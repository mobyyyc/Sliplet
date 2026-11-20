import XCTest
@testable import Sliplet

final class ReceiptPurchaseOverviewTests: XCTestCase {
    private func record(_ value: Int64, image: UInt8, merchant: String = "FICTIONAL MARKET",
                        month: Int? = 10, currency: ReceiptCurrency = .cad, archived: Bool = false,
                        review: ReceiptRevision.Review = .sourceReviewed, reconciles: Bool = true) -> ReceiptRecord {
        let original = SearchFixture.extraction(merchant: merchant, date: month.map { try! ReceiptDate(year: 2026, month: $0, day: 8) })
        var fields = original.fields
        fields.currency = currency
        fields.items = [fields.items[0]]
        fields.items[0].amount = ReceiptMoney(minorUnits: reconciles ? value : value + 1, currency: currency)
        fields.total = ReceiptMoney(minorUnits: value, currency: currency)
        let time = original.capturedAt
        return ReceiptRecord(id: UUID(), createdAt: time, updatedAt: time, original: original,
                             asset: .init(id: UUID(), mediaType: "image/png", byteCount: 1, sha256: Data(repeating: image, count: 32)),
                             revisions: [.init(id: UUID(), createdAt: time, fields: fields, review: review)],
                             organization: ReceiptOrganization(archived: archived))
    }

    func testReviewedArchiveRefundMerchantTotalsAndSeparateCurrencies() throws {
        let usd = try ReceiptCurrency(code: "USD", minorUnitScale: 2)
        let purchase = record(1299, image: 1, archived: true)
        let refund = record(-199, image: 2)
        let other = record(450, image: 3, merchant: "FICTIONAL DELI")
        let foreign = record(1300, image: 4, currency: usd)
        let older = record(999, image: 5, month: 9)
        let overview = ReceiptPurchaseOverview(records: [refund, purchase, older, other, foreign])

        XCTAssertEqual(overview.monthKeys, ["2026-10", "2026-09"])
        let cad = try XCTUnwrap(overview.months["2026-10"]?.currencies["CAD"])
        XCTAssertEqual(cad.all.net, Decimal(string: "15.50"))
        XCTAssertEqual(cad.all.count, 3)
        XCTAssertEqual(Set(cad.all.entries.map(\.id)), Set([purchase.id, refund.id, other.id]))
        XCTAssertEqual(cad.merchantsBySpending, ["FICTIONAL MARKET", "FICTIONAL DELI"])
        XCTAssertEqual(cad.merchants["FICTIONAL MARKET"]?.net, Decimal(11))
        XCTAssertEqual(overview.months["2026-10"]?.currencies["USD"]?.all.net, Decimal(13))
        XCTAssertEqual(overview.months["2026-09"]?.currencies["CAD"]?.all.net, Decimal(string: "9.99"))
    }

    func testCopiesCollapseOnlyWhenImageAndReviewedFieldsAgree() throws {
        let first = record(325, image: 1)
        let copy = record(325, image: 1)
        let differentPhoto = record(325, image: 2)
        let conflictingReview = record(425, image: 1)
        let previousMonth = record(325, image: 1, month: 9)
        let overview = ReceiptPurchaseOverview(records: [first, copy, differentPhoto, conflictingReview, previousMonth])
        let summary = try XCTUnwrap(overview.months["2026-10"]?.currencies["CAD"]?.all)
        XCTAssertEqual(summary.net, Decimal(string: "10.75"))
        XCTAssertEqual(summary.count, 3)
        XCTAssertEqual(summary.entries.count, 3)
        XCTAssertEqual(summary.copies.count, 1)
        XCTAssertTrue(summary.entries.allSatisfy { !$0.isDuplicate })
        let excluded = try XCTUnwrap(summary.copies.first)
        XCTAssertTrue([first.id, copy.id].contains(excluded.id))
        XCTAssertEqual(overview.months["2026-09"]?.currencies["CAD"]?.all.count, 1)
    }

    func testDraftsAndMissingDatesStayAccessibleWithoutEnteringTotals() throws {
        let draft = record(500, image: 1, review: .draft)
        let mismatched = record(400, image: 2, reconciles: false)
        let undated = record(700, image: 3, month: nil)
        let overview = ReceiptPurchaseOverview(records: [draft, mismatched, undated])
        let month = try XCTUnwrap(overview.months["2026-10"])
        XCTAssertTrue(month.currencies.isEmpty)
        XCTAssertEqual(Set(month.needsReview.map(\.id)), Set([draft.id, mismatched.id]))
        XCTAssertEqual(overview.undated.map(\.id), [undated.id])
    }
}
