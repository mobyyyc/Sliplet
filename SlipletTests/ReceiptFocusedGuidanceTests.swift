import XCTest
@testable import Sliplet

final class ReceiptFocusedGuidanceTests: XCTestCase {
    private func extraction(_ text: String) throws -> ReceiptExtraction {
        try ReceiptParser.extraction(OCRResult(lines: text.split(separator: "\n").map {
            ReceiptOCRLine(id: UUID(), text: String($0), engineConfidence: nil)
        }, revision: 3))
    }
    func testMerchantAndCurrencyConflictsMergeIntoRequiredDetailsWithAllEvidence() throws {
        let e = try extraction("COSTCO\nNOFRILLS\nCAD\nUSD\n2026-10-09\nTEA 1.00\nTOTAL 1.00")
        let d = ReceiptReviewDraft(fields: e.fields)
        let checks = ReceiptReviewGuidance.checks(draft: d, extraction: e).filter { $0.target == .receipt }
        XCTAssertEqual(checks.count, 1)
        let check = try XCTUnwrap(checks.first)
        let ids = e.issues.filter { ["merchant_conflicting", "currency_conflicting"].contains($0.code) }.flatMap(\.sourceLineIDs)
        XCTAssertFalse(ids.isEmpty); XCTAssertEqual(Set(check.sourceLineIDs), Set(ids))
        XCTAssertTrue(check.requiresCorrection); XCTAssertFalse(check.isChecked(in: d))
    }
    func testNegativeAndAmbiguousSummariesKeepTheirOwnSourceAndDestination() throws {
        for (subtotal, total) in [("SUBTOTAL -1,00", "TOTAL -1,00"), ("SUBTOTAL 1.00 2.00", "TOTAL 1.00 2.00"), ("SUBTOTAL 1,2", "TOTAL 1,2")] {
            let e = try extraction("COSTCO CAD\n2026-10-09\nTEA 1.00\n" + subtotal + "\n" + total)
            let d = ReceiptReviewDraft(fields: e.fields)
            let checks = ReceiptReviewGuidance.checks(draft: d, extraction: e)
            for (target, text) in [(ReceiptReviewGuidance.Target.subtotal, subtotal), (.total, total)] {
                let check = try XCTUnwrap(checks.first { $0.target == target && $0.requiresCorrection })
                XCTAssertEqual(check.sourceLineIDs, [try XCTUnwrap(e.rawOCR.first { $0.text == text }).id])
            }
            XCTAssertNil(d.fields.total); XCTAssertNil(d.fields.subtotal); XCTAssertFalse(d.canFinalize)
        }
    }
    func testAdvisoryConflictPersistsAfterUserSuppliesAValue() throws {
        let e = try extraction("COSTCO\nNOFRILLS\nCAD\nTEA 1.00\nTOTAL 1.00")
        var d = ReceiptReviewDraft(fields: e.fields); d.merchant = "FICTIONAL CHOSEN STORE"
        let check = try XCTUnwrap(ReceiptReviewGuidance.checks(draft: d, extraction: e).first { $0.title == "Verify the merchant" })
        XCTAssertFalse(check.requiresCorrection); XCTAssertFalse(check.sourceLineIDs.isEmpty)
        XCTAssertFalse(check.isChecked(in: d)); XCTAssertEqual(d.merchant, "FICTIONAL CHOSEN STORE")
    }
    func testCurrencyChangeReopensMonetaryAndSourceChecksButNotDate() {
        var d = ReceiptReviewDraft(); d.currency = "CAD"; d.date = "2026-10-09"; d.lines = [.blank()]
        for target in [ReceiptReviewGuidance.Target.subtotal, .total, .line(d.lines[0].id), .source, .date] {
            let check = ReceiptReviewGuidance(id: "check", title: "Check", message: "", target: target, sourceLineIDs: [], requiresCorrection: false)
            d.currency = "CAD"; d.guidanceChecks = [check.id: check.signature(in: d)]
            XCTAssertTrue(check.isChecked(in: d)); d.currency = "USD"
            XCTAssertEqual(check.isChecked(in: d), target == .date)
        }
    }
    func testUnassignedRereadRequiresLineAndCannotTargetReceiptTotals() {
        let check = ReceiptReviewGuidance(id: "source", title: "Check", message: "", target: .source, sourceLineIDs: [], requiresCorrection: false)
        XCTAssertTrue(check.rereadFields(lineID: nil).isEmpty)
        XCTAssertEqual(check.rereadFields(lineID: UUID()), [.amount, .description, .quantity])
    }
    @MainActor func testCorrectingSummaryNeverMutatesOriginalOrConfirmsFullReview() throws {
        let e = try extraction("COSTCO CAD\n2026-10-09\nTEA 1.00\nSUBTOTAL 1.00\nTOTAL -1,00")
        let w = ReceiptWorkspace(); w.active = true; w.flow = .review
        w.image = try ReceiptImage.decode(SyntheticFixture.imageData()); w.extraction = e
        w.draft = ReceiptReviewDraft(fields: e.fields)
        let check = try XCTUnwrap(ReceiptReviewGuidance.checks(draft: w.draft, extraction: e).first { $0.target == .total })
        let baseline = w.draft; var working = baseline; working.total = "1.00"
        XCTAssertEqual(w.draft, baseline, "Editing a local copy does not Apply")
        w.applyFocusedCorrection(working, check: check)
        XCTAssertEqual(w.draft.total, "1.00"); XCTAssertEqual(w.extraction, e)
        XCTAssertFalse(w.draft.sourceChecked); XCTAssertFalse(w.draft.canFinalize)
    }
}
