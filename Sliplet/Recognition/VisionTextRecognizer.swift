import Foundation
import Vision
import ImageIO

struct OCRResult: Sendable {
    let lines: [ReceiptOCRLine]
    let revision: Int
    var readingEvidence: ReceiptReadingEvidence? = nil
}

/// The request can be cancelled from the main actor while Vision runs off the UI thread.
final class ReceiptRecognitionJob: @unchecked Sendable {
    private let lock = NSLock()
    private var request: VNRecognizeTextRequest?
    private var cancelled = false
    func cancel() {
        lock.lock(); cancelled = true; let request = request; lock.unlock()
        request?.cancel()
    }
    private func checkCancellation() throws {
        lock.lock(); let stopped = cancelled; lock.unlock()
        if stopped || Task.isCancelled { throw CancellationError() }
    }
    /// Automatic promotion remains off: the development corpus did not demonstrate
    /// a safe gain. The actual import lab explicitly opts into this bounded engine.
    func run(_ image: ReceiptImage, adaptive: Bool = false,
             reader: ((Bool, TimeInterval?) throws -> OCRResult)? = nil) throws -> OCRResult {
        try checkCancellation()
        let start = ProcessInfo.processInfo.systemUptime
        let baseline = try reader?(false, nil) ?? recognize(image, correction: false, timeout: nil)
        try checkCancellation()
        guard adaptive else { return baseline }
        let pass = ReceiptReadingPass(lines: baseline.lines, revision: baseline.revision, usesLanguageCorrection: false)
        // Never allow optional extra evidence to make a previously usable import unsavable.
        guard (try? pass.validate()) != nil else { return baseline }
        func result(_ outcome: ReceiptReadingEvidence.Outcome, _ candidate: OCRResult? = nil) -> OCRResult {
            let corrected = candidate.map { ReceiptReadingPass(lines: $0.lines, revision: $0.revision, usesLanguageCorrection: true) }
            let evidence = ReceiptReadingEvidence(baseline: pass, corrected: corrected, outcome: outcome)
            return OCRResult(lines: evidence.selected.lines, revision: evidence.selected.revision, readingEvidence: evidence)
        }
        let parsed = ReceiptParser.parse(baseline.lines)
        let uncertain = parsed.total == nil || parsed.lines.isEmpty || parsed.issues.contains {
            ["unpaired_amount", "item_amount_ambiguous", "amount_unparsed_check_source", "unpriced_source_row"].contains($0.code)
        }
        guard uncertain else { return result(.notNeeded) }
        guard ProcessInfo.processInfo.systemUptime - start <= 1.2,
              Int64(image.pixelWidth) * Int64(image.pixelHeight) <= 20_000_000 else { return result(.budgetExceeded) }
        try checkCancellation()
        do {
            let retryStart = ProcessInfo.processInfo.systemUptime
            let candidate = try reader?(true, 1.25) ?? recognize(image, correction: true, timeout: 1.25)
            try checkCancellation()
            guard ProcessInfo.processInfo.systemUptime - retryStart <= 1.25 else { throw ReceiptReadingFailure.timedOut }
            let candidatePass = ReceiptReadingPass(lines: candidate.lines, revision: candidate.revision, usesLanguageCorrection: true)
            try candidatePass.validate()
            let outcome: ReceiptReadingEvidence.Outcome = ReceiptAdaptiveReading.shouldSelect(baseline: baseline, corrected: candidate) ? .correctionSelected : .baselineRetained
            let output = result(outcome, candidate)
            try output.readingEvidence?.validate(selectedLines: output.lines)
            return output
        } catch {
            // User/session cancellation always wins over candidate timeout or failure.
            try checkCancellation()
            if error is CancellationError { throw error }
            return result(error is ReceiptReadingFailure ? .timedOut : .failed)
        }
    }
    private func recognize(_ image: ReceiptImage, correction: Bool, timeout: TimeInterval?) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = correction
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["en-US", "fr-FR", "zh-Hans", "zh-Hant"].filter(supported.contains)
        lock.lock()
        let stopped = cancelled
        if !stopped { self.request = request }
        lock.unlock()
        guard !stopped else { throw CancellationError() }
        defer { lock.lock(); self.request = nil; lock.unlock() }
        guard let source = CGImageSourceCreateWithData(image.bytes as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw ImportFailure.unsupportedImage }
        let deadline = timeout.map { ReceiptReadingDeadline(request: request, seconds: $0) }
        defer { deadline?.finish() }
        do { try VNImageRequestHandler(cgImage: cgImage, orientation: image.orientation).perform([request]) }
        catch {
            try checkCancellation()
            if deadline?.expired == true { throw ReceiptReadingFailure.timedOut }
            throw error
        }
        try checkCancellation()
        if deadline?.expired == true { throw ReceiptReadingFailure.timedOut }
        let lines = (request.results ?? []).compactMap { observation -> ReceiptOCRLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let b = observation.boundingBox
            let x = max(0, min(1, b.minX)), y = max(0, min(1, b.minY))
            let box = try? ReceiptOCRBox(x: x, y: y, width: min(b.width, 1 - x), height: min(b.height, 1 - y))
            return ReceiptOCRLine(id: UUID(), text: candidate.string, engineConfidence: candidate.confidence, boundingBox: box)
        }
        return OCRResult(lines: lines, revision: request.revision)
    }
}

/// T01's synthetic recognition boundary remains available for diagnostics.
actor VisionTextRecognizer {
    func recognize(imageData: Data) throws -> RecognizedText {
        let result = try ReceiptRecognitionJob().run(ReceiptImage.decode(imageData))
        return RecognizedText(lines: result.lines.map(\.text))
    }
}


enum ReceiptReadingFailure: Error { case timedOut }

/// Thread-safe, request-specific deadline; a late timer can never cancel the next pass.
private final class ReceiptReadingDeadline: @unchecked Sendable {
    private let lock = NSLock()
    private let request: VNRecognizeTextRequest
    private var finished = false
    private var timedOut = false
    var expired: Bool { lock.lock(); defer { lock.unlock() }; return timedOut }
    init(request: VNRecognizeTextRequest, seconds: TimeInterval) {
        self.request = request
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self else { return }
            self.lock.lock(); defer { self.lock.unlock() }
            guard !self.finished else { return }
            self.timedOut = true; self.request.cancel()
        }
    }
    func finish() { lock.lock(); finished = true; lock.unlock() }
}

enum ReceiptAdaptiveReading {
    /// Labels, reconciliation and OCR confidence are never selection inputs. Require
    /// spatially matching observations, unchanged number strings and preservation of
    /// every baseline interpretation before accepting a strictly additional field.
    static func shouldSelect(baseline: OCRResult, corrected: OCRResult) -> Bool {
        guard baseline.lines.count == corrected.lines.count,
              Set(baseline.lines.map(\.id)).count == baseline.lines.count,
              Set(corrected.lines.map(\.id)).count == corrected.lines.count else { return false }
        for (a, b) in zip(baseline.lines, corrected.lines) {
            guard let x = a.boundingBox, let y = b.boundingBox,
                  abs(x.x-y.x) < 0.02, abs(x.y-y.y) < 0.02,
                  abs(x.width-y.width) < 0.04, abs(x.height-y.height) < 0.02 else { return false }
            func numbers(_ text: String) -> [String] {
                ReceiptParser.matches(#"[-+]?\s*[$€£¥]?\s*\d+(?:[.,:/-]\d+)*(?:\s*%)?-?"#, text).compactMap {
                    Range($0.range, in: text).map { String(text[$0]).filter { !$0.isWhitespace } }
                }
            }
            func currencies(_ text: String) -> [String] {
                ReceiptParser.matches(#"\b(?:CAD|USD|EUR|GBP|CNY|HKD|JPY)\b|CA\$|US\$|HK\$"#, text).compactMap {
                    Range($0.range, in: text).map { String(text[$0]).uppercased() }
                }
            }
            guard numbers(a.text) == numbers(b.text), currencies(a.text) == currencies(b.text) else { return false }
        }
        let a = ReceiptParser.parse(baseline.lines), b = ReceiptParser.parse(corrected.lines)
        guard !a.issues.contains(where: { $0.code == "currency_conflicting" }),
              a.merchant == nil || a.merchant == b.merchant,
              a.date == nil || a.date == b.date, a.currency == nil || a.currency == b.currency,
              a.subtotal == nil || a.subtotal == b.subtotal, a.total == nil || a.total == b.total else { return false }
        let baselineIDs = Dictionary(uniqueKeysWithValues: zip(corrected.lines, baseline.lines).map { ($0.id, $1.id) })
        func signature(_ line: ParsedReceipt.Line, mapping: [UUID: UUID] = [:]) -> Data? {
            guard let data = try? JSONEncoder().encode(line),
                  var value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
            value.removeValue(forKey: "id")
            value["sourceLineIDs"] = line.sourceLineIDs.map { (mapping[$0] ?? $0).uuidString }.sorted()
            return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        }
        var remaining = b.lines.compactMap { signature($0, mapping: baselineIDs) }
        for line in a.lines {
            guard let key = signature(line), let index = remaining.firstIndex(of: key) else { return false }
            remaining.remove(at: index)
        }
        return b.lines.count > a.lines.count || (a.merchant == nil && b.merchant != nil)
            || (a.date == nil && b.date != nil) || (a.currency == nil && b.currency != nil)
            || (a.subtotal == nil && b.subtotal != nil) || (a.total == nil && b.total != nil)
    }
}
