import XCTest
@testable import Sliplet

@MainActor final class PurchasePriceTests: XCTestCase {
    private func record(amount: Int64, quantity: ReceiptDecimal?, price: Int64?, marker: UInt8,
                        currency: ReceiptCurrency = .cad) -> ReceiptRecord {
        let base = SplitFixture.record(amounts: [amount])
        var fields = base.current.fields
        fields.currency = currency
        fields.items[0].amount = ReceiptMoney(minorUnits: amount, currency: currency)
        fields.items[0].quantity = quantity
        fields.items[0].unitPrice = price.map { ReceiptMoney(minorUnits: $0, currency: currency) }
        fields.total = ReceiptMoney(minorUnits: amount, currency: currency)
        return ReceiptRecord(id: base.id, createdAt: base.createdAt, updatedAt: base.updatedAt,
            original: base.original, asset: ReceiptAsset(id: base.asset.id, mediaType: "image/png", byteCount: 1,
                                                        sha256: Data(repeating: marker, count: 32)),
            revisions: [base.revisions[0], ReceiptRevision(id: UUID(), createdAt: base.current.createdAt,
                                                         fields: fields, review: .sourceReviewed)])
    }
    private func link(_ first: ReceiptRecord, _ second: ReceiptRecord,
                      pack: PurchaseLinkDecision.Pack = .same) -> [ReceiptRecord] {
        var a = first, b = second
        let decision = PurchaseLinkDecision(id: UUID(), first: PurchaseEvidence(record: a, lineID: a.current.fields.items[0].id),
            second: PurchaseEvidence(record: b, lineID: b.current.fields.items[0].id), verdict: .sameProduct, pack: pack)
        a.purchaseLinks = PurchaseLinks(decisions: [decision]); b.purchaseLinks = PurchaseLinks(decisions: [decision])
        return [a, b]
    }
    private func compare(_ pair: [ReceiptRecord], _ evidence: PurchasePriceEvidence) throws -> PurchasePriceComparison.Result {
        try PurchasePriceComparison.compare(pair[0], line: pair[0].current.fields.items[0].id,
                                             pair[1], line: pair[1].current.fields.items[0].id, evidence: evidence)
    }
    private var each: PurchasePriceEvidence {
        PurchasePriceEvidence(firstBasis: .calculated, secondBasis: .printed,
                              firstUnit: .each, secondUnit: .each, tax: .beforeTax)
    }

    func testDifferentQuantitiesSameUnitPriceAndFractionalEquality() throws {
        let a = record(amount: 500, quantity: try .init(coefficient: 1, scale: 0), price: nil, marker: 1)
        let b = record(amount: 1000, quantity: try .init(coefficient: 2, scale: 0), price: 500, marker: 2)
        let result = try compare(link(a, b), each)
        XCTAssertEqual(result.order, .orderedSame)
        XCTAssertEqual(result.first.basis, .calculated); XCTAssertEqual(result.second.basis, .printed)
        let c = record(amount: 1, quantity: try .init(coefficient: 3, scale: 0), price: nil, marker: 3)
        let d = record(amount: 2, quantity: try .init(coefficient: 6, scale: 0), price: nil, marker: 4)
        var evidence = each; evidence.secondBasis = .calculated
        let fractions = try compare(link(c, d), evidence)
        XCTAssertEqual(fractions.order, .orderedSame)
        XCTAssertTrue(fractions.first.formatted.hasPrefix("≈"))
        XCTAssertEqual(fractions.first.numerator, 1); XCTAssertEqual(fractions.first.denominator, 3)
    }

    func testMetricImperialVolumeConversionsAndIncompatibleUnits() throws {
        let conversions: [(PurchasePriceEvidence.Unit, PurchasePriceEvidence.Unit, Int64)] =
            [(.g, .kg, 1000), (.oz, .lb, 16), (.ml, .litre, 1000)]
        for (small, large, multiplier) in conversions {
            let a = record(amount: 100, quantity: try .init(coefficient: multiplier / 4, scale: 0), price: nil, marker: 1)
            let b = record(amount: 400, quantity: try .init(coefficient: 1, scale: 0), price: nil, marker: 2)
            let evidence = PurchasePriceEvidence(firstBasis: .calculated, secondBasis: .calculated,
                                                 firstUnit: small, secondUnit: large, tax: .included)
            XCTAssertEqual(try compare(link(a, b), evidence).order, .orderedSame)
        }
        let weighted = record(amount: 100, quantity: try .init(coefficient: 250, scale: 3), price: nil, marker: 1)
        let whole = record(amount: 400, quantity: try .init(coefficient: 1, scale: 0), price: 400, marker: 2)
        var evidence = each; evidence.firstUnit = .kg; evidence.secondUnit = .kg
        XCTAssertEqual(try compare(link(weighted, whole), evidence).order, .orderedSame)
        evidence.secondUnit = .lb
        XCTAssertThrowsError(try compare(link(weighted, whole), evidence)) { XCTAssertEqual($0 as? PurchasePriceError, .unit) }
    }

    func testMissingEvidenceCurrencyPackAndTaxBlockComparison() throws {
        let a = record(amount: 500, quantity: nil, price: nil, marker: 1)
        let b = record(amount: 500, quantity: nil, price: 500, marker: 2)
        XCTAssertThrowsError(try compare(link(a, b), each)) { XCTAssertEqual($0 as? PurchasePriceError, .quantity) }
        var evidence = each; evidence.firstBasis = .printed
        XCTAssertThrowsError(try compare(link(a, b), evidence)) { XCTAssertEqual($0 as? PurchasePriceError, .price) }
        evidence.tax = .unknown
        XCTAssertThrowsError(try compare(link(a, b), evidence)) { XCTAssertEqual($0 as? PurchasePriceError, .tax) }
        XCTAssertThrowsError(try compare(link(a, b, pack: .unknown), each)) { XCTAssertEqual($0 as? PurchasePriceError, .confirmProduct) }
        let usd = record(amount: 500, quantity: nil, price: 500, marker: 3,
                         currency: try ReceiptCurrency(code: "USD", minorUnitScale: 2))
        evidence.tax = .beforeTax
        XCTAssertThrowsError(try compare(link(b, usd), evidence)) { XCTAssertEqual($0 as? PurchasePriceError, .currency) }
    }

    func testSetupGuidanceNamesTheBlockedPurchaseAndAcceptsPrintedRatesWithoutQuantity() throws {
        let a = record(amount: 500, quantity: nil, price: 500, marker: 1)
        let b = record(amount: 500, quantity: nil, price: nil, marker: 2)
        let c = record(amount: 500, quantity: nil, price: 500, marker: 3)
        func blocker(_ pair: [ReceiptRecord]) -> String? {
            PurchasePriceComparison.setupBlocker(pair[0], line: pair[0].current.fields.items[0],
                                                 pair[1], line: pair[1].current.fields.items[0])
        }
        XCTAssertEqual(blocker([a, b]), PurchasePriceError.confirmProduct.localizedDescription)
        XCTAssertEqual(blocker(link(a, b)), "Other purchase needs a quantity or a printed unit price.")
        XCTAssertEqual(blocker(link(b, a)), "This purchase needs a quantity or a printed unit price.")
        XCTAssertNil(blocker(link(a, c)))
    }

    func testHugeValuesFailAndSeparateDiscountDoesNotChangeRowRate() throws {
        var line = record(amount: 1, quantity: nil, price: nil, marker: 1).current.fields.items[0]
        line.amount = ReceiptMoney(minorUnits: Int64.max, currency: .cad)
        line.quantity = try ReceiptDecimal(coefficient: 1, scale: 9)
        XCTAssertThrowsError(try PurchasePriceComparison.rate(line, basis: .calculated, unit: .g)) {
            XCTAssertEqual($0 as? PurchasePriceError, .range)
        }
        let base = SplitFixture.record(amounts: [500], adjustments: [(.discount, -100), (.tax, 20)])
        var purchase = base.current.fields.items[0]
        purchase.quantity = try ReceiptDecimal(coefficient: 1, scale: 0)
        let rate = try PurchasePriceComparison.rate(purchase, basis: .calculated, unit: .each)
        XCTAssertEqual(rate.numerator, 500)
    }

    /// Runs only after the owner export is validated by the local audit command.
    func testCheckedPrivatePair() throws {
        let path = URL(fileURLWithPath: "/tmp/sliplet-p1004-native.json")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("Validated private price input absent") }
        let data = try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as! [String: Any]
        let rows = data["rows"] as! [[String: Any]]
        var records: [ReceiptRecord] = []
        for (index, row) in rows.enumerated() {
            let quantity = try ReceiptDecimal(coefficient: (row["quantityCoefficient"] as! NSNumber).int64Value,
                                               scale: (row["quantityScale"] as! NSNumber).uint8Value)
            records.append(record(amount: (row["amount"] as! NSNumber).int64Value, quantity: quantity,
                                  price: (row["printedPrice"] as? NSNumber)?.int64Value, marker: UInt8(index + 1)))
        }
        let evidence = PurchasePriceEvidence(
            firstBasis: rows[0]["basis"] as! String == "calculated" ? .calculated : .printed,
            secondBasis: rows[1]["basis"] as! String == "calculated" ? .calculated : .printed,
            firstUnit: .each, secondUnit: .each, tax: .beforeTax)
        let result = try compare(link(records[0], records[1]), evidence)
        XCTAssertTrue(result.order == .orderedSame, "Checked pair must have equal unit prices")
        XCTAssertTrue(records[0].current.fields.items[0].amount != records[1].current.fields.items[0].amount,
                      "The checked pair has different line amounts")
    }
}
