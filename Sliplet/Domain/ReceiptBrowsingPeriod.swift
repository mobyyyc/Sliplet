import Foundation

/// Civil receipt dates use the user's local Gregorian day, without assigning a time to a purchase.
enum ReceiptBrowsingPeriod {
    static func today(now: Date = Date()) -> ReceiptDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return try! ReceiptDate(year: c.year!, month: c.month!, day: c.day!)
    }
    /// One leading group for a set of receipts, ordered by purchase date before calling this initializer.
    struct Recent {
        let key: String
        private let date: ReceiptDate?
        private let undatedID: UUID?

        init(newestFirst records: [ReceiptRecord], today: ReceiptDate) {
            let hasToday = records.contains { $0.current.fields.purchaseDate == today }
            key = hasToday ? "today" : "latest"
            date = hasToday ? today : records.first?.current.fields.purchaseDate
            undatedID = date == nil ? records.first?.id : nil
        }

        func contains(_ record: ReceiptRecord) -> Bool {
            if let date { return record.current.fields.purchaseDate == date }
            return record.id == undatedID
        }

        func sectionKey(for record: ReceiptRecord) -> String? {
            contains(record) ? key : ReceiptHistory.monthKey(record)
        }
    }

    static func title(_ key: String) -> String {
        switch key {
        case "today": "Today"
        case "latest": "Latest"
        default: ReceiptHistory.monthTitle(key)
        }
    }
}
