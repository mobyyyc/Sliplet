import XCTest
@testable import Sliplet

@MainActor final class ReceiptBrowsingTests: XCTestCase {
    private func revised(_ base: ReceiptRecord, date: ReceiptDate?, archived: Bool = false) -> ReceiptRecord {
        var fields = base.current.fields; fields.purchaseDate = date
        return ReceiptRecord(id: base.id, createdAt: base.createdAt, updatedAt: base.updatedAt, original: base.original,
            asset: base.asset, revisions: [.init(id: UUID(), createdAt: base.createdAt, fields: fields, review: .draft)],
            organization: ReceiptOrganization(archived: archived, starred: false))
    }
    func testGroupedSearchKeepsCurrentAndOriginalOnlyPurchaseEvidenceDistinct() throws {
        let record = SearchFixture.record()
        let current = ReceiptBrowsingSnapshot(results: ReceiptSearchIndex([record]).results(query: "milk"))
        XCTAssertEqual(current.receiptCount, 1); XCTAssertEqual(current.rows.count, 1)
        XCTAssertEqual(current.sections.first?.rows.first?.record.id, record.id)
        XCTAssertFalse(try XCTUnwrap(current.rows.first?.match).originalOnly)
        let evidence = ReceiptBrowsingSnapshot(results: ReceiptSearchIndex([record]).results(query: "removed apples"))
        XCTAssertTrue(try XCTUnwrap(evidence.rows.first?.match).originalOnly)
        XCTAssertNil(evidence.rows.first?.match?.itemID)
        let merchant = ReceiptBrowsingSnapshot(results: ReceiptSearchIndex([record]).results(query: "fictional corner"))
        XCTAssertEqual(merchant.rows.first?.id, "receipt-" + record.id.uuidString)
        XCTAssertEqual(merchant.rows.first?.match?.basis, .merchant)
    }
    func testDeletedResultRestoresNextSurvivingPurchaseAtTheSameAnchor() throws {
        let records = (0..<4).map { _ in SearchFixture.record() }
        let old = ReceiptBrowsingSnapshot(results: ReceiptSearchIndex(records).results(query: "milk"))
        let target = old.rows[1]
        let anchor = ReceiptBrowsingAnchor(rowID: target.id, receiptID: target.record.id, y: 320)
        let next = ReceiptBrowsingSnapshot(results: ReceiptSearchIndex(records.filter { $0.id != target.record.id }).results(query: "milk"))
        let restored = try XCTUnwrap(next.restored(anchor, from: old))
        XCTAssertEqual(restored.receiptID, old.rows[2].record.id); XCTAssertEqual(restored.y, 320)
        XCTAssertNil(ReceiptBrowsingSnapshot().restored(anchor, from: old))
    }
    func testFiltersCommitOnceAndRemainExplicitWhenTheLastMatchingDateChanges() throws {
        let model = ReceiptWorkspace()
        let record = SearchFixture.record(); model.receipts = [record]
        let before = model.browseVersion
        model.applyBrowseFilters(merchant: .value("FICTIONAL CORNER MART"), month: .value("2026-10"), archived: false)
        XCTAssertEqual(model.browseVersion, before + 1); XCTAssertEqual(model.browsing.receiptCount, 1)
        model.receipts = [revised(record, date: try ReceiptDate(year: 2026, month: 11, day: 3))]
        XCTAssertEqual(model.monthFilter, .value("2026-10")); XCTAssertEqual(model.browsing.receiptCount, 0)
        model.collection = "Starred"; model.searchQuery = "milk"
        model.resetBrowseFilters()
        XCTAssertEqual(model.collection, "Starred"); XCTAssertEqual(model.searchQuery, "milk")
        XCTAssertEqual(model.monthFilter, .all)
    }
    func testWalletFocusFollowsIdentityAcrossDateEditsArchiveAndRemoval() throws {
        let model = ReceiptWorkspace()
        let first = revised(SearchFixture.record(), date: try ReceiptDate(year: 2026, month: 9, day: 1))
        let second = revised(SearchFixture.record(), date: try ReceiptDate(year: 2026, month: 10, day: 1))
        model.receipts = [first, second]
        model.walletAnchorID = first.id; model.walletAnchorY = 180
        model.receipts = [revised(first, date: try ReceiptDate(year: 2026, month: 11, day: 1)), second]
        XCTAssertEqual(model.walletFocus?.receiptID, first.id); XCTAssertEqual(model.walletFocus?.y, 180)
        model.walletFocus = nil
        model.receipts = [revised(first, date: try ReceiptDate(year: 2026, month: 11, day: 1), archived: true), second]
        XCTAssertEqual(model.walletFocus?.receiptID, second.id)
        XCTAssertEqual(model.walletLayout.receiptIDs, [second.id])
    }
    func testViewSwitchPreservesSearchAndFiltersAndNeverUnarchivesAReceipt() throws {
        let model = ReceiptWorkspace(); let record = SearchFixture.record()
        model.receipts = [record]; model.library = true; model.searchQuery = "milk"
        model.applyBrowseFilters(merchant: .value("FICTIONAL CORNER MART"), month: .all, archived: false)
        let row = try XCTUnwrap(model.browsing.rows.first)
        model.browseAnchor = .init(rowID: row.id, receiptID: record.id, y: 200)
        model.switchReceiptView()
        XCTAssertFalse(model.library); XCTAssertEqual(model.walletFocus?.receiptID, record.id)
        model.switchReceiptView()
        XCTAssertTrue(model.library); XCTAssertEqual(model.searchQuery, "milk")
        XCTAssertEqual(model.merchantFilter, .value("FICTIONAL CORNER MART")); XCTAssertEqual(model.browseAnchor?.rowID, row.id)
        model.receipts = [revised(record, date: record.current.fields.purchaseDate, archived: true)]
        model.showCollection("Archive"); let archived = try XCTUnwrap(model.browsing.rows.first)
        model.browseAnchor = .init(rowID: archived.id, receiptID: record.id, y: 200); model.walletFocus = nil
        model.switchReceiptView()
        XCTAssertNil(model.walletFocus); XCTAssertTrue(model.receipts[0].isArchived); XCTAssertEqual(model.collection, "Archive")
    }
}
