import XCTest
import CryptoKit
import Vision
import UIKit
import CoreImage
import ImageIO
@testable import Sliplet

/// Evaluation-only experiments. Automatic requests contain originals, never checked labels.
@MainActor final class ReceiptRegionExperimentTests: XCTestCase {
    private struct Request: Decodable { let nonce: String; let slots: [Slot] }
    private struct Slot: Decodable { let slot: Int; let image: String; let sha256: String }
    private struct TranscriptRequest: Decodable { let nonce: String; let slots: [TranscriptSlot] }
    private struct TranscriptSlot: Decodable {
        let slot: Int
        let humanVerified: Bool
        let observations: [ReceiptOCRLine]
    }
    private struct Row: Encodable { let text: String; let ids: [UUID] }
    private struct Candidate: Codable, Sendable { let text: String; let confidence: Float }
    private struct CandidateSet: Codable, Sendable {
        let id: UUID
        let regionIndex: Int
        let boundingBox: ReceiptOCRBox?
        let candidates: [Candidate]
        let kept: Bool
    }
    private struct Read: Sendable {
        var observations: [ReceiptOCRLine]
        var candidates: [CandidateSet]
        let revision: Int
        let languages: [String]
    }
    private struct Response: Encodable {
        let status: String
        let nonce: String
        let slot: Int
        let pass: Int
        let mode: String
        let observations: [ReceiptOCRLine]
        let parsed: ParsedReceipt
        let fields: ReceiptFields
        let groupedRowIDs: [[UUID]]
        let interpretedRowIDs: [[UUID]]
        let groupedRows: [Row]
        let interpretedRows: [Row]
        let candidates: [CandidateSet]
        let elapsedMS: Double
        let baselineInclusiveMS: Double
        let visionCalls: Int
        let baselineDependency: Bool
        let regions: [[Double]]
        let coordinateSpace: String
        let recognitionRevision: Int
        let recognitionLanguages: [String]
        let usesLanguageCorrection: Bool
        let parserVersion: String
        let pixelWidth: Int
        let pixelHeight: Int
        let orientation: UInt32
    }
    private enum Failure: Error { case invalidInput, geometry, timedOut }
    /// VNRequest.cancel is documented thread-safe. Only this reference crosses the timer queue.
    private final class Cancellation: @unchecked Sendable {
        let request: VNRecognizeTextRequest
        init(_ request: VNRecognizeTextRequest) { self.request = request }
        func cancel() { request.cancel() }
    }
    private static let modes = ["baseline", "correction-off", "correction-on", "english-only", "auto-bounds", "strips", "candidates-second"]

    nonisolated private static func rect(_ box: ReceiptOCRBox) -> CGRect {
        CGRect(x: box.x, y: box.y, width: box.width, height: box.height)
    }
    nonisolated private static func box(_ rect: CGRect) -> ReceiptOCRBox? {
        let x = max(0, min(1, rect.minX)), y = max(0, min(1, rect.minY))
        return try? ReceiptOCRBox(x: x, y: y, width: min(rect.width, 1 - x), height: min(rect.height, 1 - y))
    }
    nonisolated private static func regionArray(_ rect: CGRect) -> [Double] {
        [rect.minX, rect.minY, rect.width, rect.height]
    }
    nonisolated private static func bounds(_ lines: [ReceiptOCRLine]) -> CGRect {
        let boxes = lines.compactMap(\.boundingBox).map(rect)
        guard let first = boxes.first else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        return boxes.dropFirst().reduce(first) { $0.union($1) }.insetBy(dx: -0.03, dy: -0.03)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    nonisolated private static func owns(_ y: Double, band: Int) -> Bool {
        // Half-open center ownership avoids duplicate rows in overlapping bands.
        if band == 0 { return y >= 2.0 / 3.0 }
        if band == 1 { return y >= 1.0 / 3.0 && y < 2.0 / 3.0 }
        return y < 1.0 / 3.0
    }
    nonisolated private static func recognize(_ image: ReceiptImage, region: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                                             correction: Bool = false, englishOnly: Bool = false, regionIndex: Int = 0,
                                             ownership: Bool = false) throws -> Read {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = correction
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = (englishOnly ? ["en-US"] : ["en-US", "fr-FR", "zh-Hans", "zh-Hant"]).filter(supported.contains)
        request.regionOfInterest = region
        guard let source = CGImageSourceCreateWithData(image.bytes as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw Failure.invalidInput }
        let cancellation = Cancellation(request)
        let timeout = DispatchWorkItem { cancellation.cancel() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: timeout)
        defer { timeout.cancel() }
        let start = ProcessInfo.processInfo.systemUptime
        do { try VNImageRequestHandler(cgImage: cgImage, orientation: image.orientation).perform([request]) }
        catch { if ProcessInfo.processInfo.systemUptime - start >= 60 { throw Failure.timedOut }; throw error }
        var lines: [ReceiptOCRLine] = [], all: [CandidateSet] = []
        for observation in request.results ?? [] {
            let candidates = observation.topCandidates(3).map { Candidate(text: $0.string, confidence: $0.confidence) }
            guard let first = candidates.first else { continue }
            // This installed runtime returns ROI-local normalized observations. Map once into
            // the full oriented image; the eight-orientation synthetic gate checks this.
            let local = observation.boundingBox
            let original = CGRect(x: region.minX + local.minX * region.width,
                                  y: region.minY + local.minY * region.height,
                                  width: local.width * region.width, height: local.height * region.height)
            let geometry = box(original)
            let keep = !ownership || owns(original.midY, band: regionIndex)
            let id = UUID()
            all.append(CandidateSet(id: id, regionIndex: regionIndex, boundingBox: geometry, candidates: candidates, kept: keep))
            if keep { lines.append(ReceiptOCRLine(id: id, text: first.text, engineConfidence: first.confidence, boundingBox: geometry)) }
        }
        return Read(observations: lines, candidates: all, revision: request.revision, languages: request.recognitionLanguages)
    }
    private func root(prefix: String = "P402Lab") throws -> (URL, String) {
        guard ProcessInfo.processInfo.environment["SLIPLET_P402_PRIVATE"] == "YES" else { throw XCTSkip("Explicit private Simulator experiment only") }
        guard let nonce = ProcessInfo.processInfo.environment["SLIPLET_P402_NONCE"], UUID(uuidString: nonce) != nil else { throw Failure.invalidInput }
        return (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(prefix).appendingPathComponent(nonce), nonce)
    }
    private func response(_ read: Read, image: ReceiptImage, nonce: String, slot: Int, pass: Int, mode: String,
                          start: Double, baselineMS: Double, regions: [CGRect], calls: Int, dependency: Bool) -> Response {
        let parsed = ReceiptParser.parse(read.observations)
        let grouped = ReceiptParser.rows(read.observations)
        let interpreted = ReceiptParser.interpretationRows(grouped, knownRetailer: parsed.merchant != nil)
        let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1000
        return Response(status: "ok", nonce: nonce, slot: slot, pass: pass, mode: mode,
            observations: read.observations, parsed: parsed, fields: parsed.fields(), groupedRowIDs: grouped.map(\.ids),
            interpretedRowIDs: interpreted.map(\.ids), groupedRows: grouped.map { Row(text: $0.text, ids: $0.ids) },
            interpretedRows: interpreted.map { Row(text: $0.text, ids: $0.ids) }, candidates: read.candidates,
            elapsedMS: elapsed + (dependency ? baselineMS : 0), baselineInclusiveMS: elapsed + (dependency ? baselineMS : 0), visionCalls: calls,
            baselineDependency: dependency, regions: regions.map(Self.regionArray), coordinateSpace: "full-oriented-image-normalized-lower-left",
            recognitionRevision: read.revision, recognitionLanguages: read.languages, usesLanguageCorrection: mode == "correction-on",
            parserVersion: ReceiptParser.version, pixelWidth: image.pixelWidth, pixelHeight: image.pixelHeight, orientation: image.orientation.rawValue)
    }
    func testExplicitPrivateRegionExperiments() async throws {
        #if targetEnvironment(simulator)
        let (root, nonce) = try root()
        var activeAttempt: URL?
        do {
            // Fail before reading private originals if this runtime violates the coordinate assumption.
            try await verifySyntheticROI()
            let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: root.appendingPathComponent("request.json")))
            guard request.nonce == nonce, request.slots.count == 5, Set(request.slots.map(\.slot)) == Set(0..<5) else { throw Failure.invalidInput }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            for slot in request.slots {
                guard !slot.image.contains("/"), !slot.image.contains("..") else { throw Failure.invalidInput }
                let bytes = try Data(contentsOf: root.appendingPathComponent(slot.image))
                guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == slot.sha256 else { throw Failure.invalidInput }
                let image = try ReceiptImage.decode(bytes)
                for pass in 1...2 {
                    var baseline: Read?, baselineMS = 0.0
                    for mode in Self.modes {
                        activeAttempt = root.appendingPathComponent("attempt-\(slot.slot)-\(pass)-\(mode).json")
                        try JSONSerialization.data(withJSONObject: ["status": "started", "nonce": nonce, "slot": slot.slot, "pass": pass, "mode": mode]).write(to: activeAttempt!, options: .atomic)
                        let start = ProcessInfo.processInfo.systemUptime
                        var regions = [CGRect(x: 0, y: 0, width: 1, height: 1)], calls = 1
                        let read: Read
                        if mode == "candidates-second" {
                            guard let baseline else { throw Failure.invalidInput }
                            read = Read(observations: baseline.candidates.filter(\.kept).map { set in
                                let candidate = set.candidates.count > 1 ? set.candidates[1] : set.candidates[0]
                                return ReceiptOCRLine(id: set.id, text: candidate.text, engineConfidence: candidate.confidence, boundingBox: set.boundingBox)
                            }, candidates: baseline.candidates, revision: baseline.revision, languages: baseline.languages)
                            calls = 0
                        } else if mode == "strips" {
                            regions = [CGRect(x: 0, y: 0.60, width: 1, height: 0.40), CGRect(x: 0, y: 0.27, width: 1, height: 0.46), CGRect(x: 0, y: 0, width: 1, height: 0.40)]
                            var combined: Read?
                            for (index, region) in regions.enumerated() {
                                let partial = try await Task.detached { try Self.recognize(image, region: region, regionIndex: index, ownership: true) }.value
                                if combined == nil { combined = partial }
                                else { combined!.observations += partial.observations; combined!.candidates += partial.candidates }
                            }
                            read = combined!; calls = 3
                        } else {
                            if mode == "auto-bounds" { guard let baseline else { throw Failure.invalidInput }; regions = [Self.bounds(baseline.observations)] }
                            let region = regions[0]
                            read = try await Task.detached { try Self.recognize(image, region: region, correction: mode == "correction-on", englishOnly: mode == "english-only") }.value
                        }
                        let capture = response(read, image: image, nonce: nonce, slot: slot.slot, pass: pass, mode: mode, start: start,
                            baselineMS: baselineMS, regions: regions, calls: calls, dependency: ["auto-bounds", "candidates-second"].contains(mode))
                        if mode == "baseline" { baseline = read; baselineMS = capture.elapsedMS }
                        try encoder.encode(capture).write(to: root.appendingPathComponent("capture-\(slot.slot)-\(pass)-\(mode).json"), options: .atomic)
                        try JSONSerialization.data(withJSONObject: ["status": "ok", "nonce": nonce, "slot": slot.slot, "pass": pass, "mode": mode]).write(to: activeAttempt!, options: .atomic)
                        activeAttempt = nil
                    }
                }
            }
        } catch {
            if let activeAttempt { try? JSONSerialization.data(withJSONObject: ["status": error is Failure && { if case Failure.timedOut = error { return true }; return false }() ? "timed_out" : "failed"]).write(to: activeAttempt, options: .atomic) }
            XCTFail("Private regional experiment stopped; inspect only local sanitized attempt status.")
        }
        #else
        throw XCTSkip("Private experiments are Simulator-only")
        #endif
    }

    /// A separate human transcript path cannot influence automatic OCR experiment requests.
    func testExplicitCheckedTranscript() throws {
        #if targetEnvironment(simulator)
        let (root, nonce) = try root()
        guard ProcessInfo.processInfo.environment["SLIPLET_P402_CHECKED_TEXT"] == "YES" else { throw XCTSkip("Explicit verified transcript experiment only") }
        do {
            let request = try JSONDecoder().decode(TranscriptRequest.self, from: Data(contentsOf: root.appendingPathComponent("transcripts.json")))
            guard request.nonce == nonce, !request.slots.isEmpty, Set(request.slots.map(\.slot)).count == request.slots.count else { throw Failure.invalidInput }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            for slot in request.slots {
                guard (0..<5).contains(slot.slot), slot.humanVerified, !slot.observations.isEmpty,
                      Set(slot.observations.map(\.id)).count == slot.observations.count else { throw Failure.invalidInput }
                let parsed = ReceiptParser.parse(slot.observations)
                let grouped = ReceiptParser.rows(slot.observations)
                let interpreted = ReceiptParser.interpretationRows(grouped, knownRetailer: parsed.merchant != nil)
                struct Output: Encodable {
                    let status: String; let nonce: String; let slot: Int; let mode: String
                    let observations: [ReceiptOCRLine]; let parsed: ParsedReceipt; let fields: ReceiptFields
                    let groupedRowIDs: [[UUID]]; let interpretedRowIDs: [[UUID]]
                }
                try encoder.encode(Output(status: "ok", nonce: nonce, slot: slot.slot, mode: "checked-text", observations: slot.observations,
                    parsed: parsed, fields: parsed.fields(), groupedRowIDs: grouped.map(\.ids), interpretedRowIDs: interpreted.map(\.ids)))
                    .write(to: root.appendingPathComponent("capture-\(slot.slot)-checked-text.json"), options: .atomic)
            }
        } catch { XCTFail("Verified transcript experiment did not complete.") }
        #else
        throw XCTSkip("Private experiments are Simulator-only")
        #endif
    }
    /// Assisted reread retains full-image context; it is never counted as automatic accuracy.
    func testExplicitVerifiedRegions() async throws {
        #if targetEnvironment(simulator)
        let (root, nonce) = try root()
        guard ProcessInfo.processInfo.environment["SLIPLET_P402_CHECKED_REGIONS"] == "YES" else { throw XCTSkip("Explicit verified region experiment only") }
        struct RegionSlot: Decodable { let slot: Int; let humanVerified: Bool; let region: ReceiptOCRBox }
        struct RegionRequest: Decodable { let nonce: String; let slots: [RegionSlot] }
        do {
            let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: root.appendingPathComponent("request.json")))
            let assisted = try JSONDecoder().decode(RegionRequest.self, from: Data(contentsOf: root.appendingPathComponent("regions.json")))
            guard assisted.nonce == nonce, request.nonce == nonce, !assisted.slots.isEmpty,
                  Set(assisted.slots.map(\.slot)).count == assisted.slots.count else { throw Failure.invalidInput }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            for slot in assisted.slots {
                guard slot.humanVerified, let original = request.slots.first(where: { $0.slot == slot.slot }),
                      !original.image.contains("/"), !original.image.contains("..") else { throw Failure.invalidInput }
                let bytes = try Data(contentsOf: root.appendingPathComponent(original.image))
                guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == original.sha256 else { throw Failure.invalidInput }
                let image = try ReceiptImage.decode(bytes), region = Self.rect(slot.region)
                for pass in 1...2 {
                    let start = ProcessInfo.processInfo.systemUptime
                    let full = try await Task.detached { try Self.recognize(image) }.value
                    let partial = try await Task.detached { try Self.recognize(image, region: region, regionIndex: 1) }.value
                    // A source rectangle touching the chosen boundary is retained from baseline;
                    // replace only fully enclosed observations and retain all candidates for audit.
                    let retained = full.observations.filter { line in
                        guard let b = line.boundingBox else { return true }; return !region.contains(Self.rect(b))
                    }
                    let added = partial.observations.filter { line in
                        guard let b = line.boundingBox else { return false }
                        let r = Self.rect(b)
                        return !retained.contains { old in
                            guard let oldBox = old.boundingBox else { return false }
                            let intersection = r.intersection(Self.rect(oldBox))
                            return !intersection.isNull && intersection.width * intersection.height > 0.25 * min(r.width * r.height, oldBox.width * oldBox.height)
                        }
                    }
                    let selectedIDs = Set((retained + added).map(\.id))
                    let candidates = (full.candidates + partial.candidates).map { CandidateSet(id: $0.id, regionIndex: $0.regionIndex, boundingBox: $0.boundingBox, candidates: $0.candidates, kept: selectedIDs.contains($0.id)) }
                    let result = Read(observations: retained + added, candidates: candidates, revision: partial.revision, languages: partial.languages)
                    let capture = response(result, image: image, nonce: nonce, slot: slot.slot, pass: pass, mode: "human-region", start: start, baselineMS: 0, regions: [CGRect(x: 0, y: 0, width: 1, height: 1), region], calls: 2, dependency: false)
                    try encoder.encode(capture).write(to: root.appendingPathComponent("capture-\(slot.slot)-\(pass)-human-region.json"), options: .atomic)
                }
            }
        } catch { XCTFail("Verified region experiment did not complete.") }
        #else
        throw XCTSkip("Private experiments are Simulator-only")
        #endif
    }
    private func verifySyntheticROI() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let data = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1200), format: format).pngData { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1000, height: 1200))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 42, weight: .regular), .foregroundColor: UIColor.black]
            ("ALPHA MARKET" as NSString).draw(at: CGPoint(x: 150, y: 180), withAttributes: attributes)
            ("FICTIONAL APPLES 12.34" as NSString).draw(at: CGPoint(x: 150, y: 750), withAttributes: attributes)
        }
        let decoded = try ReceiptImage.decode(data)
        for orientation: CGImagePropertyOrientation in [.up, .upMirrored, .down, .downMirrored, .leftMirrored, .right, .rightMirrored, .left] {
            let inverse: CGImagePropertyOrientation = orientation == .right ? .left : orientation == .left ? .right : orientation
            guard let source = CIImage(data: decoded.bytes) else { throw Failure.geometry }
            let rotated = source.oriented(inverse)
            guard let pixels = CIContext().createCGImage(rotated, from: rotated.extent) else { throw Failure.geometry }
            let buffer = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(buffer, "public.png" as CFString, 1, nil) else { throw Failure.geometry }
            CGImageDestinationAddImage(destination, pixels, nil)
            guard CGImageDestinationFinalize(destination) else { throw Failure.geometry }
            let image = ReceiptImage(bytes: buffer as Data, mediaType: decoded.mediaType, orientation: orientation, pixelWidth: pixels.width, pixelHeight: pixels.height)
            let full = try await Task.detached { try Self.recognize(image) }.value
            guard let marker = full.observations.first(where: { $0.text.contains("ALPHA MARKET") }), let fullBox = marker.boundingBox else { throw Failure.geometry }
            let region = Self.rect(fullBox).insetBy(dx: -0.10, dy: -0.10).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            let cropped = try await Task.detached { try Self.recognize(image, region: region) }.value
            guard let roiBox = cropped.observations.first(where: { $0.text.contains("ALPHA MARKET") })?.boundingBox else { throw Failure.geometry }
            guard
                  abs(Self.rect(roiBox).midX - Self.rect(fullBox).midX) < 0.04,
                  abs(Self.rect(roiBox).midY - Self.rect(fullBox).midY) < 0.04,
                  abs(roiBox.width - fullBox.width) < 0.08 else { throw Failure.geometry }
        }
    }
    func testSyntheticROICoordinatesRemainInOriginalImage() async throws { try await verifySyntheticROI() }
    func testOverlappingBandOwnershipHasNoDuplicateCenters() {
        for y in [0.0, 0.27, 1.0 / 3.0, 0.40, 0.60, 2.0 / 3.0, 0.73, 1.0] {
            XCTAssertEqual((0..<3).filter { Self.owns(y, band: $0) }.count, 1)
        }
    }
}
