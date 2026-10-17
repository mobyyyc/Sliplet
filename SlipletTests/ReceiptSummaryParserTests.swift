import XCTest
@testable import Sliplet

final class ReceiptSummaryParserTests: XCTestCase {
    private func source(_ text: String) -> [ReceiptOCRLine] {
        text.split(separator: "\n").map { .init(id: UUID(), text: String($0), engineConfidence: nil) }
    }
    private func box(_ text: String, x: Double, y: Double, width: Double = 0.25) throws -> ReceiptOCRLine {
        .init(id: UUID(), text: text, engineConfidence: nil,
              boundingBox: try ReceiptOCRBox(x: x, y: y, width: width, height: 0.02))
    }
    func testTotalNamedProductsDoNotStopPurchases() {
        let p = ReceiptParser.parse(source("FICTIONAL SHOP CAD\nTOTAL CEREAL 3.00\nTOTAL PROTEIN BAR 2.00\nBREAD 1.00\nTOTAL 6.00"))
        XCTAssertEqual(p.lines.map(\.description), ["TOTAL CEREAL", "TOTAL PROTEIN BAR", "BREAD"])
        XCTAssertEqual(p.total, 600)
    }
    func testSubtotalDoesNotDiscardLaterDepartmentPurchases() {
        let p = ReceiptParser.parse(source("FICTIONAL SHOP CAD\nSOAP 2.00\nSUBTOTAL 2.00\nBREAD 1.00\nHST 0.26\nTOTAL 3.26\nADVERTISEMENT 9.00"))
        XCTAssertEqual(p.lines.map(\.description), ["SOAP", "BREAD", "HST"])
        XCTAssertEqual(p.subtotal, 200); XCTAssertEqual(p.total, 326)
    }
    func testSummaryAliasesAndDecorations() {
        for label in ["GRAND TOTAL", "TOTAL DUE", "AMOUNT DUE", "TOTAL À PAYER", "TOTAL A PAYER", "TOTAL TTC", "# TOTAL", "• TOTAL"] {
            let p = ReceiptParser.parse(source("FICTIONAL SHOP CAD\nSOAP 3.00\n\(label): CAD 3.00"))
            XCTAssertEqual(p.total, 300, label); XCTAssertEqual(p.lines.count, 1, label)
        }
        for label in ["SUBTOTAL", "SUB TOTAL", "SOUS-TOTAL", "SOUS TOTAL"] {
            XCTAssertEqual(ReceiptParser.parse(source("\(label): 3,00")).subtotal, 300)
        }
    }
    func testCountsSavingsAndTenderAreNotTotalsOrPurchases() {
        let p = ReceiptParser.parse(source("SOAP 3.00\nTOTAL ITEMS 1.00\nTOTAL NUMBER OF ITEMS 1.00\nTOTAL SAVINGS 2.00\nTOTAL DISCOUNT 2.00\nDEBIT 3.00\nADVERTISEMENT 7.00"))
        XCTAssertNil(p.total); XCTAssertEqual(p.lines.map(\.description), ["SOAP"])
    }
    func testUnknownMerchantDetachedSummaryWithCurrencyUsesOnlyLocalGeometry() throws {
        let s = try [box("FICTIONAL MARKET", x: 0.1, y: 0.9), box("SOAP 3.00", x: 0.1, y: 0.7),
                     box("TOTAL DUE", x: 0.1, y: 0.5), box("CAD 3.00", x: 0.7, y: 0.47, width: 0.15)]
        let p = ReceiptParser.parse(s)
        XCTAssertEqual(p.total, 300); XCTAssertEqual(p.currency, .cad)
        XCTAssertEqual(p.lines.map(\.description), ["SOAP"])
        XCTAssertEqual(ReceiptParser.interpretationRows(ReceiptParser.rows(s), knownRetailer: false).flatMap(\.ids).count, s.count)
        XCTAssertEqual(Set(ReceiptParser.interpretationRows(ReceiptParser.rows(s), knownRetailer: false).flatMap(\.ids)), Set(s.map(\.id)))
    }
    func testDetachedTotalCannotBorrowAcrossPaymentOrWithoutGeometry() throws {
        XCTAssertNil(ReceiptParser.parse(source("TOTAL\n3.00\nDEBIT 3.00")).total)
        let s = try [box("TOTAL", x: 0.1, y: 0.5), box("DEBIT", x: 0.1, y: 0.48), box("3.00", x: 0.7, y: 0.46, width: 0.1)]
        XCTAssertNil(ReceiptParser.parse(s).total)
    }
    func testCompetingDetachedAmountsStayUnknown() throws {
        let s = try [box("TOTAL", x: 0.1, y: 0.5), box("3.00", x: 0.7, y: 0.47, width: 0.1), box("4.00", x: 0.7, y: 0.53, width: 0.1)]
        XCTAssertNil(ReceiptParser.parse(s).total)
    }
    func testMalformedAndCompetingSummariesNeverInventMoney() {
        for value in ["300", "3 00", "|3.00", "(3.00)", "- 3.00", "3.00 +", "3.00 H", "3.00 4.00"] {
            let p = ReceiptParser.parse(source("SOAP 3.00\nTOTAL \(value)"))
            XCTAssertNil(p.total, value)
            XCTAssertEqual(p.lines.count, 1, value)
        }
        let p = ReceiptParser.parse(source("TOTAL 3.00\nTOTAL DUE 4.00"))
        XCTAssertNil(p.total)
        XCTAssertTrue(p.issues.contains { $0.code == "total_conflicting" })
    }
    func testMalformedSubtotalDoesNotSuppressFollowingPurchase() {
        let p = ReceiptParser.parse(source("SUBTOTAL 3.00 4.00\nSOAP 2.00\nDEBIT 2.00"))
        XCTAssertNil(p.total); XCTAssertEqual(p.lines.map(\.description), ["SOAP"])
    }
    func testUnresolvedFinalTotalStillProtectsTheFooter() {
        let p = ReceiptParser.parse(source("SOAP 2.00\nSUBTOTAL 2.00\nTOTAL 2,00-\nFOOTER OFFER 5.00"))
        XCTAssertNil(p.total); XCTAssertEqual(p.lines.map(\.description), ["SOAP"])
    }
    func testSignsArePreservedAndRefundContextIsNotInvented() {
        XCTAssertEqual(ReceiptParser.parse(source("TOTAL -3.00")).total, -300)
        let p = ReceiptParser.parse(source("TOTAL 3,00-"))
        XCTAssertNil(p.total)
        XCTAssertTrue(p.issues.contains { $0.code == "negative_summary_check_source" })
    }
    func testUnpricedLabelCannotStealProductOrTaxAmount() throws {
        for neighbor in ["BREAD 3.00", "HST 3.00", "DEBIT 3.00"] {
            let s = try [box("TOTAL", x: 0.1, y: 0.5), box(neighbor, x: 0.5, y: 0.47)]
            XCTAssertNil(ReceiptParser.parse(s).total)
        }
    }
    func testUnknownStoreProductStillCompetesForDetachedPrice() throws {
        let s = try [box("FICTIONAL MARKET", x: 0.1, y: 0.9),
                     box("TOTAL", x: 0.1, y: 0.5),
                     box("3.00", x: 0.7, y: 0.47, width: 0.1),
                     box("BREAD", x: 0.1, y: 0.455)]
        let p = ReceiptParser.parse(s)
        XCTAssertNil(p.total)
        XCTAssertTrue(p.lines.isEmpty)
        XCTAssertEqual(ReceiptParser.interpretationRows(ReceiptParser.rows(s), knownRetailer: false).count, s.count)
    }

}
