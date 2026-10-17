import XCTest
@testable import Sliplet
final class ReceiptPurchaseAssemblyTests: XCTestCase {
    private func box(_ text: String, _ x: Double, _ y: Double, _ width: Double = 0.3) throws -> ReceiptOCRLine {
        .init(id: UUID(), text: text, engineConfidence: nil,
              boundingBox: try ReceiptOCRBox(x: x, y: y, width: width, height: 0.02))
    }
    func testLongSKUDescriptionPairsWithUniquePrintedPrice() throws {
        let s = try [box("COSTCO CAD", 0.1, 0.9), box("123456 FICTIONAL TEA", 0.1, 0.7), box("3.00", 0.7, 0.685, 0.1)]
        let p = ReceiptParser.parse(s)
        XCTAssertEqual(p.lines.count, 1); XCTAssertEqual(p.lines.first?.sku, "123456")
        XCTAssertEqual(p.lines.first?.amount, 300)
        XCTAssertEqual(p.lines.first?.description, "123456 FICTIONAL TEA")
        XCTAssertEqual(Set(p.lines.first?.sourceLineIDs ?? []), Set([s[1].id,s[2].id]))
    }
    func testShortNumericQuantityAndUnknownStoreRemainUnpaired() throws {
        for (store,name) in [("COSTCO","1234 TEA"),("COSTCO","2 TEA"),("UNKNOWN STORE","123456 TEA")] {
            let s = try [box(store,0.1,0.9),box(name,0.1,0.7),box("3.00",0.7,0.685,0.1)]
            XCTAssertTrue(ReceiptParser.parse(s).lines.isEmpty)
        }
    }
    func testCompetingPricesDoNotChooseByReconciliation() throws {
        let s = try [box("COSTCO",0.1,0.9),box("123456 TEA",0.1,0.7),box("3.00",0.7,0.685,0.1),box("4.00",0.7,0.715,0.1),box("TOTAL 3.00",0.1,0.4)]
        XCTAssertTrue(ReceiptParser.parse(s).lines.isEmpty)
    }
    func testSKUAnchoredIndentedContinuationPreservesBothSources() throws {
        let s = try [box("COSTCO CAD",0.1,0.9),box("123456 ORGANIC",0.1,0.7),box("ALMOND MILK 5.00",0.14,0.67)]
        let p = ReceiptParser.parse(s)
        XCTAssertEqual(p.lines.first?.description, "123456 ORGANIC ALMOND MILK")
        XCTAssertEqual(p.lines.first?.amount,500); XCTAssertEqual(p.lines.first?.sku,"123456")
        XCTAssertEqual(p.lines.first?.sourceLineIDs,[s[1].id,s[2].id])
        let rows=ReceiptParser.interpretationRows(ReceiptParser.rows(s),knownRetailer:true)
        XCTAssertEqual(rows.flatMap(\.ids).count,s.count); XCTAssertEqual(Set(rows.flatMap(\.ids)),Set(s.map(\.id)))
    }
    func testUnanchoredOrUnindentedNamesNeverJoin() throws {
        for (head,x) in [("ORGANIC",0.14),("123456 ORGANIC",0.1)] {
            let s = try [box("COSTCO",0.1,0.9),box(head,0.1,0.7),box("MILK 5.00",x,0.67)]
            XCTAssertEqual(ReceiptParser.parse(s).lines.first?.description,"MILK")
        }
    }
    func testSummaryTaxCouponAndNextSKUAreNotContinuations() throws {
        for tail in ["TOTAL 5.00","HST 5.00","COUPON 5.00-","987654 MILK 5.00","DEBIT 5.00"] {
            let s = try [box("COSTCO",0.1,0.9),box("123456 ORGANIC",0.1,0.7),box(tail,0.14,0.67)]
            XCTAssertFalse(ReceiptParser.parse(s).lines.contains{$0.sourceLineIDs.contains(s[1].id)})
        }
    }
    func testRepeatedPurchasesRemainSeparate() throws {
        let s = try [box("COSTCO",0.1,0.9),box("123456 TEA",0.1,0.7),box("3.00",0.7,0.685,0.1),box("123456 TEA",0.1,0.6),box("3.00",0.7,0.585,0.1)]
        let p=ReceiptParser.parse(s); XCTAssertEqual(p.lines.count,2)
        XCTAssertTrue(Set(p.lines[0].sourceLineIDs).isDisjoint(with:p.lines[1].sourceLineIDs))
        XCTAssertEqual(p.lines.map(\.amount),[300,300])
    }
    func testMissingGeometryDoesNotBorrowNextAmount() {
        let s=["COSTCO","123456 TEA","3.00"].map {ReceiptOCRLine(id:UUID(),text:$0,engineConfidence:nil)}
        XCTAssertTrue(ReceiptParser.parse(s).lines.isEmpty)
    }
}
