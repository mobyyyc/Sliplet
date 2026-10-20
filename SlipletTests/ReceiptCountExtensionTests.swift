import XCTest
@testable import Sliplet

@MainActor final class ReceiptCountExtensionTests: XCTestCase {
    private struct Key: ReceiptStoreKeyProvider {
        func loadKey() throws -> Data? { Data(repeating: 0x67, count: 32) }
        func createKey() throws -> Data { Data(repeating: 0x67, count: 32) }
    }
    private func rows(_ entries: [(String, Double, Double)]) throws -> [ReceiptOCRLine] {
        try entries.map { text, x, y in try .init(id: UUID(), text: text, engineConfidence: nil,
            boundingBox: ReceiptOCRBox(x: x, y: y, width: 0.5, height: 0.025)) }
    }
    private func fixture() throws -> [ReceiptOCRLine] {
        try rows([("NO FRILLS",0.1,0.95),("CAD",0.1,0.91),("FIRST 1.00",0.1,0.86),
            ("(2)123456 OAT CRACKERS XYZ",0.1,0.80),("2 @ $3.00 6.00",0.3,0.775),
            ("LAST 2.00",0.1,0.70),("UNRESOLVED PRODUCT",0.1,0.64),("TOTAL 9.00",0.1,0.55)])
    }
    func testSourceOrderAndScopedDiagnostics() throws {
        let observations=try fixture(), parsed=ReceiptParser.parse(observations)
        XCTAssertEqual(parsed.lines.map(\.description), ["FIRST","123456 OAT CRACKERS XYZ","LAST"])
        let line=parsed.lines[1]
        XCTAssertEqual(line.amount,600); XCTAssertEqual(line.unitPrice,300)
        XCTAssertEqual(line.quantity,try ReceiptDecimal(coefficient:2,scale:0))
        XCTAssertEqual(Set(line.sourceLineIDs),Set([observations[3].id,observations[4].id]))
        XCTAssertFalse(parsed.issues.contains { ["unpriced_source_row","quantity_association_uncertain"].contains($0.code) && !Set($0.sourceLineIDs).isDisjoint(with:line.sourceLineIDs) })
        XCTAssertTrue(parsed.issues.contains { $0.code=="unpriced_source_row" && $0.sourceLineIDs.contains(observations[6].id) })
        XCTAssertTrue(parsed.issues.contains { $0.code=="source_review_required" && Set($0.sourceLineIDs)==Set(observations.map(\.id)) })
    }
    func testNegativeGuardsInProduction() throws {
        let tails=["2 @ $3.00","2 @ $3.00 7.00","2 @ $3.00 6.00-","2 @ $3.00 6.00 1.00","3 @ $2.00 6.00"]
        for tail in tails {
            let input=try rows([("NO FRILLS",0.1,0.95),("(2)123456 OAT CRACKERS XYZ",0.1,0.80),(tail,0.3,0.775)])
            XCTAssertTrue(ReceiptParser.parse(input).lines.isEmpty)
        }
        for scenario in 0..<5 {
            var entries=[(scenario==0 ? "UNKNOWN MARKET" : "NO FRILLS",0.1,0.95),
                         (scenario==1 ? "123456 OAT CRACKERS XYZ" : "(2)123456 OAT CRACKERS XYZ",0.1,0.80)]
            if scenario==2 { entries.append(("OTHER PRODUCT",0.1,0.79)) }
            entries.append(("2 @ $3.00 6.00",0.3,scenario==3 ? 0.65 : 0.775))
            var input=try rows(entries)
            if scenario==4 { input=input.map { .init(id:$0.id,text:$0.text,engineConfidence:nil) } }
            XCTAssertTrue(ReceiptParser.parse(input).lines.isEmpty)
        }
    }
    func testDraftSaveReopenAndReviewGatePreserveOriginal() async throws {
        let observations=try fixture()
        let extraction=try ReceiptParser.extraction(OCRResult(lines:observations,revision:3))
        var draft=ReceiptReviewDraft(parsed:ReceiptParser.parse(observations))
        draft.date="2026-10-07";draft.subtotalNotPrinted=true
        XCTAssertTrue(draft.canSaveDraft);XCTAssertFalse(draft.canFinalize)
        draft.sourceOpened=true;XCTAssertFalse(draft.canFinalize)
        draft.sourceChecked=true;XCTAssertTrue(draft.canFinalize)
        draft.sourceChecked=false
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("P704-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try ReceiptStore(directory:directory,keyProvider:Key())
        let record=try await store.create(extraction:extraction,originalImage:SyntheticFixture.imageData(),mediaType:"image/png",correction:draft.fields,reviewInput:JSONEncoder().encode(draft))
        XCTAssertFalse(ReceiptCompletion.isComplete(record))
        try await store.close()
        let reopened=try ReceiptStore(directory:directory,keyProvider:Key())
        let fetched=try await reopened.receipt(id:record.id)
        let restored=try XCTUnwrap(fetched)
        XCTAssertEqual(restored.original,extraction)
        XCTAssertEqual(restored.original.rawOCR,observations)
        XCTAssertEqual(restored.current.fields,draft.fields)
        XCTAssertEqual(try JSONDecoder().decode(ReceiptReviewDraft.self,from:XCTUnwrap(restored.current.reviewInput)),draft)
        XCTAssertFalse(ReceiptCompletion.isComplete(restored));try await reopened.close()
    }
}
