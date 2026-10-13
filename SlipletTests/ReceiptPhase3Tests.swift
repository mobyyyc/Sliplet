import XCTest
import UIKit
import ImageIO
import CryptoKit
@testable import Sliplet

@MainActor final class ReceiptPhase3Tests: XCTestCase {
    private func editable(_ review: ReceiptRevision.Review = .sourceReviewed, input: Bool = true) throws -> ReceiptWorkspace {
        let model = ReceiptWorkspace(); model.active = true; model.availability = .ready
        let record = SearchFixture.record()
        var draft = ReceiptReviewDraft(fields: record.current.fields)
        draft.subtotalNotPrinted = true; draft.sourceOpened = true; draft.sourceChecked = review == .sourceReviewed
        let revision = ReceiptRevision(id: UUID(), createdAt: record.updatedAt, fields: record.current.fields,
                                       review: review, reviewInput: input ? try JSONEncoder().encode(draft) : nil)
        model.selected = ReceiptRecord(id: record.id, createdAt: record.createdAt, updatedAt: record.updatedAt,
            original: record.original, asset: record.asset, revisions: record.revisions + [revision])
        model.image = try ReceiptImage.decode(SyntheticFixture.imageData()); model.extraction = record.original; model.flow = .detail
        return model
    }
    func testExistingReviewSurvivesOpeningNoOpDateAndAdvisoryChanges() throws {
        let model = try editable(); model.edit()
        XCTAssertTrue(model.draft.sourceChecked); XCTAssertTrue(model.draft.sourceOpened)
        XCTAssertTrue(model.draft.canFinalize); XCTAssertFalse(model.hasUnsavedReviewChanges)
        let date = model.draft.date
        model.updateDraft { $0.date = date }
        XCTAssertTrue(model.draft.sourceChecked); XCTAssertFalse(model.hasUnsavedReviewChanges)
        model.updateDraft { $0.guidanceChecks = ["fictional-check": "fictional-signature"] }
        XCTAssertTrue(model.draft.sourceChecked); XCTAssertTrue(model.hasUnsavedReviewChanges)
        model.finishEditing(); XCTAssertEqual(model.flow, .detail)
        model.edit(); XCTAssertTrue(model.draft.sourceChecked); XCTAssertFalse(model.hasUnsavedReviewChanges)
    }
    func testRealAndTemporarilyMalformedEditsRequireConfirmationWithoutReopeningOriginal() throws {
        let model = try editable(); model.edit()
        model.updateDraft { $0.merchant += " CHANGED" }
        XCTAssertFalse(model.draft.sourceChecked); XCTAssertTrue(model.draft.sourceOpened)
        XCTAssertFalse(model.draft.canFinalize); XCTAssertTrue(model.hasUnsavedReviewChanges)
        model.draft.sourceChecked = true
        model.updateDraft { $0.total = "not a number" }
        XCTAssertFalse(model.draft.sourceChecked); XCTAssertFalse(model.draft.canSaveDraft)
        XCTAssertTrue(model.draft.sourceOpened)
    }
    func testLegacyReviewedReceiptsPreserveConfirmationButDraftsNeverAcquireIt() throws {
        let legacy = try editable(input: false); legacy.edit()
        XCTAssertTrue(legacy.draft.sourceChecked); XCTAssertTrue(legacy.draft.canFinalize)
        for input in [true, false] {
            let draft = try editable(.draft, input: input); draft.edit()
            XCTAssertFalse(draft.draft.sourceChecked); XCTAssertFalse(draft.draft.canFinalize)
        }
    }
    func testFinishingAnUnchangedReviewedReceiptKeepsRevisionAndFinalizedSplit() throws {
        let model = try editable()
        var record = try XCTUnwrap(model.selected), plan = ReceiptSplitPlan()
        let person = SplitParticipant(id: UUID(), name: "FICTIONAL PERSON")
        plan.participants = [person]
        plan.assignments = Dictionary(uniqueKeysWithValues: record.current.fields.items.map { ($0.id, [person.id]) })
        plan.finalizedRevision = record.current.id; record.splitPlan = plan; model.selected = record
        XCTAssertEqual(try ReceiptSplitEngine.compute(record, plan: plan).total, 300)
        model.edit(); XCTAssertFalse(model.hasUnsavedReviewChanges)
        model.save(asDraft: false)
        XCTAssertEqual(model.flow, .detail); XCTAssertEqual(model.selected, record)
        XCTAssertEqual(model.selected?.splitPlan?.finalizedRevision, record.current.id)
    }
    func testReverseSwipeIsContinuousClosesAtCenterAndHonorsDisabledActions() {
        for start: CGFloat in [-108, 108] {
            var previous = start
            for step in 0...300 {
                let translation = CGFloat(step) * (start < 0 ? 1 : -1)
                let next = ReceiptSwipeGeometry.offset(start: start, translation: translation, leftEnabled: false, rightEnabled: false)
                XCTAssertLessThanOrEqual(abs(next - previous), 1)
                XCTAssertTrue(start < 0 ? next <= 0 : next >= 0)
                previous = next
            }
            XCTAssertEqual(previous, 0); XCTAssertEqual(ReceiptSwipeGeometry.settled(previous), 0)
        }
        XCTAssertEqual(ReceiptSwipeGeometry.offset(start: 0, translation: -100, leftEnabled: false, rightEnabled: true), 0)
        XCTAssertEqual(ReceiptSwipeGeometry.offset(start: 0, translation: 100, leftEnabled: true, rightEnabled: false), 0)
        XCTAssertEqual(ReceiptSwipeGeometry.settled(-70), -108)
        XCTAssertEqual(ReceiptSwipeGeometry.settled(30), 0)
    }
    func testIncrementalSearchKeepsEvidenceAndMetadataWithoutRetokenizingTheWallet() {
        var records = (0..<500).map { _ in SearchFixture.record() }
        var index = ReceiptSearchIndex(records)
        XCTAssertEqual(index.lastRebuiltDocumentCount, 500)
        records[200].organization = .init(archived: true, starred: true)
        records[100].splitPlan = ReceiptSplitPlan()
        let start = ContinuousClock.now
        index.update(records)
        let duration = start.duration(to: .now)
        XCTAssertEqual(index.lastRebuiltDocumentCount, 0)
        let fresh = ReceiptSearchIndex(records)
        for query in ["milk", "old 123456", "rawtoken", "fennel", "removed apples", "苹果", ""] {
            XCTAssertEqual(index.results(query: query, includeArchived: true).map(\.id), fresh.results(query: query, includeArchived: true).map(\.id))
        }
        XCTAssertEqual(index.results(query: "milk", collection: "Archive").first?.record.organization, records[200].organization)
        var fields = records[0].current.fields; fields.items[0].description = "FICTIONAL UPDATED BREAD"
        let old = records[0]
        records[0] = ReceiptRecord(id: old.id, createdAt: old.createdAt, updatedAt: old.updatedAt, original: old.original, asset: old.asset,
            revisions: old.revisions + [.init(id: UUID(), createdAt: old.updatedAt, fields: fields, review: .draft)])
        index.update(records); XCTAssertEqual(index.lastRebuiltDocumentCount, 1)
        XCTAssertEqual(index.results(query: "updated bread").first?.id, old.id)
        XCTAssertEqual(index.results(query: "org mlk", includeArchived: true).count, 500)
        print("P3_SAFE_INDEX metadata_refresh_500=\(duration) retokenized=0 changed_receipt_retokenized=1")
    }
    nonisolated private static func measuredRaster(_ bytes: Data) -> (CGImage?, Bool) {
        (ReceiptDisplayImage.raster(bytes), Thread.isMainThread)
    }
    func testBackgroundRasterPreservesEncodedBytesAndBoundsLongDisplay() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let bytes = UIGraphicsImageRenderer(size: CGSize(width: 2200, height: 8200), format: format).pngData { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 2200, height: 8200))
            UIColor.black.setFill(); context.fill(CGRect(x: 200, y: 8000, width: 1000, height: 80))
        }
        let digest = SHA256.hash(data: bytes)
        let (raster, main) = await Task.detached { Self.measuredRaster(bytes) }.value
        let image = try XCTUnwrap(raster)
        XCTAssertFalse(main); XCTAssertLessThanOrEqual(image.width, 2048)
        XCTAssertLessThanOrEqual(image.width * image.height, 16_020_000)
        XCTAssertEqual(Double(image.width) / Double(image.height), 2200.0 / 8200, accuracy: 0.001)
        XCTAssertEqual(SHA256.hash(data: bytes), digest)
    }
    func testViewerResizePreservesRelativeZoomAndCancelledDecodeCannotReappear() async throws {
        let bytes = try SyntheticFixture.imageData()
        let coordinator = ZoomReceiptImage.Coordinator(), view = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        coordinator.scrollView = view; view.delegate = coordinator
        coordinator.imageView.image = UIImage(data: bytes); coordinator.imageView.frame = CGRect(x: 0, y: 0, width: 800, height: 3000)
        view.addSubview(coordinator.imageView); view.contentSize = coordinator.imageView.bounds.size
        coordinator.fit(view); view.setZoomScale(view.minimumZoomScale * 2, animated: false)
        view.frame.size.width = 390; coordinator.fit(view)
        XCTAssertEqual(view.zoomScale / view.minimumZoomScale, 2, accuracy: 0.01)
        let cancelled = ZoomReceiptImage.Coordinator(); cancelled.scrollView = view
        cancelled.update(bytes: bytes, boxes: []); cancelled.stopObserving(); cancelled.imageView.image = nil
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertNil(cancelled.imageView.image)
    }
}
