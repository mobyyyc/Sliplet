import XCTest
@testable import Sliplet

@MainActor final class ReceiptCurrencyContextTests: XCTestCase {
    private func extraction(currency: String = "") throws -> ReceiptExtraction {
        let source = "FICTIONAL MARKET \(currency)\n2026-10-07\nFICTIONAL APPLE 1.23\nSUBTOTAL 1.23\nTOTAL 1.23"
        return try ReceiptParser.extraction(OCRResult(lines: source.split(separator: "\n").map {
            ReceiptOCRLine(id: UUID(), text: String($0), engineConfidence: 0.9)
        }, revision: 3))
    }
    func testImportDefaultContextDoesNotRewriteExtractionOrClaimReview() throws {
        let original = try extraction()
        let parsed = try JSONDecoder().decode(ParsedReceipt.self, from: original.rawParserOutput)
        let strict = ReceiptReviewDraft(parsed: parsed)
        let imported = ReceiptReviewDraft(parsed: parsed, useDefaultCurrency: true)
        XCTAssertNil(original.fields.currency); XCTAssertNil(original.fields.items.first?.amount)
        XCTAssertEqual(strict.currency, ""); XCTAssertNil(strict.currencyOrigin)
        XCTAssertEqual(imported.currency, "CAD"); XCTAssertEqual(imported.currencyOrigin, .defaultCAD)
        XCTAssertEqual(imported.fields.items.first?.amount?.minorUnits, 123)
        XCTAssertEqual(imported.fields.items.first?.sourceLineIDs, original.fields.items.first?.sourceLineIDs)
        XCTAssertFalse(imported.sourceChecked); XCTAssertFalse(imported.canFinalize); XCTAssertTrue(imported.canSaveDraft)
        XCTAssertNotNil(imported.currencyContextMessage)
        XCTAssertNil(try JSONDecoder().decode(ParsedReceipt.self, from: original.rawParserOutput).currency)
    }
    func testExplicitRecognizedCurrencyWinsAndExistingUnknownDraftDoesNotReceiveDefault() throws {
        let original = try extraction(currency: "USD")
        let parsed = try JSONDecoder().decode(ParsedReceipt.self, from: original.rawParserOutput)
        let imported = ReceiptReviewDraft(parsed: parsed, useDefaultCurrency: true)
        XCTAssertEqual(imported.currency, "USD"); XCTAssertNil(imported.currencyOrigin)
        var legacy = ReceiptReviewDraft(); legacy.merchant = "Fictional"
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        object.removeValue(forKey: "currencyOrigin")
        let decoded = try JSONDecoder().decode(ReceiptReviewDraft.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.currency, ""); XCTAssertNil(decoded.currencyOrigin)
    }
    func testConflictingPrintedCurrenciesDoNotSilentlyUseDefault() throws {
        let original = try extraction(currency: "CAD USD")
        let parsed = try JSONDecoder().decode(ParsedReceipt.self, from: original.rawParserOutput)
        XCTAssertTrue(parsed.issues.contains { $0.code == "currency_conflicting" })
        let draft = ReceiptReviewDraft(parsed: parsed, useDefaultCurrency: true)
        XCTAssertEqual(draft.currency, ""); XCTAssertNil(draft.currencyOrigin)
    }
    func testUnitPriceSurvivesCurrencyEditAndInexactCurrencyChangeCannotSave() throws {
        var draft = ReceiptReviewDraft(); draft.applyDefaultCurrency()
        draft.lines = [.init(id: UUID(), kind: "purchase", name: "Fictional", quantity: "1", amount: "1.23", sourceLineIDs: [],
            unitPrice: ReceiptMoney(minorUnits: 123, currency: .cad))]
        draft.currency = "USD"
        XCTAssertEqual(draft.currencyOrigin, .userSelected)
        XCTAssertEqual(draft.fields.items.first?.unitPrice?.minorUnits, 123)
        XCTAssertEqual(draft.fields.items.first?.unitPrice?.currency.code, "USD"); XCTAssertTrue(draft.canSaveDraft)
        draft.currency = "JPY"; draft.lines[0].amount = "123"
        XCTAssertEqual(draft.lines[0].editableUnitPrice, "1.23"); XCTAssertFalse(draft.canSaveDraft)
        XCTAssertTrue(draft.reconciliation.issues.contains { $0.contains("unit prices") })
        draft.lines[0].unitPriceText = "123"
        XCTAssertTrue(draft.canSaveDraft); XCTAssertEqual(draft.fields.items.first?.unitPrice?.minorUnits, 123)
        XCTAssertEqual(draft.fields.items.first?.unitPrice?.currency.code, "JPY")
        let reloaded = try JSONDecoder().decode(ReceiptReviewDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(reloaded, draft); XCTAssertEqual(reloaded.fields, draft.fields)
    }
    func testCurrencyEditClearsFullReviewAndCancelWorkingCopyPreservesContext() {
        let model = ReceiptWorkspace(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            keyProvider: ReceiptBackupTemporaryKey(bytes: Data(repeating: 0x44, count: 32)))
        model.draft.applyDefaultCurrency(); model.draft.sourceChecked = true
        let before = model.draft
        var working = before; working.currency = "USD"
        XCTAssertEqual(model.draft, before)
        model.updateDraft { $0 = working }
        XCTAssertEqual(model.draft.currencyOrigin, .userSelected); XCTAssertFalse(model.draft.sourceChecked)
    }
    func testDraftMetadataAndCurrencyContextSurviveEncryptedBackupRestore() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("P404-currency-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try ReceiptStore(directory: root.appendingPathComponent("source"), keyProvider: ReceiptBackupTemporaryKey(bytes: Data(repeating: 0x52, count: 32)))
        let target = try ReceiptStore(directory: root.appendingPathComponent("target"), keyProvider: ReceiptBackupTemporaryKey(bytes: Data(repeating: 0x73, count: 32)))
        let original = try extraction()
        var draft = ReceiptReviewDraft(parsed: try JSONDecoder().decode(ParsedReceipt.self, from: original.rawParserOutput), useDefaultCurrency: true)
        draft.lines[0].unit = "kg"; draft.lines[0].quantity = "1"; draft.lines[0].sku = "FIC-001"; draft.lines[0].taxMarker = "FIC-T"; draft.lines[0].unitPriceText = "1.23"
        let created = try await source.create(extraction: original, originalImage: SyntheticFixture.imageData(), mediaType: "image/png",
            correction: draft.fields, review: .draft, reviewInput: JSONEncoder().encode(draft))
        let archive = root.appendingPathComponent("fixture.slipletbackup")
        try await source.exportBackup(to: archive, password: "fictional-backup-password", permit: ReceiptOperationPermit())
        let prepared = try await ReceiptBackupPreparation.prepare(url: archive, password: "fictional-backup-password", permit: ReceiptOperationPermit())
        let preview = try await target.previewBackup(prepared, permit: ReceiptOperationPermit())
        _ = try await target.mergeBackup(prepared, expected: preview, permit: ReceiptOperationPermit())
        let loaded = try await target.receipt(id: created.id)
        let restored = try XCTUnwrap(loaded)
        let input = try JSONDecoder().decode(ReceiptReviewDraft.self, from: XCTUnwrap(restored.current.reviewInput))
        XCTAssertEqual(input, draft); XCTAssertEqual(restored.current.fields, draft.fields)
        XCTAssertEqual(restored.original, original); XCTAssertNil(restored.original.fields.currency)
        XCTAssertEqual(input.currencyOrigin, .defaultCAD)
        try await source.close(); try await target.close()
    }
}
