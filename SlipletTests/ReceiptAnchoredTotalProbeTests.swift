import XCTest
import CryptoKit
import CoreImage
import Vision
import UIKit
@testable import Sliplet

/// P6-02B isolated probe. Never called by production and never receives answer labels.
@MainActor final class ReceiptAnchoredTotalProbeTests: XCTestCase {
    private struct Request: Decodable { let nonce: String; let slots: [Slot] }
    private struct Slot: Decodable { let slot: Int; let image: String; let sha256: String }
    private struct Capture: Decodable { let observations: [ReceiptOCRLine] }
    private struct Read: Encodable {
        let mode: String
        let observations: [ReceiptOCRLine]
        let parsed: ParsedReceipt
        let milliseconds: Double
    }
    private struct Probe: Encodable {
        let pass: Int
        let region: ReceiptOCRBox?
        let reads: [Read]
        let baseline: ParsedReceipt
        let proposedTotal: Int64?
        let decision: String
        let supportingObservationIDs: [UUID]
    }
    private enum Failure: Error { case invalid, timedOut }

    private func region(_ lines: [ReceiptOCRLine]) throws -> ReceiptOCRBox? {
        let rows = ReceiptParser.rows(lines).filter { ReceiptParser.summaryLabel($0.text)?.kind == .total }
        guard rows.count == 1 else { return nil }
        let ids = Set(rows[0].ids)
        // Use the label observation, not an amount or a known reference location.
        let labels = lines.filter { ids.contains($0.id) && ReceiptParser.summaryLabel($0.text)?.kind == .total }
        guard labels.count == 1, let b = labels[0].boundingBox else { return nil }
        let h = max(b.height * 5, 0.04)
        let bottom = max(0, b.y + b.height / 2 - h / 2)
        let top = min(1, b.y + b.height / 2 + h / 2)
        // Full-width strip preserves both sides of the amount, including real signs.
        return try ReceiptOCRBox(x: 0, y: bottom, width: 1, height: top - bottom)
    }
    private func read(_ image: ReceiptImage, region: ReceiptOCRBox, inverted: Bool) throws -> Read {
        let start = ProcessInfo.processInfo.systemUptime
        guard let raw = CIImage(data: image.bytes) else { throw Failure.invalid }
        let upright = raw.oriented(forExifOrientation: Int32(image.orientation.rawValue))
        let e = upright.extent
        let crop = CGRect(x: e.minX + region.x * e.width, y: e.minY + region.y * e.height,
                          width: region.width * e.width, height: region.height * e.height).integral.intersection(e)
        let clipped = upright.cropped(to: crop)
        let pixels = inverted ? clipped.applyingFilter("CIColorInvert") : clipped
        guard let cg = CIContext(options: [.cacheIntermediates: false]).createCGImage(pixels, from: crop) else { throw Failure.invalid }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["en-US", "fr-FR", "zh-Hans", "zh-Hant"].filter(supported.contains)
        let cancel = DispatchWorkItem { request.cancel() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: cancel)
        defer { cancel.cancel() }
        try VNImageRequestHandler(cgImage: cg, orientation: .up).perform([request])
        guard ProcessInfo.processInfo.systemUptime - start < 3 else { throw Failure.timedOut }
        // Account for pixel rounding when mapping crop-local boxes back to the original.
        let actual = try ReceiptOCRBox(x: (crop.minX-e.minX)/e.width, y: (crop.minY-e.minY)/e.height,
                                      width: crop.width/e.width, height: crop.height/e.height)
        let lines = (request.results ?? []).compactMap { o -> ReceiptOCRLine? in
            guard let c = o.topCandidates(1).first,
                  let box = try? ReceiptRegionReadingJob.originalBox(local: o.boundingBox, region: actual) else { return nil }
            return ReceiptOCRLine(id: UUID(), text: c.string, engineConfidence: c.confidence, boundingBox: box)
        }
        return Read(mode: inverted ? "inverted" : "original", observations: lines,
                    parsed: ReceiptParser.parse(lines), milliseconds: (ProcessInfo.processInfo.systemUptime-start)*1000)
    }
    private struct Selection {
        let value: Int64?
        let reason: String
        var ids: [UUID] = []
    }
    private func decision(_ baseline: ParsedReceipt, _ source: [ReceiptOCRLine], _ reads: [Read]) -> Selection {
        if let value = baseline.total { return Selection(value: value, reason: "preserve_existing") }
        if baseline.issues.contains(where: { ["negative_summary_check_source", "total_conflicting", "summary_amount_ambiguous"].contains($0.code) }) {
            return Selection(value: nil, reason: "preserve_conflict")
        }
        let labels = source.filter { ReceiptParser.summaryLabel($0.text)?.kind == .total }
        guard labels.count == 1, let anchor = labels.first, let box = anchor.boundingBox else { return Selection(value: nil, reason: "no_unique_anchor") }
        let cy = box.y + box.height / 2
        let competitors = source.filter { line in
            line.id != anchor.id && (ReceiptParser.summaryLabel(line.text) != nil ||
                ReceiptParser.first(#"^[\s*:=]*(?:TAX|HST|GST|PST|QST|TPS|TVQ|CASH|CHANGE|TENDER|BALANCE|AMOUNT)\b"#, line.text) != nil)
        }.compactMap(\.boundingBox)
        func aligned(_ b: ReceiptOCRBox) -> Bool {
            let distance = abs(b.y + b.height / 2 - cy)
            guard b.x >= box.x + box.width - 0.01, distance <= max(box.height, b.height) * 1.5 else { return false }
            return !competitors.contains { other in
                abs(b.y + b.height / 2 - (other.y + other.height / 2)) <= distance
            }
        }
        guard reads.count == 2 else { return Selection(value: nil, reason: "missing_reads") }
        var chosen: [ReceiptOCRLine] = []
        for read in reads {
            let alignedLines = read.observations.filter { $0.boundingBox.map(aligned) ?? false }
            // Signs remain evidence even if OCR separates them from the digits.
            if alignedLines.contains(where: { $0.text.contains("-") || $0.text.contains("−") || $0.text.contains("(") || $0.text.contains(")") }) {
                return Selection(value: nil, reason: "signed_or_uncertain_region")
            }
            let numbers = alignedLines.filter {
                let t = $0.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return ReceiptParser.first(#"^\$?\d[\d.,\s]*$"#, t) == t
            }
            guard numbers.count == 1 else { return Selection(value: nil, reason: "ambiguous_or_missing_amount") }
            chosen.append(numbers[0])
        }
        let strings = chosen.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
        let digits = strings.map { $0.filter(\.isNumber) }
        guard digits[0] == digits[1], !digits[0].isEmpty else { return Selection(value: nil, reason: "digits_disagree") }
        let literals = strings.compactMap { t -> Int64? in
            guard ReceiptParser.first(ReceiptParser.moneyPattern, t) == t else { return nil }
            return ReceiptParser.printedMoney(t)
        }
        guard let amount = literals.first, amount >= 0, literals.allSatisfy({ $0 == amount }) else {
            return Selection(value: nil, reason: "no_literal_money_agreement")
        }
        // A non-money corroboration may contain only digits and whitespace. Never
        // disregard a malformed separator to agree with a different decimal scale.
        guard strings.allSatisfy({ ReceiptParser.first(ReceiptParser.moneyPattern, $0) == $0 || ReceiptParser.first(#"^\d[\d\s]*$"#, $0) == $0 }) else {
            return Selection(value: nil, reason: "malformed_separator")
        }
        return Selection(value: amount, reason: "anchored_literal_with_digit_corroboration", ids: [anchor.id] + chosen.map(\.id))
    }
    func testPrivateTotalProbe() throws {
        guard ProcessInfo.processInfo.environment["SLIPLET_P602B_PRIVATE"] == "YES" else { throw XCTSkip("Explicit private experiment only") }
        do {
            guard let nonce = ProcessInfo.processInfo.environment["SLIPLET_P401_NONCE"], UUID(uuidString: nonce) != nil else { throw Failure.invalid }
            let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("P401Lab").appendingPathComponent(nonce)
            let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: root.appendingPathComponent("request.json")))
            guard request.nonce == nonce, request.slots.count == 5 else { throw Failure.invalid }
            for slot in request.slots {
                guard (0..<5).contains(slot.slot), !slot.image.contains("/"), !slot.image.contains("..") else { throw Failure.invalid }
                let bytes = try Data(contentsOf: root.appendingPathComponent(slot.image))
                guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == slot.sha256 else { throw Failure.invalid }
                let image = try ReceiptImage.decode(bytes)
                let c = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: root.appendingPathComponent("capture-\(slot.slot)-1.json")))
                let baseline = ReceiptParser.parse(c.observations)
                let roi = try region(c.observations)
                var probes: [Probe] = []
                for pass in 1...2 {
                    var readings: [Read] = []
                    if let roi {
                        // Alternate order between passes; no result-dependent variant tuning.
                        for inverse in (pass == 1 ? [false, true] : [true, false]) {
                            readings.append(try read(image, region: roi, inverted: inverse))
                        }
                    }
                    let result = decision(baseline, c.observations, readings)
                    probes.append(Probe(pass: pass, region: roi, reads: readings, baseline: baseline, proposedTotal: result.value, decision: result.reason, supportingObservationIDs: result.ids))
                }
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                try encoder.encode(probes).write(to: root.appendingPathComponent("anchored-probe-\(slot.slot).json"), options: .atomic)
            }
        } catch { XCTFail("Private total probe failed; inspect private evidence only.") }
    }
    func testAnchoredSelectionSafety() throws {
        func line(_ text: String, x: Double = 0.6, y: Double = 0.30) throws -> ReceiptOCRLine {
            .init(id: UUID(), text: text, engineConfidence: 1, boundingBox: try ReceiptOCRBox(x: x, y: y, width: 0.15, height: 0.02))
        }
        let anchor = try line("TOTAL", x: 0.15)
        let baseline = ReceiptParser.parse([anchor])
        func reads(_ a: [ReceiptOCRLine], _ b: [ReceiptOCRLine]) -> [Read] {
            [Read(mode: "original", observations: a, parsed: ReceiptParser.parse(a), milliseconds: 0),
             Read(mode: "inverted", observations: b, parsed: ReceiptParser.parse(b), milliseconds: 0)]
        }
        XCTAssertEqual(try decision(baseline, [anchor], reads([line("1234")], [line("12.34")])).value, 1234)
        XCTAssertEqual(try decision(baseline, [anchor], reads([line("12.34")], [line("12.34")])).value, 1234)
        for invalid in ["-12.34", "12.34-", "12,3", "12.35", "1.234", "AMOUNT 12.34"] {
            XCTAssertNil(try decision(baseline, [anchor], reads([line(invalid)], [line("12.34")])).value)
        }
        XCTAssertNil(try decision(baseline, [anchor], reads([line("12.34"),line("23.45",x:0.8)], [line("12.34")])).value)
        XCTAssertNil(try decision(baseline, [anchor], reads([line("12.34"),line("-",x:0.8)], [line("12.34")])).value)
        let tax = try line("TAX", x: 0.15, y: 0.34)
        XCTAssertNil(try decision(baseline, [anchor,tax], reads([line("12.34",y:0.34)], [line("12.34",y:0.34)])).value)
        XCTAssertNil(try decision(baseline, [anchor], reads([line("12.34",x:0.05)], [line("12.34",x:0.05)])).value)
        let conflict = ReceiptParser.parse([try line("TOTAL 12,34-",x:0.15)])
        XCTAssertNil(try decision(conflict, [anchor], reads([line("12.34")], [line("12.34")])).value)
    }
    func testFictionalDarkBarsPreserveNegativeMissingAndCompetingAmounts() throws {
        let font = UIFont.monospacedSystemFont(ofSize: 38, weight: .bold)
        for value in ["12.34", "-12.34", "12.34-", "", "12.34 23.45"] {
            let rendered = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 700)).image { context in
                UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1000, height: 700))
                ("TOTAL" as NSString).draw(at: CGPoint(x: 80, y: 320), withAttributes: [.font: font, .foregroundColor: UIColor.black])
                UIColor.black.setFill(); context.fill(CGRect(x: 340, y: 310, width: 620, height: 75))
                (value as NSString).draw(at: CGPoint(x: 360, y: 320), withAttributes: [.font: font, .foregroundColor: UIColor.white])
            }
            let image = try ReceiptImage.decode(XCTUnwrap(rendered.pngData()))
            let label = ReceiptOCRLine(id: UUID(), text: "TOTAL", engineConfidence: 1,
                                       boundingBox: try ReceiptOCRBox(x: 0.08, y: 0.48, width: 0.2, height: 0.06))
            let roi = try XCTUnwrap(region([label]))
            let reads = try [read(image, region: roi, inverted: false), read(image, region: roi, inverted: true)]
            let proposed = decision(ReceiptParser.parse([label]), [label], reads).value
            if value == "12.34" { XCTAssertEqual(proposed, 1234) }
            else if value.contains("-") { XCTAssertTrue(proposed == nil || proposed == -1234) }
            else { XCTAssertNil(proposed) }
        }
    }
    func testRegionsRequireUniqueTotalLabelAndKeepFullWidth() throws {
        func line(_ text: String, _ y: Double) throws -> ReceiptOCRLine {
            .init(id: UUID(), text: text, engineConfidence: 1, boundingBox: try ReceiptOCRBox(x: 0.2, y: y, width: 0.2, height: 0.02))
        }
        let r = try XCTUnwrap(region([try line("TOTAL", 0.3)]))
        XCTAssertEqual(r.x, 0); XCTAssertEqual(r.width, 1)
        XCTAssertNil(try region([try line("TOTAL ITEMS", 0.3)]))
        XCTAssertNil(try region([try line("TOTAL", 0.3), try line("TOTAL", 0.6)]))
    }
}
