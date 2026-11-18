import Foundation

/// Civil receipt dates use the user's local Gregorian day, without assigning a time to a purchase.
enum ReceiptBrowsingPeriod {
    static func today(now: Date = Date()) -> ReceiptDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return try! ReceiptDate(year: c.year!, month: c.month!, day: c.day!)
    }
    static func key(_ record: ReceiptRecord, today: ReceiptDate) -> String? {
        record.current.fields.purchaseDate == today ? "today" : ReceiptHistory.monthKey(record)
    }
    static func title(_ key: String) -> String {
        key == "today" ? "Today" : ReceiptHistory.monthTitle(key)
    }
}
