import XCTest
import CryptoKit
@testable import Sliplet

/// Fictional region observations only; these tests never read private receipts or run OCR.
final class ReceiptAssistedReadingTests: XCTestCase {
    private let fixtureAssetHash = Data(repeating: 0x41, count: 32)
    private func observation(_ text: String) throws -> ReceiptOCRLine {
        ReceiptOCRLine(id: UUID(), text: text, engineConfidence: 0.8,
            boundingBox: try ReceiptOCRBox(x: 0.2, y: 0.3, width: 0.4, height: 0.05))
    }
    private func choices(_ text: String, field: ReceiptAssistedField, currency: ReceiptCurrency? = .cad) throws -> [ReceiptAssistedChoice] {
        ReceiptAssistedReading.choices(lines: [try observation(text)], field: field, currency: currency)
    }
    private func event(_ text: String = "12.34", field: ReceiptAssistedField = .total,
                       previous: String = "", lineID: UUID? = nil) throws -> ReceiptAssistedReading {
        let lines = [try observation(text)]
        let choice = try XCTUnwrap(ReceiptAssistedReading.choices(lines: lines, field: field, currency: .cad).first)
        return ReceiptAssistedReading(id: UUID(), date: Date(timeIntervalSince1970: 1_800_000_000),
            assetSHA256: fixtureAssetHash, region: try ReceiptOCRBox(x: 0.1, y: 0.2, width: 0.6, height: 0.3),
            revision: 3, observations: lines, choice: choice, field: field, lineID: lineID,
            previousValue: previous, currency: .cad)
    }
    private func mutated(_ value: ReceiptAssistedReading, _ edit: (inout [String: Any]) -> Void) throws -> ReceiptAssistedReading {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
        edit(&object)
        return try JSONDecoder().decode(ReceiptAssistedReading.self, from: JSONSerialization.data(withJSONObject: object))
    }
    func testLiteralDescriptionRetainsUnicodeAndExactUTF16Range() throws {
        let values = try choices("  🧾 Fictional 苹果  ", field: .description)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0].literal, "🧾 Fictional 苹果")
        XCTAssertEqual(values[0].value, values[0].literal)
        XCTAssertEqual(values[0].rangeStart, 2)
        XCTAssertEqual(values[0].rangeLength, (values[0].literal as NSString).length)
    }
    func testMultipleAmountsRemainSeparateExplicitChoices() throws {
        let values = try choices("Tax 1.23 Total 12.34", field: .total)
        XCTAssertEqual(values.map(\.value), ["1.23", "12.34"])
        XCTAssertEqual(values.map(\.literal), ["1.23", "12.34"])
        XCTAssertEqual(Set(values.map(\.id)).count, 2)
    }
    func testExactMoneyPreservesSignsAndNeverRoundsOrInventsDecimals() throws {
        XCTAssertEqual(try choices("-$12.34", field: .amount).map(\.value), ["-12.34"])
        XCTAssertEqual(try choices("12.34-", field: .amount).map(\.value), ["-12.34"])
        for text in ["12,34", "12.345", "(12.34)", "- $12.34", "( 12.34 )", "13.00 %", "12.34 /kg"] {
            XCTAssertTrue(try choices(text, field: .amount).isEmpty, "Rejected unsupported literal syntax")
        }
        XCTAssertTrue(try choices("12.34", field: .amount, currency: nil).isEmpty)
        XCTAssertTrue(try choices("12.34", field: .amount, currency: ExactInput.currency("JPY")).isEmpty)
        XCTAssertEqual(try choices("12", field: .amount, currency: ExactInput.currency("JPY")).map(\.value), ["12"])
    }
    func testDatesDoNotGuessMonthDayOrderOrInvalidCalendarDates() throws {
        XCTAssertEqual(try choices("DATE 2026/10/07", field: .date).map(\.value), ["2026-10-07"])
        XCTAssertEqual(try choices("2026-10-07", field: .date).map(\.literal), ["2026-10-07"])
        for text in ["10/07/2026", "07/10/26", "2026-02-30", "2026/10-07"] {
            XCTAssertTrue(try choices(text, field: .date).isEmpty)
        }
    }
    func testQuantityIsExplicitPositiveDecimalWithoutUnitsOrRounding() throws {
        XCTAssertEqual(try choices("0.375 kg", field: .quantity).map(\.value), ["0.375"])
        for text in ["0", "-1", "- 1", "( 1 )", "0,375", "2x", "1/2", "12%"] {
            XCTAssertTrue(try choices(text, field: .quantity).isEmpty)
        }
    }
    func testUseChangesOnlyTargetAndPreservesOriginalSourceIDs() throws {
        var draft = ReceiptReviewDraft()
        draft.currency = "CAD"; draft.merchant = "Fictional"; draft.sourceChecked = true
        let sourceID = UUID()
        var line = EditableReceiptLine.blank(); line.name = "Fictional pears"; line.amount = "1.00"; line.sourceLineIDs = [sourceID]
        draft.lines = [line]
        let reading = try event(field: .amount, previous: "1.00", lineID: line.id)
        try draft.useAssistedReading(reading)
        XCTAssertEqual(draft.lines[0].amount, "12.34")
        XCTAssertEqual(draft.lines[0].sourceLineIDs, [sourceID])
        XCTAssertEqual(draft.lines[0].name, "Fictional pears")
        XCTAssertEqual(draft.merchant, "Fictional")
        XCTAssertFalse(draft.sourceChecked)
        XCTAssertEqual(draft.assistedReadings, [reading])
    }
    func testSubtotalClearsNotPrintedAndConfirmation() throws {
        var draft = ReceiptReviewDraft(); draft.currency = "CAD"
        draft.subtotalNotPrinted = true; draft.sourceChecked = true
        try draft.useAssistedReading(event(field: .subtotal))
        XCTAssertFalse(draft.subtotalNotPrinted); XCTAssertFalse(draft.sourceChecked)
        XCTAssertEqual(draft.subtotal, "12.34")
    }
    func testStalePreviousValueMissingLineAndCurrencyMismatchAreTransactional() throws {
        var draft = ReceiptReviewDraft(); draft.currency = "CAD"; draft.total = "3.00"
        let before = draft
        XCTAssertThrowsError(try draft.useAssistedReading(event()))
        XCTAssertEqual(draft, before)
        XCTAssertThrowsError(try draft.useAssistedReading(event(field: .amount, lineID: UUID())))
        XCTAssertEqual(draft, before)
        draft.currency = "USD"
        let beforeUSD = draft
        XCTAssertThrowsError(try draft.useAssistedReading(event(previous: "3.00")))
        XCTAssertEqual(draft, beforeUSD)
    }
    func testMalformedChoiceRangeLiteralValueOrMembershipIsRejected() throws {
        let good = try event()
        for (key, value) in [("rangeStart", -1 as Any), ("rangeLength", Int.max as Any),
                             ("literal", "other" as Any), ("value", "99.00" as Any),
                             ("observationID", UUID().uuidString as Any), ("id", "wrong" as Any)] {
            let bad = try mutated(good) { object in
                var choice = object["choice"] as! [String: Any]; choice[key] = value; object["choice"] = choice
            }
            XCTAssertThrowsError(try bad.validate(assetSHA256: fixtureAssetHash))
        }
    }
    func testWrongImageTargetAndRegionAreRejected() throws {
        let good = try event()
        XCTAssertThrowsError(try good.validate(assetSHA256: Data(repeating: 0x42, count: 32)))
        let badTarget = try mutated(good) { $0["lineID"] = UUID().uuidString }
        XCTAssertThrowsError(try badTarget.validate(assetSHA256: fixtureAssetHash))
        let badRegion = try mutated(good) { $0["region"] = ["x": 0.8, "y": 0.8, "width": 0.1, "height": 0.1] }
        XCTAssertThrowsError(try badRegion.validate(assetSHA256: fixtureAssetHash))
    }
    func testHistoricalEditsSurviveLaterChangesAndDeletedLine() throws {
        var draft = ReceiptReviewDraft(); draft.currency = "CAD"
        let line = EditableReceiptLine.blank(); draft.lines = [line]
        try draft.useAssistedReading(event(field: .amount, lineID: line.id))
        draft.lines.removeAll()
        try draft.validateAssistedReadings(assetSHA256: fixtureAssetHash)
        XCTAssertNotNil(draft.assistedReadings)
    }
    func testDuplicateAndOverCapHistoryRejectWithoutPartialMutation() throws {
        var draft = ReceiptReviewDraft(); draft.currency = "CAD"
        let first = try event()
        try draft.useAssistedReading(first)
        let before = draft
        XCTAssertThrowsError(try draft.useAssistedReading(first))
        XCTAssertEqual(draft, before)
        draft.assistedReadings = try (0..<ReceiptAssistedReading.maximumEvents).map { _ in try event() }
        let full = draft
        XCTAssertThrowsError(try draft.useAssistedReading(event(previous: "12.34")))
        XCTAssertEqual(draft, full)
        draft.assistedReadings = [first, first]
        XCTAssertFalse(draft.canSaveDraft)
    }
    func testLegacyDraftDecodesWithoutAssistedHistory() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ReceiptReviewDraft())) as? [String: Any])
        object.removeValue(forKey: "assistedReadings")
        let decoded = try JSONDecoder().decode(ReceiptReviewDraft.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.assistedReadings)
    }
    func testHistoryRoundTripPreservesLiteralEvidence() throws {
        var draft = ReceiptReviewDraft(); draft.currency = "CAD"
        try draft.useAssistedReading(event())
        let decoded = try JSONDecoder().decode(ReceiptReviewDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(decoded, draft)
        try decoded.validateAssistedReadings(assetSHA256: fixtureAssetHash)
    }
    @MainActor func testEncryptedSaveReopenAndBackupMergeRetainBoundHistoryAndRejectWrongAsset() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("P405-assisted-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let key = ReceiptBackupTemporaryKey(bytes: Data(repeating: 0x61, count: 32))
        let sourceDirectory = root.appendingPathComponent("source")
        let store = try ReceiptStore(directory: sourceDirectory, keyProvider: key)
        let image = try SyntheticFixture.imageData()
        let imageHash = Data(SHA256.hash(data: image))
        let original = try ReceiptParser.extraction(OCRResult(lines: [try observation("FICTIONAL COSTCO CAD")], revision: 3))
        var draft = ReceiptReviewDraft(fields: original.fields)
        let wrongAsset = try event()
        var malformed = draft
        try malformed.useAssistedReading(wrongAsset)
        do {
            _ = try await store.create(extraction: original, originalImage: image, mediaType: "image/png",
                correction: malformed.fields, review: .draft, reviewInput: JSONEncoder().encode(malformed))
            XCTFail("Asset-mismatched assisted evidence must not be saved")
        } catch { XCTAssertEqual(error as? ReceiptValidationError, .invalidEvidence) }
        let correct = try mutated(wrongAsset) { $0["assetSHA256"] = imageHash.base64EncodedString() }
        try draft.useAssistedReading(correct)
        let saved = try await store.create(extraction: original, originalImage: image, mediaType: "image/png",
            correction: draft.fields, review: .draft, reviewInput: JSONEncoder().encode(draft))
        do {
            _ = try await store.revise(id: saved.id, expectedRevision: saved.current.id, fields: malformed.fields,
                review: .draft, reviewInput: JSONEncoder().encode(malformed))
            XCTFail("Revision save must reject mismatched assisted image provenance")
        } catch { XCTAssertEqual(error as? ReceiptValidationError, .invalidEvidence) }
        try await store.close()
        let reopened = try ReceiptStore(directory: sourceDirectory, keyProvider: key)
        let reloaded = try await reopened.receipt(id: saved.id)
        XCTAssertEqual(reloaded, saved)
        XCTAssertEqual(reloaded?.original, original)
        let archive = root.appendingPathComponent("fictional-assisted.slipletbackup")
        try await reopened.exportBackup(to: archive, password: "fictional-assistance-password", permit: ReceiptOperationPermit())
        let prepared = try await ReceiptBackupPreparation.prepare(url: archive, password: "fictional-assistance-password", permit: ReceiptOperationPermit())
        let target = try ReceiptStore(directory: root.appendingPathComponent("target"),
            keyProvider: ReceiptBackupTemporaryKey(bytes: Data(repeating: 0x62, count: 32)))
        let preview = try await target.previewBackup(prepared, permit: ReceiptOperationPermit())
        _ = try await target.mergeBackup(prepared, expected: preview, permit: ReceiptOperationPermit())
        let restored = try await target.receipt(id: saved.id)
        let restoredImage = try await target.originalImage(receiptID: saved.id)
        XCTAssertEqual(restored, saved)
        XCTAssertEqual(restoredImage, image)
        let restoredInput = try XCTUnwrap(restored?.current.reviewInput)
        let restoredDraft = try JSONDecoder().decode(ReceiptReviewDraft.self, from: restoredInput)
        XCTAssertEqual(restoredDraft.assistedReadings, [correct])
        XCTAssertFalse(restoredDraft.sourceChecked)
        try restoredDraft.validateAssistedReadings(assetSHA256: imageHash)
        try await reopened.close(); try await target.close()
    }

}
