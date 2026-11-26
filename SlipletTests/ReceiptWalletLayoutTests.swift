import XCTest
@testable import Sliplet

final class ReceiptWalletLayoutTests: XCTestCase {
    func testMonthBoundariesAndMissingDatesKeepEveryIdentityInOrder() {
        let months: [String?] = [nil, nil, "2025-12", "2026-01", "2026-01", "2026-11"]
        let entries = months.map { (id: UUID(), month: $0) }
        let layout = ReceiptWalletLayout(entries: entries)
        XCTAssertEqual(layout.receiptIDs, entries.map(\.id))
        XCTAssertEqual(layout.sections.map(\.id), ["undated", "2025-12", "2026-01", "2026-11"])
        XCTAssertEqual(layout.sections.map(\.indices), [0..<2, 2..<3, 3..<5, 5..<6])
        XCTAssertEqual(layout.latestDatedIndex, 5)
        for index in entries.indices {
            XCTAssertEqual(layout.indexByID[entries[index].id], index)
            XCTAssertTrue(layout.sections[layout.sectionIndices[index]].indices.contains(index))
            if index > 0 {
                let gap = layout.offsets[index] - layout.offsets[index - 1]
                XCTAssertEqual(gap, months[index] == months[index - 1] ? 136 : 556)
            }
        }
        XCTAssertEqual(layout.sections.first?.title, "Date unavailable")
        XCTAssertEqual(ReceiptWalletLayout().visibleIndices(lower: -100, upper: 100), 0..<0)
        XCTAssertNil(ReceiptWalletLayout(entries: [(UUID(), nil)]).latestDatedIndex)
    }
    func testProjectedVisibilityAndMonthJumpRemainBoundedAtThousandReceipts() {
        let entries = (0..<1000).map { (id: UUID(), month: String(format: "%04d-%02d", 2020 + $0 / 120, ($0 / 10) % 12 + 1)) }
        let layout = ReceiptWalletLayout(entries: entries)
        for height: CGFloat in [440, 656, 820] {
            let curve = ReceiptStackProjection(viewportHeight: height, readingY: height / 3, anchor: height - 332)
            for section in layout.sections {
                let base = curve.logicalPosition(curve.readingY) - layout.offsets[section.indices.lowerBound]
                XCTAssertEqual(curve.position(base + layout.offsets[section.indices.lowerBound]), curve.readingY, accuracy: 0.001)
            }
            for scroll: CGFloat in stride(from: -layout.height, through: 1000, by: 111) {
                let visible = layout.visibleIndices(lower: curve.logicalPosition(-300) - scroll,
                                                    upper: curve.logicalPosition(height + 100) - scroll)
                XCTAssertLessThanOrEqual(visible.count, 36)
                // Compare binary selection to independently sampled screen-space visibility.
                for index in stride(from: 0, to: 1000, by: 7) {
                    let top = curve.position(scroll + layout.offsets[index])
                    if top >= -300 && top < height + 100 { XCTAssertTrue(visible.contains(index)) }
                }
            }
        }
    }
    func testSeparatedGeometryPreservesExactOffsetsWithoutLazyEstimates() {
        let grouped = ReceiptWalletLayout(entries: (0..<1000).map { (UUID(), String(format: "2026-%02d", $0 / 100 + 1)) })
        for height: CGFloat in [244, 400, 620] {
            let plain = ReceiptWalletPlainLayout(grouped: grouped, paperHeight: height, headingHeight: 80)
            for index in [0, 99, 100, 499, 999] {
                let offset = plain.offset(index)
                XCTAssertEqual(plain.lowerBound(offset), index)
                let origin: CGFloat = 180
                let scroll = offset - origin
                XCTAssertEqual(plain.offset(index) - scroll, origin, accuracy: 0.001)
                let visible = plain.visibleIndices(lower: scroll, upper: scroll + 820)
                XCTAssertTrue(visible.contains(index)); XCTAssertLessThanOrEqual(visible.count, 6)
            }
            XCTAssertEqual(plain.offset(100) - plain.offset(99), height + 16 + 104)
        }
    }
    @MainActor func testCommittedReceiptChangesRebuildCachedGroupsAndExcludeArchive() {
        let workspace = ReceiptWorkspace()
        func record(_ base: ReceiptRecord, date: ReceiptDate?) -> ReceiptRecord {
            var fields = base.current.fields; fields.purchaseDate = date
            return ReceiptRecord(id: base.id, createdAt: base.createdAt, updatedAt: base.updatedAt,
                original: base.original, asset: base.asset,
                revisions: [.init(id: UUID(), createdAt: base.createdAt, fields: fields, review: .draft)])
        }
        var first = record(SearchFixture.record(), date: try! ReceiptDate(year: 2025, month: 12, day: 1))
        let second = record(SearchFixture.record(), date: nil)
        workspace.receipts = [first, second]
        XCTAssertEqual(workspace.walletLayout.sections.map(\.id), ["undated", "latest"])
        first = record(first, date: try! ReceiptDate(year: 2026, month: 1, day: 1))
        workspace.receipts = [first, second]
        XCTAssertEqual(workspace.walletLayout.sections.map(\.id), ["undated", "latest"])
        XCTAssertEqual(workspace.walletLayout.indexByID[first.id], 1)
        first.organization = ReceiptOrganization(archived: true, starred: false)
        workspace.receipts = [first, second]
        XCTAssertEqual(workspace.walletLayout.sections.map(\.id), ["latest"])
        XCTAssertEqual(workspace.walletLayout.receiptIDs, [second.id])
    }
    private func dated(_ date: ReceiptDate) -> ReceiptRecord {
        let base = SearchFixture.record(); var fields = base.current.fields; fields.purchaseDate = date
        return ReceiptRecord(id: base.id, createdAt: base.createdAt, updatedAt: base.updatedAt, original: base.original, asset: base.asset,
            revisions: [.init(id: UUID(), createdAt: base.createdAt, fields: fields, review: .draft)])
    }
    func testTodayUsesTheSameSectionGeometryAndLeavesEarlierPurchasesInTheirMonth() throws {
        let today = try ReceiptDate(year: 2026, month: 11, day: 18)
        let records = [dated(try ReceiptDate(year: 2026, month: 10, day: 1)), dated(try ReceiptDate(year: 2026, month: 11, day: 1)), dated(today), dated(today)]
        let layout = ReceiptWalletLayout(records: records, today: today)
        XCTAssertEqual(layout.sections.map(\.id), ["2026-10", "2026-11", "today"])
        XCTAssertEqual(layout.sections.last?.title, "Today"); XCTAssertEqual(layout.sections.last?.count, 2)
        XCTAssertEqual(layout.offsets[2] - layout.offsets[1], ReceiptWalletLayout.pitch + ReceiptWalletLayout.monthGap)
        let snapshot = ReceiptBrowsingSnapshot(results: ReceiptSearchIndex(records).results(query: ""), today: today)
        XCTAssertEqual(snapshot.sections.map(\.id), ["today", "2026-11", "2026-10"])
        XCTAssertEqual(snapshot.sections[1].rows.count, 1)
        let tomorrow = try ReceiptDate(year: 2026, month: 11, day: 19)
        let next = ReceiptWalletLayout(records: records, today: tomorrow)
        XCTAssertFalse(next.sections.contains { $0.id == "today" })
        XCTAssertEqual(next.sections.map(\.id), ["2026-10", "2026-11", "latest"])
        XCTAssertEqual(next.sections.last?.title, "Latest")
        XCTAssertEqual(next.sections.last?.count, 2)
        XCTAssertEqual(next.sections[1].count, 1)
        let nextList = ReceiptBrowsingSnapshot(results: ReceiptSearchIndex(records).results(query: ""), today: tomorrow)
        XCTAssertEqual(nextList.sections.first?.title, "Latest")
        XCTAssertEqual(Set(nextList.sections[0].rows.map(\.record.id)), Set(records.suffix(2).map(\.id)))
        XCTAssertEqual(Set(nextList.sections.flatMap(\.rows).map(\.record.id)).count, records.count)
    }
    @MainActor func testSearchCancelResetsHomeAndFutureDatesCannotDuplicateTodayMonthSections() throws {
        let today = ReceiptBrowsingPeriod.today()
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .autoupdatingCurrent
        let future = ReceiptBrowsingPeriod.today(now: calendar.date(byAdding: .day, value: 1, to: Date())!)
        let model = ReceiptWorkspace(); let current = dated(today)
        model.receipts = [dated(future), current, dated(try ReceiptDate(year: 2025, month: 1, day: 1))]
        XCTAssertEqual(model.walletReceipts.last?.id, current.id)
        XCTAssertEqual(Set(model.walletLayout.sections.map(\.id)).count, model.walletLayout.sections.count)
        model.searching = true; model.searchQuery = "unrecognized zebra"
        XCTAssertEqual(model.browsing.receiptCount, 0)
        XCTAssertEqual(model.homeBrowsing.receiptCount, 3)
        XCTAssertEqual(model.walletReceipts.last?.id, current.id)
        model.walletScrollOffset = 450; model.walletAnchorID = current.id
        model.walletFocus = ReceiptWalletFocus(receiptID: current.id, y: 140)
        model.endSearch()
        XCTAssertFalse(model.searching); XCTAssertEqual(model.searchQuery, "")
        XCTAssertNil(model.walletScrollOffset); XCTAssertNil(model.walletFocus); XCTAssertNil(model.walletAnchorID)
        XCTAssertNil(model.browseAnchor)
        XCTAssertEqual(model.walletLayout.sections.last?.title, "Today")
    }

}
