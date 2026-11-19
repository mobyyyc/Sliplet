import Foundation

/// An exact, memory-only index of the receipts that contribute to purchase totals.
struct ReceiptPurchaseOverview: Sendable {
    struct Entry: Sendable, Identifiable {
        let record: ReceiptRecord
        let isDuplicate: Bool
        var id: UUID { record.id }
    }

    struct Summary: Sendable {
        var entries: [Entry] = []
        private(set) var count = 0
        private(set) var net = Decimal.zero
        private var scale: UInt8 = 0

        mutating func add(_ entry: Entry, amount: Decimal, minorUnitScale: UInt8) {
            entries.append(entry)
            guard !entry.isDuplicate else { return }
            count += 1
            scale = max(scale, minorUnitScale)
            net += amount
        }

        func amount(currency: String) -> String {
            net.formatted(.currency(code: currency).presentation(.isoCode)
                .precision(.fractionLength(Int(scale))))
        }
    }

    struct Currency: Sendable {
        var all = Summary()
        var merchants: [String: Summary] = [:]
        var merchantsBySpending: [String] {
            merchants.keys.sorted { lhs, rhs in
                let a = merchants[lhs]?.net ?? 0
                let b = merchants[rhs]?.net ?? 0
                return a == b ? lhs < rhs : a > b
            }
        }
    }

    struct Month: Sendable {
        var currencies: [String: Currency] = [:]
        var needsReview: [Entry] = []
    }

    private struct CopyKey: Hashable {
        let image: Data
        let merchant: String
        let date: ReceiptDateKey
        let currency: String
        let amount: Decimal
    }

    private struct ReceiptDateKey: Hashable {
        let year: Int
        let month: Int
        let day: Int

        init(_ date: ReceiptDate) {
            year = date.year
            month = date.month
            day = date.day
        }
    }

    let months: [String: Month]
    let monthKeys: [String]
    let undated: [Entry]

    init(records: [ReceiptRecord]) {
        var months: [String: Month] = [:]
        var undated: [Entry] = []
        var seen: Set<CopyKey> = []
        for record in records.sorted(by: ReceiptHistory.newestFirst) {
            guard !Task.isCancelled else { break }
            guard let key = ReceiptHistory.monthKey(record), let date = record.current.fields.purchaseDate else {
                undated.append(Entry(record: record, isDuplicate: false))
                continue
            }
            let fields = record.current.fields
            guard record.current.review.isFinished, let merchant = fields.merchant, let total = fields.total,
                  fields.currency == total.currency, ReceiptCompletion.isComplete(record) else {
                months[key, default: Month()].needsReview.append(Entry(record: record, isDuplicate: false))
                continue
            }
            let signedAmount = Decimal(total.minorUnits) / pow(Decimal(10), Int(total.currency.minorUnitScale))
            let copy = CopyKey(image: record.asset.sha256, merchant: merchant, date: ReceiptDateKey(date),
                               currency: total.currency.code, amount: signedAmount)
            let entry = Entry(record: record, isDuplicate: !seen.insert(copy).inserted)
            let currency = total.currency.code
            months[key, default: Month()].currencies[currency, default: Currency()].all.add(
                entry, amount: signedAmount, minorUnitScale: total.currency.minorUnitScale)
            months[key, default: Month()].currencies[currency, default: Currency()].merchants[merchant, default: Summary()].add(
                entry, amount: signedAmount, minorUnitScale: total.currency.minorUnitScale)
        }
        self.months = months
        self.monthKeys = months.keys.sorted(by: >)
        self.undated = undated
    }
}
