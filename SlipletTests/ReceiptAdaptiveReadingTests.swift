import XCTest
@testable import Sliplet

/// Fictional observations and isolated stores only. Injected passes never invoke Vision.
@MainActor final class ReceiptAdaptiveReadingTests: XCTestCase {
    private enum InjectedFailure: Error { case unavailable }
    private func image() throws -> ReceiptImage { try ReceiptImage.decode(SyntheticFixture.imageData()) }
    private func result(_ texts: [String]) throws -> OCRResult {
        OCRResult(lines: try texts.enumerated().map { index, text in
            ReceiptOCRLine(id: UUID(), text: text, engineConfidence: 0.9,
                boundingBox: try ReceiptOCRBox(x: 0.10, y: 0.90 - Double(index) * 0.08, width: 0.80, height: 0.04))
        }, revision: 3)
    }
    private func incomplete() throws -> OCRResult {
        try result(["NO FRILLS CAD", "2026-10-07", "FICTIONAL APPLES 1.23"])
    }
    private func pair() throws -> (OCRResult, OCRResult) {
        let baseline = try result(["NO FRILIS CAD", "2026-10-07", "FICTIONAL APPLES 1.23", "SUBTOTAL 1.23"])
        var lines = baseline.lines.map { ReceiptOCRLine(id: UUID(), text: $0.text, engineConfidence: $0.engineConfidence, boundingBox: $0.boundingBox) }
        let old = lines[0]
        lines[0] = ReceiptOCRLine(id: UUID(), text: "NO FRILLS CAD", engineConfidence: 0.9, boundingBox: old.boundingBox)
        return (baseline, OCRResult(lines: lines, revision: 3))
    }
    private func pass(_ result: OCRResult, corrected: Bool) -> ReceiptReadingPass {
        ReceiptReadingPass(lines: result.lines, revision: result.revision, usesLanguageCorrection: corrected)
    }
    func testDefaultPathRunsOnlyBaselineAndLeavesEvidenceAbsent() throws {
        let baseline = try incomplete(), job = ReceiptRecognitionJob()
        var calls: [Bool] = []
        let output = try job.run(image(), reader: { correction, _ in calls.append(correction); return baseline })
        XCTAssertEqual(calls, [false]); XCTAssertEqual(output.lines, baseline.lines)
        XCTAssertNil(output.readingEvidence)
    }
    func testCompleteBaselineDoesNotSpendSecondPass() throws {
        let baseline = try result(["NO FRILLS CAD", "2026-10-07", "FICTIONAL APPLES 1.23", "SUBTOTAL 1.23", "TOTAL 1.23"])
        var calls: [Bool] = []
        let output = try ReceiptRecognitionJob().run(image(), adaptive: true, reader: { correction, _ in calls.append(correction); return baseline })
        XCTAssertEqual(calls, [false]); XCTAssertEqual(output.readingEvidence?.outcome, .notNeeded)
        XCTAssertNil(output.readingEvidence?.corrected)
    }
    func testImageBudgetPreventsExtraReadWithoutLosingBaseline() throws {
        let original = try image(), baseline = try incomplete()
        let large = ReceiptImage(bytes: original.bytes, mediaType: original.mediaType, orientation: original.orientation, pixelWidth: 6000, pixelHeight: 4000)
        var calls: [Bool] = []
        let output = try ReceiptRecognitionJob().run(large, adaptive: true, reader: { correction, _ in calls.append(correction); return baseline })
        XCTAssertEqual(calls, [false]); XCTAssertEqual(output.lines, baseline.lines)
        XCTAssertEqual(output.readingEvidence?.outcome, .budgetExceeded)
    }
    func testAdaptiveSelectionKeepsSelectedSourceIDsAndBothPasses() throws {
        let (baseline, candidate) = try pair()
        XCTAssertNil(ReceiptParser.parse(baseline.lines).merchant)
        XCTAssertNotNil(ReceiptParser.parse(candidate.lines).merchant)
        XCTAssertTrue(ReceiptAdaptiveReading.shouldSelect(baseline: baseline, corrected: candidate))
        var calls: [Bool] = []
        let output = try ReceiptRecognitionJob().run(image(), adaptive: true, reader: { correction, timeout in
            calls.append(correction)
            if correction { XCTAssertNotNil(timeout) }
            return correction ? candidate : baseline
        })
        XCTAssertEqual(calls, [false, true]); XCTAssertEqual(output.lines, candidate.lines)
        XCTAssertEqual(output.readingEvidence?.outcome, .correctionSelected)
        XCTAssertEqual(output.readingEvidence?.baseline.lines, baseline.lines)
        XCTAssertEqual(output.readingEvidence?.corrected?.lines, candidate.lines)
        let extraction = try ReceiptParser.extraction(output)
        try extraction.validate()
        XCTAssertEqual(extraction.rawOCR, candidate.lines)
        let raw = try JSONDecoder().decode(ParsedReceipt.self, from: extraction.rawParserOutput)
        XCTAssertEqual(Set(raw.lines.flatMap(\.sourceLineIDs)), Set(extraction.fields.items.flatMap(\.sourceLineIDs)))
    }
    func testNumericChangeOrLostPurchaseCannotWinEvenWithBetterMerchant() throws {
        let (baseline, candidate) = try pair()
        var changed = candidate.lines
        let old = changed[2]
        changed[2] = ReceiptOCRLine(id: UUID(), text: "FICTIONAL APPLES 7.23", engineConfidence: 1, boundingBox: old.boundingBox)
        XCTAssertFalse(ReceiptAdaptiveReading.shouldSelect(baseline: baseline, corrected: OCRResult(lines: changed, revision: 3)))
        XCTAssertFalse(ReceiptAdaptiveReading.shouldSelect(baseline: baseline, corrected: OCRResult(lines: candidate.lines.filter { $0.id != old.id }, revision: 3)))
        XCTAssertFalse(ReceiptAdaptiveReading.shouldSelect(baseline: candidate, corrected: candidate))
    }
    func testSignLossOnUnresolvedAmountCannotWinWithMerchantImprovement() throws {
        let baseline = try result(["NO FRILIS CAD", "2026-10-07", "FICTIONAL APPLES 1.23", "SUBTOTAL 1.23", "-$1.23"])
        let candidate = try result(["NO FRILLS CAD", "2026-10-07", "FICTIONAL APPLES 1.23", "SUBTOTAL 1.23", "$1.23"])
        let unresolvedID = try XCTUnwrap(baseline.lines.last?.id)
        XCTAssertFalse(ReceiptParser.parse(baseline.lines).lines.flatMap(\.sourceLineIDs).contains(unresolvedID))
        XCTAssertNil(ReceiptParser.parse(baseline.lines).merchant)
        XCTAssertNotNil(ReceiptParser.parse(candidate.lines).merchant)
        XCTAssertFalse(ReceiptAdaptiveReading.shouldSelect(baseline: baseline, corrected: candidate))
    }
    func testRemovingConflictingCurrencyCannotWinWithMerchantImprovement() throws {
        let baseline = try result(["NO FRILIS CAD USD", "2026-10-07", "FICTIONAL APPLES 1.23", "SUBTOTAL 1.23"])
        let candidate = try result(["NO FRILLS CAD", "2026-10-07", "FICTIONAL APPLES 1.23", "SUBTOTAL 1.23"])
        XCTAssertTrue(ReceiptParser.parse(baseline.lines).issues.contains { $0.code == "currency_conflicting" })
        XCTAssertEqual(ReceiptParser.parse(candidate.lines).currency, .cad)
        XCTAssertFalse(ReceiptAdaptiveReading.shouldSelect(baseline: baseline, corrected: candidate))
    }
    func testEqualPricedPurchasesCannotSwapSourcePositionsToGainMerchant() throws {
        let baseline = try result(["NO FRILIS CAD", "2026-10-07", "FICTIONAL APPLES 1.23", "FICTIONAL PEARS 1.23", "SUBTOTAL 2.46"])
        let candidate = try result(["NO FRILLS CAD", "2026-10-07", "FICTIONAL PEARS 1.23", "FICTIONAL APPLES 1.23", "SUBTOTAL 2.46"])
        let before = ReceiptParser.parse(baseline.lines), after = ReceiptParser.parse(candidate.lines)
        XCTAssertEqual(before.lines.count, 2); XCTAssertEqual(after.lines.count, 2)
        XCTAssertEqual(before.lines.map(\.description).sorted(), after.lines.map(\.description).sorted())
        XCTAssertFalse(ReceiptAdaptiveReading.shouldSelect(baseline: baseline, corrected: candidate))
    }
    func testLateSuccessfulCandidateIsTimedOutAndBaselineSurvives() throws {
        let (baseline, candidate) = try pair()
        var calls: [Bool] = []
        let output = try ReceiptRecognitionJob().run(image(), adaptive: true, reader: { correction, _ in
            calls.append(correction)
            if correction { Thread.sleep(forTimeInterval: 1.3); return candidate }
            return baseline
        })
        XCTAssertEqual(calls, [false, true])
        XCTAssertEqual(output.lines, baseline.lines)
        XCTAssertEqual(output.readingEvidence?.outcome, .timedOut)
        XCTAssertNil(output.readingEvidence?.corrected)
    }
    func testChangedGeometryAndMissingBoxesCannotBeTreatedAsSameEvidence() throws {
        let (baseline, candidate) = try pair()
        for box in [ReceiptOCRBox?.none, try ReceiptOCRBox(x: 0.1, y: 0.05, width: 0.8, height: 0.04)] {
            var lines = candidate.lines; let old = lines[2]
            lines[2] = ReceiptOCRLine(id: UUID(), text: old.text, engineConfidence: old.engineConfidence, boundingBox: box)
            XCTAssertFalse(ReceiptAdaptiveReading.shouldSelect(baseline: baseline, corrected: OCRResult(lines: lines, revision: 3)))
        }
    }
    func testUnchangedCandidateIsRetainedOnlyAsEvidence() throws {
        let baseline = try incomplete()
        let candidate = OCRResult(lines: baseline.lines.map { ReceiptOCRLine(id: UUID(), text: $0.text, engineConfidence: $0.engineConfidence, boundingBox: $0.boundingBox) }, revision: 3)
        let output = try ReceiptRecognitionJob().run(image(), adaptive: true, reader: { correction, _ in correction ? candidate : baseline })
        XCTAssertEqual(output.lines, baseline.lines)
        XCTAssertEqual(output.readingEvidence?.outcome, .baselineRetained)
        XCTAssertNotNil(output.readingEvidence?.corrected)
    }
    func testCandidateFailureAndTimeoutKeepBaselineWithoutFabricatingCandidate() throws {
        for timedOut in [false, true] {
            let baseline = try incomplete(); var calls: [Bool] = []
            let output = try ReceiptRecognitionJob().run(image(), adaptive: true, reader: { correction, _ in
                calls.append(correction)
                if correction { if timedOut { throw ReceiptReadingFailure.timedOut }; throw InjectedFailure.unavailable }
                return baseline
            })
            XCTAssertEqual(calls, [false, true]); XCTAssertEqual(output.lines, baseline.lines)
            XCTAssertNil(output.readingEvidence?.corrected)
            XCTAssertEqual(output.readingEvidence?.outcome, timedOut ? .timedOut : .failed)
        }
    }
    func testBaselineFailureNeverAttemptsCorrection() throws {
        var count = 0
        XCTAssertThrowsError(try ReceiptRecognitionJob().run(image(), adaptive: true, reader: { _, _ in count += 1; throw InjectedFailure.unavailable }))
        XCTAssertEqual(count, 1)
    }
    func testCancellationBeforeReadingMakesNoRequests() throws {
        let job = ReceiptRecognitionJob(); job.cancel(); var calls = 0
        XCTAssertThrowsError(try job.run(image(), adaptive: true, reader: { _, _ in calls += 1; return try self.incomplete() })) {
            XCTAssertTrue($0 is CancellationError)
        }
        XCTAssertEqual(calls, 0)
    }
    func testCancellationAfterBaselinePreventsSecondPass() throws {
        let job = ReceiptRecognitionJob(), baseline = try incomplete(); var calls: [Bool] = []
        XCTAssertThrowsError(try job.run(image(), adaptive: true, reader: { correction, _ in
            calls.append(correction); job.cancel(); return baseline
        })) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(calls, [false])
    }
    func testCancellationDuringCandidateDoesNotPublishFallbackOrCandidate() throws {
        for visionThrows in [false, true] {
            let job = ReceiptRecognitionJob(), baseline = try incomplete(); var calls: [Bool] = []
            XCTAssertThrowsError(try job.run(image(), adaptive: true, reader: { correction, _ in
                calls.append(correction)
                if correction { job.cancel(); if visionThrows { throw InjectedFailure.unavailable } }
                return baseline
            })) { XCTAssertTrue($0 is CancellationError) }
            XCTAssertEqual(calls, [false, true])
        }
    }
    func testCandidateCancellationErrorIsNeverSwallowedAsOrdinaryFailure() throws {
        let baseline = try incomplete()
        XCTAssertThrowsError(try ReceiptRecognitionJob().run(image(), adaptive: true, reader: { correction, _ in
            if correction { throw CancellationError() }; return baseline
        })) { XCTAssertTrue($0 is CancellationError) }
    }
    func testLegacyExtractionDecodesWithoutReadingEvidence() throws {
        let extraction = try ReceiptParser.extraction(incomplete())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(extraction)) as? [String: Any])
        object.removeValue(forKey: "readingEvidence")
        let decoded = try JSONDecoder().decode(ReceiptExtraction.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.readingEvidence); XCTAssertEqual(decoded, extraction); try decoded.validate()
    }
    func testSelectedPassMismatchAndImpossibleOutcomeFailValidation() throws {
        let (baseline, candidate) = try pair()
        var extraction = try ReceiptParser.extraction(baseline)
        extraction.readingEvidence = ReceiptReadingEvidence(baseline: pass(baseline, corrected: false), corrected: pass(candidate, corrected: true), outcome: .correctionSelected)
        XCTAssertThrowsError(try extraction.validate())
        extraction.readingEvidence = ReceiptReadingEvidence(baseline: pass(baseline, corrected: false), corrected: nil, outcome: .correctionSelected)
        XCTAssertThrowsError(try extraction.validate())
        extraction.readingEvidence = ReceiptReadingEvidence(baseline: pass(baseline, corrected: false), corrected: pass(candidate, corrected: true), outcome: .failed)
        XCTAssertThrowsError(try extraction.validate())
    }
    func testMalformedNonselectedPassCannotHideBehindValidSelectedOCR() throws {
        let baseline = try incomplete()
        let first = baseline.lines[0]
        let invalidConfidence = ReceiptOCRLine(id: UUID(), text: "Fictional", engineConfidence: 2, boundingBox: first.boundingBox)
        let tooLong = ReceiptOCRLine(id: UUID(), text: String(repeating: "F", count: 8193), engineConfidence: 0.9, boundingBox: first.boundingBox)
        for bad in [[first, first], [invalidConfidence], [tooLong], (0..<2001).map { _ in ReceiptOCRLine(id: UUID(), text: "F", engineConfidence: nil, boundingBox: first.boundingBox) }] {
            var extraction = try ReceiptParser.extraction(baseline)
            extraction.readingEvidence = ReceiptReadingEvidence(baseline: pass(baseline, corrected: false),
                corrected: ReceiptReadingPass(lines: bad, revision: 3, usesLanguageCorrection: true), outcome: .baselineRetained)
            XCTAssertThrowsError(try extraction.validate())
        }
    }
    func testAdaptiveEvidenceSurvivesEncryptedSaveAndBackupMerge() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("P403-evidence-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceDirectory = root.appendingPathComponent("source"), targetDirectory = root.appendingPathComponent("target")
        let key = ReceiptBackupTemporaryKey(bytes: Data(repeating: 0x42, count: 32))
        let source = try ReceiptStore(directory: sourceDirectory, keyProvider: key)
        let (baseline, candidate) = try pair()
        var original = try ReceiptParser.extraction(candidate)
        original.readingEvidence = ReceiptReadingEvidence(baseline: pass(baseline, corrected: false), corrected: pass(candidate, corrected: true), outcome: .correctionSelected)
        let draft = ReceiptReviewDraft(parsed: try JSONDecoder().decode(ParsedReceipt.self, from: original.rawParserOutput), useDefaultCurrency: true)
        let bytes = try SyntheticFixture.imageData()
        let record = try await source.create(extraction: original, originalImage: bytes, mediaType: "image/png",
            correction: draft.fields, review: .draft, reviewInput: JSONEncoder().encode(draft))
        try await source.close()
        let reopened = try ReceiptStore(directory: sourceDirectory, keyProvider: key)
        let reloaded = try await reopened.receipt(id: record.id)
        XCTAssertEqual(reloaded, record)
        let archive = root.appendingPathComponent("fictional.slipletbackup")
        try await reopened.exportBackup(to: archive, password: "fictional-private-password", permit: ReceiptOperationPermit())
        let prepared = try await ReceiptBackupPreparation.prepare(url: archive, password: "fictional-private-password", permit: ReceiptOperationPermit())
        let target = try ReceiptStore(directory: targetDirectory, keyProvider: ReceiptBackupTemporaryKey(bytes: Data(repeating: 0x76, count: 32)))
        let preview = try await target.previewBackup(prepared, permit: ReceiptOperationPermit())
        _ = try await target.mergeBackup(prepared, expected: preview, permit: ReceiptOperationPermit())
        let restored = try await target.receipt(id: record.id)
        let restoredImage = try await target.originalImage(receiptID: record.id)
        XCTAssertEqual(restored, record); XCTAssertEqual(restoredImage, bytes)
        XCTAssertEqual(restored?.original.readingEvidence, original.readingEvidence)
        XCTAssertEqual(restored?.current.review, .draft)
        try await reopened.close(); try await target.close()
    }
}
