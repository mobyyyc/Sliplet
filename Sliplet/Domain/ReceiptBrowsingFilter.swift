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
    func accepts(_ record: ReceiptRecord) -> Bool {
        if dateMode == .day || dateMode == .range {
            guard let date = record.current.fields.purchaseDate else { return false }
            let key = String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
            guard key >= Self.key(start), key <= Self.key(dateMode == .day ? start : end) else { return false }
        }
        if hasAmount {
            guard validation == nil, let total = record.current.fields.total, total.currency == currency else { return false }
            if let low = ExactInput.money(minimum, scale: currency.minorUnitScale), total.minorUnits < low { return false }
            if let high = ExactInput.money(maximum, scale: currency.minorUnitScale), total.minorUnits > high { return false }
        }
        return true
    }
}
