import XCTest
import CryptoKit
import CoreImage
import Vision
import UIKit
@testable import Sliplet

/// P6-02 isolated probe. Never called by production and never receives answer labels.
@MainActor final class ReceiptTotalProbeTests: XCTestCase {
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
    private func decision(_ baseline: ParsedReceipt, _ reads: [Read]) -> (Int64?, String) {
        if let value = baseline.total { return (value, "preserve_existing") }
        if baseline.issues.contains(where: { ["negative_summary_check_source", "total_conflicting", "summary_amount_ambiguous"].contains($0.code) }) {
            return (nil, "preserve_conflict")
        }
        guard reads.count == 2, let a = reads[0].parsed.total, let b = reads[1].parsed.total, a == b else { return (nil, "no_agreement") }
        guard !reads.contains(where: { $0.parsed.issues.contains(where: { ["negative_summary_check_source", "total_conflicting", "summary_amount_ambiguous"].contains($0.code) }) }) else { return (nil, "preserve_conflict") }
        return (a, "two_read_agreement")
    }
    func testPrivateTotalProbe() throws {
        guard ProcessInfo.processInfo.environment["SLIPLET_P602_PRIVATE"] == "YES" else { throw XCTSkip("Explicit private experiment only") }
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
                    let result = decision(baseline, readings)
                    probes.append(Probe(pass: pass, region: roi, reads: readings, baseline: baseline, proposedTotal: result.0, decision: result.1))
                }
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                try encoder.encode(probes).write(to: root.appendingPathComponent("total-probe-\(slot.slot).json"), options: .atomic)
            }
        } catch { XCTFail("Private total probe failed; inspect private evidence only.") }
    }
    func testDecisionDoesNotEraseSignsOrChooseCompetingValues() throws {
        func parse(_ text: String) -> ParsedReceipt { ReceiptParser.parse([ReceiptOCRLine(id: UUID(), text: text, engineConfidence: 1, boundingBox: nil)]) }
        func result(_ text: String) -> Read { Read(mode: "fixture", observations: [], parsed: parse(text), milliseconds: 0) }
        XCTAssertEqual(decision(parse("TOTAL"), [result("TOTAL 12.34"), result("TOTAL 12.34")]).0, 1234)
        XCTAssertNil(decision(parse("TOTAL"), [result("TOTAL 12.34"), result("TOTAL 12.35")]).0)
        XCTAssertNil(decision(parse("TOTAL 12,34-"), [result("TOTAL 12.34"), result("TOTAL 12.34")]).0)
        XCTAssertEqual(decision(parse("TOTAL -12.34"), [result("TOTAL 12.34"), result("TOTAL 12.34")]).0, -1234)
        XCTAssertNil(decision(parse("TOTAL"), [result("AMOUNT 12.34"), result("AMOUNT 12.34")]).0)
        XCTAssertNil(decision(parse("TOTAL"), [result("TOTAL 12.34 23.45"), result("TOTAL 12.34")]).0)
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
            let proposed = decision(ReceiptParser.parse([label]), reads).0
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
