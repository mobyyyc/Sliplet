import Foundation

/// Memory-only presentation rows, prepared when the search inputs or saved receipts change.
struct ReceiptBrowsingSnapshot {
    struct Row: Identifiable {
        let record: ReceiptRecord
        let match: ReceiptSearchIndex.Match?
        var id: String { (match?.basis == .merchant ? nil : match).map { "match-" + $0.id } ?? "receipt-" + record.id.uuidString }
        var identifier: String { (match?.basis == .merchant ? nil : match).map { "searchMatch-" + $0.id } ?? "searchReceipt-" + record.id.uuidString }
    }
    struct Section: Identifiable {
        let id: String
        let title: String
        let rows: [Row]
    }
    let receiptCount: Int
    let rows: [Row]
    let sections: [Section]
    let indexByID: [String: Int]
    let firstRowByReceipt: [UUID: String]
    init(results: [ReceiptSearchIndex.Result] = [], monthTitles: [String: String] = [:], today: ReceiptDate = ReceiptBrowsingPeriod.today()) {
        receiptCount = results.count
        rows = results.flatMap { result in
            if result.matches.isEmpty || result.matches.first?.basis == .merchant {
                return [Row(record: result.record, match: result.matches.first)]
            }
            return result.matches.map { Row(record: result.record, match: $0) }
        }
        indexByID = Dictionary(uniqueKeysWithValues: rows.enumerated().map { ($0.element.id, $0.offset) })
        var first: [UUID: String] = [:]
        for row in rows where first[row.record.id] == nil { first[row.record.id] = row.id }
        firstRowByReceipt = first
        let recent = ReceiptBrowsingPeriod.Recent(newestFirst: results.map(\.record), today: today)
        let groups = Dictionary(grouping: rows) { recent.sectionKey(for: $0.record) ?? "" }
        sections = groups.keys.sorted(by: >).map {
            Section(id: $0, title: $0.isEmpty ? "Date unavailable" : monthTitles[$0] ?? ReceiptBrowsingPeriod.title($0), rows: groups[$0]!)
        }
    }
    /// Keep the same purchase after edits; after removal prefer its next surviving neighbor.
    func restored(_ anchor: ReceiptBrowsingAnchor?, from previous: Self) -> ReceiptBrowsingAnchor? {
        guard let anchor else { return nil }
        if indexByID[anchor.rowID] != nil { return anchor }
        if let rowID = firstRowByReceipt[anchor.receiptID] {
            return ReceiptBrowsingAnchor(rowID: rowID, receiptID: anchor.receiptID, y: anchor.y)
        }
        if let index = previous.indexByID[anchor.rowID] {
            let nearby = previous.rows.dropFirst(index + 1) + previous.rows.prefix(index).reversed()
            for candidate in nearby {
                if let rowID = firstRowByReceipt[candidate.record.id] {
                    return ReceiptBrowsingAnchor(rowID: rowID, receiptID: candidate.record.id, y: anchor.y)
                }
            }
        }
        return rows.first.map { ReceiptBrowsingAnchor(rowID: $0.id, receiptID: $0.record.id, y: anchor.y) }
    }
}

struct ReceiptBrowsingAnchor: Equatable {
    let rowID: String
    let receiptID: UUID
    /// Global row-top position, clamped to the current safe viewport when restored.
    var y: CGFloat
}

struct ReceiptWalletFocus: Equatable {
    let token = UUID()
    let receiptID: UUID
    let y: CGFloat?
}
