import Foundation

/// Local guidance from original bytes or complete, independently recorded receipt fields.
struct ReceiptImportMatch {
    enum Kind: Equatable { case samePhoto, similarReceipt }

    let kind: Kind
    let record: ReceiptRecord

    static func samePhoto(_ digest: Data, in records: [ReceiptRecord]) -> ReceiptRecord? {
        let matches = records.filter { $0.asset.sha256 == digest }
        return matches.first { !$0.isArchived && $0.current.review.isFinished }
            ?? matches.first { !$0.isArchived }
            ?? matches.first
    }

    static func similarReceipt(_ incoming: ReceiptFields, in records: [ReceiptRecord]) -> ReceiptRecord? {
        guard let merchant = normalized(incoming.merchant), let date = incoming.purchaseDate,
              let total = incoming.total, incoming.currency == total.currency, let basket = Basket(incoming) else { return nil }
        return records.first { record in
            let saved = record.current.fields
            return saved.purchaseDate == date && saved.total == total && saved.currency == incoming.currency
                && saved.subtotal == incoming.subtotal && normalized(saved.merchant) == merchant && Basket(saved) == basket
        }
    }

    private static func normalized(_ value: String?) -> String? {
        value?.precomposedStringWithCompatibilityMapping.lowercased()
            .split(whereSeparator: \.isWhitespace).joined(separator: " ").nilIfEmpty
    }

    private struct Purchase: Hashable {
        let name: String
        let code: String?
        let quantity: String?
        let unit: String?
        let unitPrice: Int64?
        let amount: Int64
    }

    private struct Adjustment: Hashable {
        let kind: ReceiptAdjustment.Kind
        let amount: Int64
    }

    private struct Basket: Equatable {
        let purchases: [Purchase: Int]
        let adjustments: [Adjustment: Int]

        init?(_ fields: ReceiptFields) {
            var purchases: [Purchase: Int] = [:]
            for line in fields.items {
                guard let name = normalized(line.description), let amount = line.amount else { return nil }
                let purchase = Purchase(name: name, code: normalized(line.sku), quantity: line.quantity.map(ExactInput.quantity),
                                        unit: normalized(line.unit), unitPrice: line.unitPrice?.minorUnits, amount: amount.minorUnits)
                purchases[purchase, default: 0] += 1
            }
            // Single-product baskets recur often and are weak evidence, even with the same total and date.
            guard purchases.count >= 2 else { return nil }
            var adjustments: [Adjustment: Int] = [:]
            for line in fields.adjustments {
                guard let amount = line.amount else { return nil }
                adjustments[Adjustment(kind: line.kind, amount: amount.minorUnits), default: 0] += 1
            }
            self.purchases = purchases
            self.adjustments = adjustments
        }
    }
}
