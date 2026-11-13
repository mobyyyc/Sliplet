import Foundation

/// Explicit comparison choices, bound to the two revisions in PurchaseLinkDecision.
struct PurchasePriceEvidence: Codable, Equatable, Sendable {
    enum Basis: String, Codable, CaseIterable, Sendable {
        case printed, calculated
        var title: String { self == .printed ? "Printed unit price" : "Line amount ÷ quantity" }
    }
    enum Unit: String, Codable, CaseIterable, Sendable {
        case unknown, each, kg, g, lb, oz, litre, ml
        var title: String {
            switch self {
            case .unknown: "Choose unit"
            case .litre: "L"
            case .ml: "mL"
            default: rawValue
            }
        }
        var standard: Unit {
            switch self { case .g: .kg; case .oz: .lb; case .ml: .litre; default: self }
        }
        var multiplier: Int64 {
            switch self { case .g, .ml: 1000; case .oz: 16; default: 1 }
        }
        static func printed(_ text: String?) -> Unit {
            switch text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "each", "ea", "pc", "pcs": .each
            case "kg", "kilogram", "kilograms": .kg
            case "g", "gram", "grams": .g
            case "lb", "lbs", "pound", "pounds": .lb
            case "oz", "ounce", "ounces": .oz
            case "l", "litre", "liter", "litres", "liters": .litre
            case "ml", "millilitre", "milliliter": .ml
            default: .unknown
            }
        }
    }
    enum Tax: String, Codable, CaseIterable, Sendable {
        case unknown, beforeTax, included
        var title: String {
            switch self { case .unknown: "Choose tax basis"; case .beforeTax: "Before tax"; case .included: "Tax included" }
        }
    }
    var firstBasis: Basis = .printed
    var secondBasis: Basis = .printed
    var firstUnit: Unit = .unknown
    var secondUnit: Unit = .unknown
    var tax: Tax = .unknown

    var reversed: Self {
        Self(firstBasis: secondBasis, secondBasis: firstBasis, firstUnit: secondUnit, secondUnit: firstUnit, tax: tax)
    }
}

enum PurchasePriceError: Error, Equatable, LocalizedError {
    case confirmProduct, reviewReceipts, currency, unit, tax, price, quantity, range
    var errorDescription: String? {
        switch self {
        case .confirmProduct: "Confirm the same product and pack size before comparing prices."
        case .reviewReceipts: "Finish reviewing both receipts before comparing prices."
        case .currency: "Prices must use the same currency."
        case .unit: "Choose compatible units for both purchases. Metric and imperial units are compared separately."
        case .tax: "Confirm whether both row prices are before tax or include tax."
        case .price: "A positive price is missing. Check the row fields against the original."
        case .quantity: "A positive quantity is needed to calculate a unit price. Check the row fields."
        case .range: "These values are too large for an exact comparison."
        }
    }
}

enum PurchasePriceComparison {
    /// Reduced rational minor currency units per standard unit.
    struct Rate: Equatable {
        let numerator: Int64
        let denominator: Int64
        let currency: ReceiptCurrency
        let unit: PurchasePriceEvidence.Unit
        let basis: PurchasePriceEvidence.Basis

        var formatted: String {
            var value = Decimal(numerator)
            var divisor = Decimal(denominator) * pow10(currency.minorUnitScale)
            var quotient = Decimal()
            let division = NSDecimalDivide(&quotient, &value, &divisor, .plain)
            var rounded = Decimal()
            NSDecimalRound(&rounded, &quotient, max(4, Int(currency.minorUnitScale)), .plain)
            let approximate = division == .lossOfPrecision || rounded != quotient
            return "\(approximate ? "≈ " : "")\(currency.code) \(NSDecimalNumber(decimal: rounded).stringValue) / \(unit.title)"
        }
    }
    struct Result {
        let first: Rate
        let second: Rate
        let order: ComparisonResult
        let tax: PurchasePriceEvidence.Tax
        var summary: String {
            switch order {
            case .orderedSame: "Same unit price"
            case .orderedAscending: "This purchase has a lower unit price"
            case .orderedDescending: "This purchase has a higher unit price"
            }
        }
    }

    /// Explains blockers that cannot be resolved by the comparison controls.
    static func setupBlocker(_ a: ReceiptRecord, line first: ReceiptLine,
                             _ b: ReceiptRecord, line second: ReceiptLine) -> String? {
        guard let decision = PurchaseLinkEngine.decision(a, line: first.id, b, line: second.id),
              decision.verdict == .sameProduct, decision.pack == .same else {
            return PurchasePriceError.confirmProduct.localizedDescription
        }
        return priceBlocker(a, line: first, b, line: second)
    }

    /// A candidate may open the comparison without granting product or pack approval.
    static func priceBlocker(_ a: ReceiptRecord, line first: ReceiptLine,
                             _ b: ReceiptRecord, line second: ReceiptLine) -> String? {
        guard ReceiptCompletion.isComplete(a), ReceiptCompletion.isComplete(b) else {
            return PurchasePriceError.reviewReceipts.localizedDescription
        }
        guard a.current.fields.currency == b.current.fields.currency else {
            return PurchasePriceError.currency.localizedDescription
        }
        for (line, title) in [(first, "This purchase"), (second, "Other purchase")] {
            if (line.unitPrice?.minorUnits ?? 0) > 0 { continue }
            guard (line.amount?.minorUnits ?? 0) > 0 else {
                return "\(title) needs a positive line total or printed unit price."
            }
            guard (line.quantity?.coefficient ?? 0) > 0 else {
                return "\(title) needs a quantity or a printed unit price."
            }
        }
        return nil
    }

    static func savedEvidence(_ a: ReceiptRecord, line first: UUID,
                              _ b: ReceiptRecord, line second: UUID) -> PurchasePriceEvidence? {
        guard let decision = PurchaseLinkEngine.decision(a, line: first, b, line: second),
              let evidence = decision.priceEvidence else { return nil }
        return decision.first.endpoint == PurchaseEndpoint(receiptID: a.id, lineID: first) ? evidence : evidence.reversed
    }

    static func compare(_ a: ReceiptRecord, line firstID: UUID,
                        _ b: ReceiptRecord, line secondID: UUID,
                        evidence: PurchasePriceEvidence) throws -> Result {
        guard let decision = PurchaseLinkEngine.decision(a, line: firstID, b, line: secondID),
              decision.verdict == .sameProduct, decision.pack == .same else { throw PurchasePriceError.confirmProduct }
        guard ReceiptCompletion.isComplete(a), ReceiptCompletion.isComplete(b) else { throw PurchasePriceError.reviewReceipts }
        guard let first = a.current.fields.items.first(where: { $0.id == firstID }),
              let second = b.current.fields.items.first(where: { $0.id == secondID }) else { throw PurchasePriceError.price }
        guard evidence.tax != .unknown else { throw PurchasePriceError.tax }
        let left = try rate(first, basis: evidence.firstBasis, unit: evidence.firstUnit)
        let right = try rate(second, basis: evidence.secondBasis, unit: evidence.secondUnit)
        guard left.currency == right.currency else { throw PurchasePriceError.currency }
        guard left.unit == right.unit else { throw PurchasePriceError.unit }
        // Each operand is Int64. Products have at most 38 digits; require exact arithmetic.
        var ln = Decimal(left.numerator), rd = Decimal(right.denominator)
        var rn = Decimal(right.numerator), ld = Decimal(left.denominator)
        var l = Decimal(), r = Decimal()
        guard NSDecimalMultiply(&l, &ln, &rd, .plain) == .noError,
              NSDecimalMultiply(&r, &rn, &ld, .plain) == .noError else { throw PurchasePriceError.range }
        return Result(first: left, second: right, order: NSDecimalCompare(&l, &r), tax: evidence.tax)
    }

    static func rate(_ line: ReceiptLine, basis: PurchasePriceEvidence.Basis,
                     unit: PurchasePriceEvidence.Unit) throws -> Rate {
        guard unit != .unknown else { throw PurchasePriceError.unit }
        let price = basis == .printed ? line.unitPrice : line.amount
        guard let price, price.minorUnits > 0 else { throw PurchasePriceError.price }
        var numerators = [price.minorUnits, unit.multiplier]
        var denominators: [Int64] = [1]
        if basis == .calculated {
            guard let quantity = line.quantity, quantity.coefficient > 0 else { throw PurchasePriceError.quantity }
            numerators.append((0..<quantity.scale).reduce(Int64(1)) { value, _ in value * 10 })
            denominators.append(quantity.coefficient)
        }
        // Cancel before multiplication to retain exact fractional quantities without overflow.
        for n in numerators.indices {
            for d in denominators.indices {
                let divisor = gcd(numerators[n], denominators[d])
                numerators[n] /= divisor; denominators[d] /= divisor
            }
        }
        return Rate(numerator: try product(numerators), denominator: try product(denominators),
                    currency: price.currency, unit: unit.standard, basis: basis)
    }

    private static func gcd(_ first: Int64, _ second: Int64) -> Int64 {
        var a = first, b = second
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }
    private static func product(_ values: [Int64]) throws -> Int64 {
        try values.reduce(1) { accumulated, value in
            let (result, overflow) = accumulated.multipliedReportingOverflow(by: value)
            guard !overflow else { throw PurchasePriceError.range }
            return result
        }
    }
    private static func pow10(_ scale: UInt8) -> Decimal {
        (0..<scale).reduce(Decimal(1)) { value, _ in value * 10 }
    }
}
