import Foundation

struct ReceiptBrowsingFilter: Equatable {
    enum DateMode: String, CaseIterable, Identifiable { case any = "Any date", month = "Month", day = "Specific date", range = "Date range"; var id: String { rawValue } }
    var dateMode: DateMode = .any
    var start = Date()
    var end = Date()
    var minimum = ""
    var maximum = ""
    var currency = ReceiptCurrency.cad
    var hasAmount: Bool { !minimum.isEmpty || !maximum.isEmpty }
    var active: Bool { dateMode == .day || dateMode == .range || hasAmount }
    static func key(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    var validation: String? {
        if dateMode == .range && Self.key(start) > Self.key(end) { return "The end date must follow the start date." }
        let low = minimum.isEmpty ? nil : ExactInput.money(minimum, scale: currency.minorUnitScale)
        let high = maximum.isEmpty ? nil : ExactInput.money(maximum, scale: currency.minorUnitScale)
        if (!minimum.isEmpty && low == nil) || (!maximum.isEmpty && high == nil) { return "Enter a valid amount for this currency." }
        if let low, let high, low > high { return "Maximum must be at least the minimum." }
        return nil
    }
    func predicate() -> (ReceiptRecord) -> Bool {
        guard validation == nil else { return { _ in false } }
        let hasDateBounds = dateMode == .day || dateMode == .range
        let firstDay = hasDateBounds ? Self.key(start) : nil
        let lastDay = hasDateBounds ? Self.key(dateMode == .day ? start : end) : nil
        let low = minimum.isEmpty ? nil : ExactInput.money(minimum, scale: currency.minorUnitScale)
        let high = maximum.isEmpty ? nil : ExactInput.money(maximum, scale: currency.minorUnitScale)
        return { record in
            if let firstDay, let lastDay {
                guard let date = record.current.fields.purchaseDate else { return false }
                let key = String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
                guard key >= firstDay, key <= lastDay else { return false }
            }
            if low != nil || high != nil {
                guard let total = record.current.fields.total, total.currency == currency else { return false }
                if let low, total.minorUnits < low { return false }
                if let high, total.minorUnits > high { return false }
            }
            return true
        }
    }

    func accepts(_ record: ReceiptRecord) -> Bool { predicate()(record) }
}
