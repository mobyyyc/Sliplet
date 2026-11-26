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
        XCTAssertEqual(model.collection, "All receipts"); XCTAssertEqual(model.searchQuery, "milk")
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
    func testLeavingSearchClearsTheQueryAndPreservesArchiveScope() throws {
        let model = ReceiptWorkspace(); let record = SearchFixture.record()
        model.receipts = [revised(record, date: record.current.fields.purchaseDate, archived: true)]
        model.applyBrowseFilters(merchant: .value("FICTIONAL CORNER MART"), month: .all, archived: false, scope: "Archive")
        model.searching = true; model.searchQuery = "milk"
        let row = try XCTUnwrap(model.browsing.rows.first)
        model.browseAnchor = .init(rowID: row.id, receiptID: record.id, y: 200)
        model.endSearch()
        XCTAssertFalse(model.searching); XCTAssertEqual(model.searchQuery, "")
        XCTAssertNil(model.browseAnchor)
        XCTAssertEqual(model.merchantFilter, .value("FICTIONAL CORNER MART"))
        XCTAssertEqual(model.collection, "Archive")
        XCTAssertEqual(model.walletReceipts.map(\.id), [record.id])
        XCTAssertTrue(model.receipts[0].isArchived)
    }
    func testSharedMonthAndTotalScopeProduceIdenticalWalletAndListIdentities() throws {
        let model = ReceiptWorkspace(); let record = SearchFixture.record(); model.receipts = [record]
        var extra = ReceiptBrowsingFilter(); extra.minimum = "3.00"; extra.maximum = "3.00"
        model.applyBrowseFilters(merchant: .all, month: .value("2026-10"), archived: false, extra: extra)
        XCTAssertEqual(model.walletReceipts.map(\.id), model.browsing.rows.map { $0.record.id })
        XCTAssertEqual(model.walletReceipts.count, 1)
        extra.maximum = "2.99"; extra.minimum = ""
        model.applyBrowseFilters(merchant: .all, month: .all, archived: false, extra: extra)
        XCTAssertTrue(model.walletReceipts.isEmpty); XCTAssertEqual(model.browsing.receiptCount, 0)
        model.resetBrowseFilters(); XCTAssertEqual(model.walletReceipts.count, 1)
    }
    func testIncludeArchivedPreservesQueryAndFiltersForOriginalOnlyEvidence() throws {
        let record = revised(SearchFixture.record(), date: try ReceiptDate(year: 2026, month: 10, day: 8), archived: true)
        let model = ReceiptWorkspace()
        model.receipts = [record]
        model.searchQuery = "corner removed apples"
        let merchant: ReceiptHistoryChoice = .value("FICTIONAL CORNER MART")
        let month: ReceiptHistoryChoice = .value("2026-10")
        var filter = ReceiptBrowsingFilter()
        filter.dateMode = .day
        filter.start = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: .init(year: 2026, month: 10, day: 8)))
        filter.minimum = "3.00"; filter.maximum = "3.00"
        model.applyBrowseFilters(merchant: merchant, month: month, archived: false, scope: "Needs review", extra: filter)
        XCTAssertTrue(model.hasArchivedSearchMatch)
        XCTAssertEqual(model.browsing.receiptCount, 0)

        model.includeArchived = true
        XCTAssertFalse(model.hasArchivedSearchMatch)
        XCTAssertEqual(model.browsing.receiptCount, 1)
        let row = try XCTUnwrap(model.browsing.rows.first)
        XCTAssertEqual(row.record.id, record.id)
        XCTAssertTrue(row.record.isArchived)
        XCTAssertTrue(try XCTUnwrap(row.match).originalOnly)
        XCTAssertEqual(model.searchQuery, "corner removed apples")
        XCTAssertEqual(model.merchantFilter, merchant)
        XCTAssertEqual(model.monthFilter, month)
        XCTAssertEqual(model.collection, "Needs review")
        XCTAssertEqual(model.browsingFilter, filter)
        XCTAssertEqual(model.receipts, [record])

        model.includeArchived = false
        XCTAssertTrue(model.hasArchivedSearchMatch)
    }

    func testArchiveShortcutRequiresAnEligibleMatchAndNoCurrentResults() throws {
        var archived = SearchFixture.record()
        archived.organization = .init(archived: true, starred: false)
        let active = SearchFixture.record()
        let model = ReceiptWorkspace()
        model.receipts = [archived, active]
        model.searchQuery = "milk"
        XCTAssertFalse(model.hasArchivedSearchMatch)
        XCTAssertEqual(model.browsing.receiptCount, 1)
        model.receipts = [archived]
        XCTAssertTrue(model.hasArchivedSearchMatch)

        for query in ["", "  ", "…", String(repeating: "a", count: 513), "no matching evidence"] {
            model.searchQuery = query
            XCTAssertFalse(model.hasArchivedSearchMatch, query)
        }
        model.searchQuery = "milk"
        model.applyBrowseFilters(merchant: .value("FICTIONAL DIFFERENT STORE"), month: .all, archived: false)
        XCTAssertFalse(model.hasArchivedSearchMatch)
        model.applyBrowseFilters(merchant: .all, month: .value("2026-11"), archived: false)
        XCTAssertFalse(model.hasArchivedSearchMatch)

        var constraint = ReceiptBrowsingFilter()
        constraint.maximum = "2.99"
        model.applyBrowseFilters(merchant: .all, month: .all, archived: false, extra: constraint)
        XCTAssertFalse(model.hasArchivedSearchMatch)
        model.resetBrowseFilters()
        model.collection = "Starred"
        XCTAssertFalse(model.hasArchivedSearchMatch)
        archived.organization?.starred = true
        model.receipts = [archived]
        XCTAssertTrue(model.hasArchivedSearchMatch)
        model.collection = "Archive"
        XCTAssertFalse(model.hasArchivedSearchMatch)
        XCTAssertEqual(model.browsing.receiptCount, 1)
    }

    func testClearPurchaseFiltersPreservesQueryCollectionArchiveAndCurrency() throws {
        var archivedStar = SearchFixture.record()
        archivedStar.organization = .init(archived: true, starred: true)
        let other = SearchFixture.record()
        let model = ReceiptWorkspace()
        model.active = true
        model.searching = true
        model.receipts = [archivedStar, other]
        model.searchQuery = "old 123456"

        var filters = ReceiptBrowsingFilter()
        filters.dateMode = .day
        filters.start = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: .init(year: 2026, month: 10, day: 25)))
        filters.maximum = "2.99"
        filters.currency = try ReceiptCurrency(code: "USD", minorUnitScale: 2)
        model.applyBrowseFilters(merchant: .value("FICTIONAL DIFFERENT STORE"), month: .all,
                                 archived: true, scope: "Starred", extra: filters)
        XCTAssertEqual(model.browsing.receiptCount, 0)
        XCTAssertTrue(model.hasMatchOutsidePurchaseFilters)

        let version = model.browseVersion
        model.clearPurchaseFiltersForSearch()
        XCTAssertEqual(model.browseVersion, version + 1)
        XCTAssertEqual(model.searchQuery, "old 123456")
        XCTAssertEqual(model.collection, "Starred")
        XCTAssertTrue(model.includeArchived)
        XCTAssertEqual(model.merchantFilter, .all)
        XCTAssertEqual(model.monthFilter, .all)
        XCTAssertFalse(model.browsingFilter.active)
        XCTAssertEqual(model.browsingFilter.currency, filters.currency)
        XCTAssertFalse(model.hasMatchOutsidePurchaseFilters)
        XCTAssertEqual(model.browsing.rows.map { $0.record.id }, [archivedStar.id])
        XCTAssertEqual(model.browsing.rows.first?.match?.basis, .originalSKU)
        XCTAssertEqual(model.receipts, [archivedStar, other])
    }

    func testRecoveryOffersOnlyActionsThatFindResultsInTheirOwnScope() {
        let active = SearchFixture.record()
        var archived = revised(SearchFixture.record(), date: nil, archived: true)
        archived.organization?.starred = true
        let model = ReceiptWorkspace()
        model.receipts = [active, archived]
        model.searchQuery = "milk"
        model.applyBrowseFilters(merchant: .all, month: .missing, archived: false)
        XCTAssertTrue(model.hasArchivedSearchMatch)
        XCTAssertFalse(model.hasMatchOutsidePurchaseFilters, "Prefer the archive shortcut when it preserves the current purchase filters")
        model.applyBrowseFilters(merchant: .value("FICTIONAL DIFFERENT STORE"), month: .all, archived: false)
        XCTAssertTrue(model.hasMatchOutsidePurchaseFilters)
        XCTAssertFalse(model.hasArchivedSearchMatch)
        model.collection = "Starred"
        XCTAssertFalse(model.hasMatchOutsidePurchaseFilters, "The matching star is archived, and archived receipts are currently excluded")
        XCTAssertFalse(model.hasArchivedSearchMatch, "The archive shortcut would also have to keep the store filter")
        model.collection = "Archive"
        XCTAssertTrue(model.hasMatchOutsidePurchaseFilters)
        XCTAssertFalse(model.hasArchivedSearchMatch)

        for query in ["", "  ", "…", String(repeating: "a", count: 513), "missingword", "milk creme"] {
            model.searchQuery = query
            XCTAssertFalse(model.hasMatchOutsidePurchaseFilters, query)
            XCTAssertFalse(model.hasArchivedSearchMatch, query)
        }
    }

    func testRecoveryFollowsRapidQueriesAndFilterChangesWithThousandReceipts() {
        let model = ReceiptWorkspace()
        model.receipts = (0..<1_000).map { _ in SearchFixture.record() }
        XCTAssertEqual(model.searchIndex.count, 1_000)
        let cases: [(String, Bool)] = [
            ("m", true), ("mi", true), ("mil", true), ("milk", true),
            ("milk x", false), ("milk absent", false), ("old 123456", true),
            ("fennel", true), ("no matching evidence", false), ("", false)
        ]
        var durations: [Double] = []
        for turn in 0..<6 {
            var amount = ReceiptBrowsingFilter()
            amount.maximum = "2.99"
            model.applyBrowseFilters(merchant: turn.isMultiple(of: 2) ? .value("FICTIONAL DIFFERENT STORE") : .all,
                                     month: .all, archived: false, extra: amount)
            for (query, expectedRecovery) in cases {
                let start = ProcessInfo.processInfo.systemUptime
                model.searchQuery = query
                durations.append(ProcessInfo.processInfo.systemUptime - start)
                XCTAssertEqual(model.hasMatchOutsidePurchaseFilters, expectedRecovery)
                XCTAssertEqual(model.browsing.receiptCount, 0)
                XCTAssertFalse(model.hasArchivedSearchMatch)
            }
        }
        XCTAssertEqual(model.searchIndex.count, 1_000)
        let sorted = durations.sorted()
        print("P19-03 fictional search updates=\(sorted.count) p95_ms=\(sorted[56] * 1_000) max_ms=\(sorted[59] * 1_000)")
    }

    func testDateBoundsAreInclusiveAndAmountScopeNeverMixesCurrencies() throws {
        let record = SearchFixture.record(); let date = try XCTUnwrap(record.current.fields.purchaseDate)
        let calendar = Calendar(identifier: .gregorian)
        let exact = try XCTUnwrap(calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)))
        var filter = ReceiptBrowsingFilter(); filter.dateMode = .day; filter.start = exact
        XCTAssertTrue(filter.accepts(record))
        filter.dateMode = .range; filter.end = exact; XCTAssertTrue(filter.accepts(record))
        filter.end = calendar.date(byAdding: .day, value: -1, to: exact)!; XCTAssertNotNil(filter.validation)
        filter.dateMode = .any; filter.minimum = "3.00"; filter.maximum = "3.00"
        XCTAssertTrue(filter.accepts(record))
        filter.currency = try ReceiptCurrency(code: "USD", minorUnitScale: 2)
        XCTAssertFalse(filter.accepts(record))
        filter.minimum = "invalid"; XCTAssertNotNil(filter.validation); XCTAssertFalse(filter.accepts(record))
    }

}
