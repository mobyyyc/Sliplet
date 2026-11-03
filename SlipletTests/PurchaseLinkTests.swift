import XCTest
@testable import Sliplet

@MainActor final class PurchaseLinkTests: XCTestCase {
    private struct Key: ReceiptStoreKeyProvider {
        func loadKey() throws -> Data? { Data(repeating: 0x73, count: 32) }
        func createKey() throws -> Data { Data(repeating: 0x73, count: 32) }
    }

    private func create(_ store: ReceiptStore, marker: UInt8, amount: Int64 = 500,
                        merchant: String = "FICTIONAL STORE", code: String? = "123",
                        name: String = "FICTIONAL RICE 1 KG") async throws -> ReceiptRecord {
        let fixture = SplitFixture.record(amounts: [amount, 100], adjustments: [(.discount, -10)])
        var fields = fixture.current.fields
        fields.merchant = merchant
        fields.items[0].sku = code
        fields.items[0].description = name
        fields.items[0].quantity = try ReceiptDecimal(coefficient: amount == 1000 ? 2 : 1, scale: 0)
        fields.items[0].unitPrice = ReceiptMoney(minorUnits: 500, currency: .cad)
        // Unique fictional bytes exercise asset identity without touching real photos.
        var image = try SyntheticFixture.imageData()
        image.append(marker)
        return try await store.create(extraction: fixture.original, originalImage: image,
                                      mediaType: "image/png", correction: fields, review: .sourceReviewed)
    }

    private func load(_ store: ReceiptStore, id: UUID) async throws -> ReceiptRecord {
        let record = try await store.receipt(id: id)
        return try XCTUnwrap(record)
    }

    private func save(_ store: ReceiptStore, _ a: ReceiptRecord, _ b: ReceiptRecord,
                      verdict: PurchaseLinkDecision.Verdict? = .sameProduct,
                      pack: PurchaseLinkDecision.Pack = .same,
                      permit: ReceiptOperationPermit? = nil) async throws -> [ReceiptRecord] {
        try await store.savePurchaseLink(
            first: PurchaseEvidence(record: a, lineID: a.current.fields.items[0].id),
            second: PurchaseEvidence(record: b, lineID: b.current.fields.items[0].id),
            expectedFirstLinks: a.purchaseLinks?.id, expectedSecondLinks: b.purchaseLinks?.id,
            verdict: verdict, pack: pack, permit: permit)
    }

    private func decision(_ pair: [ReceiptRecord]) -> PurchaseLinkDecision? {
        PurchaseLinkEngine.decision(pair[0], line: pair[0].current.fields.items[0].id,
                                    pair[1], line: pair[1].current.fields.items[0].id)
    }

    private func candidate(_ a: ReceiptRecord, _ b: ReceiptRecord) -> PurchaseLinkEngine.Reason? {
        PurchaseLinkEngine.candidate(a, line: a.current.fields.items[0].id,
                                     b, line: b.current.fields.items[0].id)
    }

    func testDiscoveryNeverConfirmsIdentityOrEquatesAmounts() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReceiptStore(directory: directory, keyProvider: Key())
        let a = try await create(store, marker: 1)
        let b = try await create(store, marker: 2, amount: 1000)
        XCTAssertEqual(candidate(a, b), .sameStoreCode)
        XCTAssertNil(decision([a, b]))
        let pair = try await save(store, a, b)
        XCTAssertEqual(decision(pair)?.verdict, .sameProduct)
        XCTAssertEqual(pair[0].current.fields.items[0].unitPrice, pair[1].current.fields.items[0].unitPrice)
        XCTAssertNotEqual(pair[0].current.fields.items[0].amount, pair[1].current.fields.items[0].amount)
        XCTAssertEqual(pair[0].revisions, a.revisions)

        let otherStore = try await create(store, marker: 3, merchant: "OTHER STORE")
        XCTAssertNil(candidate(a, otherStore))
        let duplicate = try await create(store, marker: 1)
        XCTAssertNil(candidate(a, duplicate))
        let refund = try await create(store, marker: 4, amount: -500)
        XCTAssertNil(candidate(a, refund))
        let missingCode = try await create(store, marker: 5, code: nil)
        XCTAssertEqual(candidate(a, missingCode), .sameStoreDescription)
        let conflict = try await create(store, marker: 6, code: "456")
        XCTAssertNil(candidate(a, conflict))
        let changedPack = try await create(store, marker: 7, name: "FICTIONAL RICE 2 KG")
        XCTAssertEqual(candidate(a, changedPack), .sameStoreCode)
        XCTAssertNil(decision([a, changedPack]))
        let sameReceipt = PurchaseLinkEngine.candidate(a, line: a.current.fields.items[0].id,
                                                       a, line: a.current.fields.items[1].id)
        XCTAssertNil(sameReceipt)
        let adjustment = PurchaseLinkEngine.candidate(a, line: a.current.fields.adjustments[0].id,
                                                      b, line: b.current.fields.items[0].id)
        XCTAssertNil(adjustment)
        try await store.close()
    }

    func testEncryptedRestartUndoRejectionAndStaleWrites() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReceiptStore(directory: directory, keyProvider: Key())
        let a = try await create(store, marker: 1), b = try await create(store, marker: 2)
        XCTAssertNil(a.purchaseLinks)
        let pair = try await save(store, a, b)
        do { _ = try await save(store, a, b); XCTFail("Stale write succeeded") }
        catch { XCTAssertEqual(error as? ReceiptStoreError, .editConflict) }
        try await store.close()
        let bytes = try Data(contentsOf: directory.appendingPathComponent("receipts.sqlite"))
        XCTAssertNil(bytes.range(of: Data("purchaseLinks".utf8)))
        XCTAssertNil(bytes.range(of: Data("sameProduct".utf8)))
        let reopened = try ReceiptStore(directory: directory, keyProvider: Key())
        let loadedA = try await load(reopened, id: a.id)
        let loadedB = try await load(reopened, id: b.id)
        XCTAssertEqual(decision([loadedA, loadedB]), decision(pair))
        let removed = try await save(reopened, loadedA, loadedB, verdict: nil)
        XCTAssertNil(decision(removed))
        XCTAssertNil(decision([removed[0], pair[1]]), "One old peer must not resurrect an undone link")
        let rejected = try await save(reopened, removed[0], removed[1], verdict: .differentProduct, pack: .different)
        XCTAssertEqual(decision(rejected)?.verdict, .differentProduct)
        XCTAssertNil(candidate(rejected[0], rejected[1]))
        let undone = try await save(reopened, rejected[0], rejected[1], verdict: nil)
        XCTAssertEqual(candidate(undone[0], undone[1]), .sameStoreCode)
        try await reopened.close()
    }

    func testRevisionChangeAndRemovedLineInvalidateAndCanBeUnlinked() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReceiptStore(directory: directory, keyProvider: Key())
        let a = try await create(store, marker: 1), b = try await create(store, marker: 2)
        let pair = try await save(store, a, b)
        var fields = a.current.fields
        fields.items.removeFirst()
        let edited = try await store.revise(id: a.id, expectedRevision: a.current.id, fields: fields)
        XCTAssertNil(PurchaseLinkEngine.decision(edited, line: a.current.fields.items[0].id,
                                                 pair[1], line: b.current.fields.items[0].id))
        let cleared = try await store.savePurchaseLink(
            first: PurchaseEvidence(record: edited, lineID: a.current.fields.items[0].id),
            second: PurchaseEvidence(record: pair[1], lineID: b.current.fields.items[0].id),
            expectedFirstLinks: edited.purchaseLinks?.id, expectedSecondLinks: pair[1].purchaseLinks?.id,
            verdict: nil)
        XCTAssertTrue(cleared.allSatisfy { $0.purchaseLinks?.decisions.isEmpty == true })
        try await store.close()
    }

    func testPairWriteRollsBackAndRevokedWriteDoesNotCommit() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReceiptStore(directory: directory, keyProvider: Key())
        let a = try await create(store, marker: 1), b = try await create(store, marker: 2)
        let permit = ReceiptOperationPermit()
        permit.revoke()
        do { _ = try await save(store, a, b, permit: permit); XCTFail("Revoked write succeeded") }
        catch { XCTAssertTrue(error is CancellationError) }
        try await store.close()
        let faulty = try ReceiptStore(directory: directory, keyProvider: Key(), fault: { point in
            if point == .afterReceiptWrite { throw ReceiptStoreError.injectedFailure }
        })
        do { _ = try await save(faulty, a, b); XCTFail("Partial write committed") }
        catch { XCTAssertEqual(error as? ReceiptStoreError, .injectedFailure) }
        let unchangedA = try await faulty.receipt(id: a.id)
        let unchangedB = try await faulty.receipt(id: b.id)
        XCTAssertEqual(unchangedA, a); XCTAssertEqual(unchangedB, b)
        try await faulty.close()
    }

    func testLinksStayScopedToExplicitRowsAndDoNotBecomeTransitive() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReceiptStore(directory: directory, keyProvider: Key())
        let a = try await create(store, marker: 1)
        let b = try await create(store, marker: 2)
        let c = try await create(store, marker: 3)
        let ab = try await save(store, a, b)
        let bc = try await save(store, ab[1], c, pack: .unknown)
        XCTAssertEqual(decision([ab[0], bc[0]])?.verdict, .sameProduct)
        XCTAssertEqual(decision(bc)?.pack, .unknown)
        XCTAssertNil(decision([ab[0], bc[1]]))
        XCTAssertNil(PurchaseLinkEngine.decision(ab[0], line: a.current.fields.items[1].id,
                                                 bc[0], line: b.current.fields.items[0].id))
        let starred = try await store.organize(id: a.id, expectedRevision: a.current.id, action: .star)
        XCTAssertEqual(decision([starred, bc[0]])?.verdict, .sameProduct)
        try await store.delete(id: b.id)
        let missing = try await store.receipt(id: b.id)
        XCTAssertNil(missing)
        // Malformed mirrored data cannot be accepted through backup decoding.
        var malformed = starred
        let duplicateDecision = try XCTUnwrap(malformed.purchaseLinks?.decisions.first)
        malformed.purchaseLinks?.decisions.append(duplicateDecision)
        XCTAssertThrowsError(try malformed.validate())
        try await store.close()
    }

    func testLegacyRecordDecodesAndCannotLinkInvalidEndpoints() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReceiptStore(directory: directory, keyProvider: Key())
        let a = try await create(store, marker: 1)
        let duplicate = try await create(store, marker: 1)
        let refund = try await create(store, marker: 3, amount: -100)
        let bytes = try JSONEncoder().encode(a)
        let legacy = try JSONDecoder().decode(ReceiptRecord.self, from: bytes)
        XCTAssertNil(legacy.purchaseLinks)
        for invalid in [a, duplicate, refund] {
            do { _ = try await save(store, a, invalid); XCTFail("Invalid pair saved") }
            catch { XCTAssertEqual(error as? ReceiptValidationError, .invalidEvidence) }
        }
        try await store.close()
    }

    func testHistoryLabelsArchiveDraftChangedAndRejectedPurchases() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReceiptStore(directory: directory, keyProvider: Key())
        let a = try await create(store, marker: 1)
        let b = try await create(store, marker: 2)
        let c = try await create(store, marker: 3)
        let endpoint = PurchaseEndpoint(receiptID: a.id, lineID: a.current.fields.items[0].id)
        let ab = try await save(store, a, b)
        let ac = try await save(store, ab[0], c, verdict: .differentProduct)
        let archived = try await store.organize(id: b.id, expectedRevision: b.current.id, action: .archive)
        let initial = PurchaseHistoryEntry.entries(for: endpoint, in: [ac[0], archived, ac[1]])
        XCTAssertTrue(initial.contains { $0.record.isArchived && $0.status == .confirmed })
        XCTAssertTrue(initial.contains { $0.record.id == c.id && $0.status == .different })
        var fields = b.current.fields
        fields.purchaseDate = nil
        let edited = try await store.revise(id: b.id, expectedRevision: b.current.id, fields: fields)
        let changed = PurchaseHistoryEntry.entries(for: endpoint, in: [ac[0], edited, ac[1]])
        XCTAssertEqual(changed.last?.record.id, b.id)
        XCTAssertEqual(changed.last?.status, .changed)
        XCTAssertEqual(changed.last?.record.current.review, .draft)
        try await store.delete(id: b.id)
        let surviving = try await store.receipts()
        XCTAssertFalse(PurchaseHistoryEntry.entries(for: endpoint, in: surviving).contains { $0.record.id == b.id })
        try await store.close()
    }

    func testWorkspacePublishesPairTogetherAndRejectsLockedAccess() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReceiptStore(directory: directory, keyProvider: Key())
        let a = try await create(store, marker: 1), b = try await create(store, marker: 2)
        try await store.close()
        let workspace = ReceiptWorkspace(directory: directory, keyProvider: Key())
        workspace.activate(protectedDataAvailable: true)
        for _ in 0..<200 {
            if workspace.availability == .ready { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(workspace.availability, .ready)
        try await workspace.savePurchaseDecision(first: a, line: a.current.fields.items[0].id,
                                                  second: b, line: b.current.fields.items[0].id,
                                                  verdict: .sameProduct, pack: .same)
        let left = try XCTUnwrap(workspace.receipts.first { $0.id == a.id })
        let right = try XCTUnwrap(workspace.receipts.first { $0.id == b.id })
        XCTAssertEqual(decision([left, right])?.verdict, .sameProduct)
        XCTAssertFalse(workspace.saving)
        workspace.suspend()
        XCTAssertTrue(workspace.receipts.isEmpty)
        do { _ = try await workspace.purchaseOriginal(id: a.id); XCTFail("Locked original exposed") }
        catch { XCTAssertTrue(error is CancellationError) }
        do {
            try await workspace.savePurchaseDecision(first: left, line: a.current.fields.items[0].id,
                                                      second: right, line: b.current.fields.items[0].id,
                                                      verdict: nil, pack: .unknown)
            XCTFail("Locked change committed")
        } catch { XCTAssertTrue(error is CancellationError) }
    }

    func testPriceVerificationPersistsReversesAndClears() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReceiptStore(directory: directory, keyProvider: Key())
        let a = try await create(store, marker: 1)
        let b = try await create(store, marker: 2, amount: 1000)
        let evidence = PurchasePriceEvidence(firstBasis: .calculated, secondBasis: .printed,
                                             firstUnit: .each, secondUnit: .each, tax: .beforeTax)
        let pair = try await store.savePurchaseLink(
            first: PurchaseEvidence(record: a, lineID: a.current.fields.items[0].id),
            second: PurchaseEvidence(record: b, lineID: b.current.fields.items[0].id),
            expectedFirstLinks: nil, expectedSecondLinks: nil, verdict: .sameProduct, pack: .same,
            priceEvidence: evidence)
        XCTAssertEqual(decision(pair)?.priceEvidence, evidence)
        try await store.close()
        let reopened = try ReceiptStore(directory: directory, keyProvider: Key())
        let left = try await load(reopened, id: a.id), right = try await load(reopened, id: b.id)
        let saved = try XCTUnwrap(decision([left, right])?.priceEvidence)
        XCTAssertEqual(saved, evidence)
        let result = try PurchasePriceComparison.compare(right, line: b.current.fields.items[0].id,
                                                         left, line: a.current.fields.items[0].id,
                                                         evidence: saved.reversed)
        XCTAssertEqual(result.order, .orderedSame)
        let cleared = try await save(reopened, left, right)
        XCTAssertNil(decision(cleared)?.priceEvidence)
        XCTAssertEqual(decision(cleared)?.verdict, .sameProduct)
        try await reopened.close()
    }

    func testBackupRestoresPairButCannotOverwriteUndoFromOldPeer() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try ReceiptStore(directory: directory.appendingPathComponent("source"), keyProvider: Key())
        let a = try await create(source, marker: 1), b = try await create(source, marker: 2)
        let pair = try await save(source, a, b)
        let archive = directory.appendingPathComponent("fictional.slipletbackup")
        try await source.exportBackup(to: archive, password: "fictional password", permit: ReceiptOperationPermit())
        let prepared = try await ReceiptBackupPreparation.prepare(url: archive, password: "fictional password", permit: ReceiptOperationPermit())
        let target = try ReceiptStore(directory: directory.appendingPathComponent("target"), keyProvider: Key())
        let preview = try await target.previewBackup(prepared, permit: ReceiptOperationPermit())
        _ = try await target.mergeBackup(prepared, expected: preview, permit: ReceiptOperationPermit())
        let restoredA = try await load(target, id: a.id)
        let restoredB = try await load(target, id: b.id)
        XCTAssertEqual(decision([restoredA, restoredB]), decision(pair))
        let cleared = try await save(target, restoredA, restoredB, verdict: nil)
        try await target.delete(id: b.id)
        let again = try await target.previewBackup(prepared, permit: ReceiptOperationPermit())
        _ = try await target.mergeBackup(prepared, expected: again, permit: ReceiptOperationPermit())
        let oldPeer = try await load(target, id: b.id)
        XCTAssertNil(decision([cleared[0], oldPeer]))
        try await source.close(); try await target.close()
    }
}
