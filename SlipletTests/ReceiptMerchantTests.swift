import XCTest
@testable import Sliplet

final class ReceiptMerchantTests: XCTestCase {
    private func source(_ text: String) -> [ReceiptOCRLine] {
        text.split(separator: "\n").map { .init(id: UUID(), text: String($0), engineConfidence: nil) }
    }
    func testExplicitAliasesAndNormalization() {
        for (name, expected) in [("no frills", "NOFRILLS"), ("ALEX RIVER NOFRILLS", "NOFRILLS"), ("ALEX RIVERNOFRILLS", "NOFRILLS"), ("@NOFRILLS", "NOFRILLS"), ("T&TSupermarkel", "T&T SUPERMARKET"), ("ALEX’S NOFRILLS", "NOFRILLS"),
            ("ＣＯＳＴＣＯ WHOLESALE", "COSTCO"), ("T & T SUPERMARKET", "T&T SUPERMARKET"),
            ("COSTCO CAD", "COSTCO")] {
            XCTAssertEqual(ReceiptParser.parse(source(name + "\nTEA 3.00")).merchant, expected)
        }
    }
    func testProductsPromotionsAndWebsitesAreNotAliases() {
        for text in ["COSTCO BAG", "SHOP AT COSTCO", "COMPARE WITH NOFRILLS", "T&T TEA", "COSTCO.COM", "NOTCOSTCO", "NOFRILLS SAVINGS", "NOFRILLS COSTCO"] {
            XCTAssertNil(ReceiptParser.parse(source(text + "\nTEA 3.00")).merchant)
        }
    }
    func testFooterAndLateMentionsCannotChooseRetailer() {
        for text in ["UNKNOWN MART\nTEA 3.00\nCOSTCO", "UNKNOWN MART\nTOTAL\nCOSTCO", "UNKNOWN MART\nTHANK YOU\nCOSTCO", Array(repeating: "HEADER", count: 12).joined(separator: "\n") + "\nCOSTCO"] {
            XCTAssertNil(ReceiptParser.parse(source(text)).merchant)
        }
    }
    func testConflictingHeadersRetainEvidenceAndDisableDatePolicy() {
        let lines = source("NOFRILLS\nCOSTCO\n26/09/19 14:25:00\nTEA 3.00")
        let parsed = ReceiptParser.parse(lines)
        XCTAssertNil(parsed.merchant)
        XCTAssertEqual(parsed.date, try? ReceiptDate(year: 2019, month: 9, day: 26))
        XCTAssertNotEqual(parsed.date, try? ReceiptDate(year: 2026, month: 9, day: 19))
        XCTAssertEqual(Set(parsed.issues.first { $0.code == "merchant_conflicting" }?.sourceLineIDs ?? []), Set(lines.prefix(2).map(\.id)))
    }
    func testRepeatedSameIdentityIsNotConflict() {
        XCTAssertEqual(ReceiptParser.parse(source("COSTCO\nCOSTCO WHOLESALE\nTEA 3.00")).merchant, "COSTCO")
    }
    func testMisleadingMentionDoesNotEnableDetachedPurchasePairing() throws {
        for header in ["COMPARE WITH COSTCO", "UNKNOWN MART", "COSTCO\nNOFRILLS"] {
            var lines = source(header)
            lines += [ReceiptOCRLine(id: UUID(), text: "123456 TEA", engineConfidence: nil,
                boundingBox: try ReceiptOCRBox(x: 0.1, y: 0.7, width: 0.3, height: 0.02)),
                ReceiptOCRLine(id: UUID(), text: "3.00", engineConfidence: nil,
                boundingBox: try ReceiptOCRBox(x: 0.7, y: 0.685, width: 0.1, height: 0.02))]
            XCTAssertTrue(ReceiptParser.parse(lines).lines.isEmpty)
        }
    }
}
