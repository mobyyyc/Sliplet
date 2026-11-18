import Foundation

/// Built once per receipt update. Scroll frames use binary searches over cached offsets.
struct ReceiptWalletLayout {
    let revision = UUID()
    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        let indices: Range<Int>
        var count: Int { indices.count }
    }
    static let pitch: CGFloat = 136
    static let monthGap: CGFloat = 420
    static let headingHeight: CGFloat = 40
    let receiptIDs: [UUID]
    let offsets: [CGFloat]
    let sections: [Section]
    let sectionIndices: [Int]
    let indexByID: [UUID: Int]
    let latestDatedIndex: Int?
    var lastOffset: CGFloat { offsets.last ?? 0 }
    var height: CGFloat { offsets.isEmpty ? 0 : lastOffset + 244 }

    init(records: [ReceiptRecord] = [], today: ReceiptDate = ReceiptBrowsingPeriod.today()) {
        self.init(entries: records.map { ($0.id, ReceiptBrowsingPeriod.key($0, today: today)) })
    }
    init(entries: [(id: UUID, month: String?)]) {
        receiptIDs = entries.map(\.id)
        indexByID = Dictionary(uniqueKeysWithValues: receiptIDs.enumerated().map { ($0.element, $0.offset) })
        latestDatedIndex = entries.lastIndex { $0.month != nil }
        var offsets: [CGFloat] = [], sections: [Section] = [], sectionIndices: [Int] = []
        var offset = Self.headingHeight, start = 0
        for index in entries.indices {
            if index > 0 {
                offset += Self.pitch
                if entries[index].month != entries[index - 1].month {
                    let key = entries[start].month
                    sections.append(Section(id: key ?? "undated", title: key.map(ReceiptBrowsingPeriod.title) ?? "Date unavailable", indices: start..<index))
                    start = index; offset += Self.monthGap
                }
            }
            offsets.append(offset); sectionIndices.append(sections.count)
        }
        if let last = entries.last {
            sections.append(Section(id: last.month ?? "undated", title: last.month.map(ReceiptBrowsingPeriod.title) ?? "Date unavailable", indices: start..<entries.count))
        }
        self.offsets = offsets; self.sections = sections; self.sectionIndices = sectionIndices
    }
    /// The preceding paper can still cover the viewport through its full preview height.
    func visibleIndices(lower: CGFloat, upper: CGFloat) -> Range<Int> {
        let first = lowerBound(lower), last = lowerBound(upper)
        return first..<max(first, last)
    }
    func lowerBound(_ offset: CGFloat) -> Int {
        var low = 0, high = offsets.count
        while low < high {
            let middle = (low + high) / 2
            if offsets[middle] < offset { low = middle + 1 } else { high = middle }
        }
        return low
    }
    func section(at offset: CGFloat) -> Section? {
        guard !offsets.isEmpty else { return nil }
        let index = min(offsets.count - 1, max(0, lowerBound(offset.nextUp) - 1))
        return sections[sectionIndices[index]]
    }
}

/// Deterministic separated-card geometry for Reduce Motion and larger text.
/// Font changes alter the shared dimensions, rather than lazy estimated row heights.
struct ReceiptWalletPlainLayout {
    let grouped: ReceiptWalletLayout
    let paperHeight: CGFloat
    let headingHeight: CGFloat
    func offset(_ index: Int) -> CGFloat {
        headingHeight + CGFloat(index) * (paperHeight + 16)
            + CGFloat(grouped.sectionIndices[index]) * (headingHeight + 24)
    }
    var lastOffset: CGFloat { grouped.receiptIDs.isEmpty ? 0 : offset(grouped.receiptIDs.count - 1) }
    var height: CGFloat { grouped.receiptIDs.isEmpty ? 0 : lastOffset + paperHeight }
    func lowerBound(_ value: CGFloat) -> Int {
        var low = 0, high = grouped.receiptIDs.count
        while low < high {
            let mid = (low + high) / 2
            if offset(mid) < value { low = mid + 1 } else { high = mid }
        }
        return low
    }
    func visibleIndices(lower: CGFloat, upper: CGFloat) -> Range<Int> {
        let first = lowerBound(lower - paperHeight)
        return first..<max(first, lowerBound(upper))
    }
}
