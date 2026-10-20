import XCTest
import CryptoKit
@testable import Sliplet

@MainActor final class ReceiptItemBoundaryProofTests: XCTestCase {
    private struct Key: ReceiptStoreKeyProvider {
        let bytes = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        func loadKey() throws -> Data? { bytes }
        func createKey() throws -> Data { bytes }
    }
    private struct Request: Decodable { let nonce: String; let slots: [Slot] }
    private struct Slot: Decodable { let slot: Int; let image: String; let sha256: String }
    private struct Capture: Encodable {
        let observations: [ReceiptOCRLine]; let parsed: ParsedReceipt; let draftFields: ReceiptFields
    }
    private struct Pair: Encodable { let baseline: Capture; let candidate: Capture }
    private enum Failure: Error { case invalid, timeout }
    private func wait(_ predicate: () -> Bool) async throws {
        let start = ProcessInfo.processInfo.systemUptime
        while !predicate() {
            guard ProcessInfo.processInfo.systemUptime - start < 120 else { throw Failure.timeout }
            try await Task.sleep(for: .milliseconds(25))
        }
    }
    func testFictionalBoundaryGuards() throws {
        func observations(head: String = "(2)123456 OAT CRACKERS XYZ", tail: String = "2 @ $3.00 6.00", gap: Double = 0.025, merchant: String = "NO FRILLS", geometry: Bool = true, intervening: Bool = false) -> [ReceiptOCRLine] {
            var rows: [(String, Double, Double)] = [(merchant,0.1,0.95),(head,0.1,0.80)]
            if intervening { rows.append(("OTHER PRODUCT",0.1,0.79)) }
            rows.append((tail,0.3,0.80-gap))
            return rows.map { text,x,y in ReceiptOCRLine(id: UUID(),text: text,engineConfidence: nil,boundingBox: geometry ? try! ReceiptOCRBox(x:x,y:y,width:0.5,height:0.025) : nil) }
        }
        let positive = observations()
        let result = ReceiptItemBoundaryCandidate.candidate(positive)
        let item = try XCTUnwrap(result.lines.first)
        XCTAssertEqual(item.description,"123456 OAT CRACKERS XYZ")
        XCTAssertEqual(item.amount,600); XCTAssertEqual(item.unitPrice,300)
        XCTAssertEqual(Set(item.sourceLineIDs),Set(positive.dropFirst().map(\.id)))
        let negatives = [observations(tail:"2 @ $3.00"),observations(tail:"2 @ $3.00 7.00"),
            observations(tail:"2 @ $3.00 6.00-"),observations(tail:"2 @ $3.00 6.00 1.00"),
            observations(tail:"3 @ $2.00 6.00"),observations(gap:0.15),observations(merchant:"UNKNOWN MARKET"),
            observations(geometry:false),observations(head:"123456 OAT CRACKERS XYZ"),observations(intervening:true)]
        for rows in negatives {
            XCTAssertEqual(ReceiptItemBoundaryCandidate.candidate(rows).lines.count, ReceiptParser.parse(rows).lines.count)
        }
    }
    func testExplicitPrivateImports() async throws {
        #if targetEnvironment(simulator)
        let env = ProcessInfo.processInfo.environment
        guard env["SLIPLET_P703_PRIVATE"] == "YES" else { throw XCTSkip("Explicit private Simulator proof only") }
        guard let nonce=env["SLIPLET_P401_NONCE"], UUID(uuidString:nonce) != nil else { XCTFail("Invalid proof identity"); return }
        let root=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("P401Lab").appendingPathComponent(nonce)
        do {
            let request=try JSONDecoder().decode(Request.self,from:Data(contentsOf:root.appendingPathComponent("request.json")))
            guard request.nonce==nonce, request.slots.count==5, Set(request.slots.map(\.slot))==Set(0..<5) else { throw Failure.invalid }
            for slot in request.slots {
                guard !slot.image.contains("/"),!slot.image.contains("..") else { throw Failure.invalid }
                let input=root.appendingPathComponent(slot.image), bytes=try Data(contentsOf:input)
                guard SHA256.hash(data:bytes).map({String(format:"%02x",$0)}).joined()==slot.sha256 else { throw Failure.invalid }
                for pass in 1...2 {
                    let directory=root.appendingPathComponent("proof-store-\(slot.slot)-\(pass)")
                    guard !FileManager.default.fileExists(atPath:directory.path) else { throw Failure.invalid }
                    let model=ReceiptWorkspace(directory:directory,keyProvider:Key()); defer { model.suspend() }
                    model.adaptiveReading=false
                    model.activate(protectedDataAvailable:true)
                    try await wait { model.availability == .ready }
                    model.importFile(input)
                    try await wait { model.flow == .review || model.flow == .failed }
                    guard model.flow == .review, let extraction=model.extraction else { throw Failure.invalid }
                    let baseline=try JSONDecoder().decode(ParsedReceipt.self,from:extraction.rawParserOutput)
                    let candidate=ReceiptItemBoundaryCandidate.candidate(extraction.rawOCR)
                    var conversion=candidate
                    if conversion.currency == nil { conversion.currency = .cad }
                    let pair=Pair(baseline:Capture(observations:extraction.rawOCR,parsed:baseline,draftFields:model.draft.fields),candidate:Capture(observations:extraction.rawOCR,parsed:candidate,draftFields:conversion.fields()))
                    try JSONEncoder().encode(pair).write(to:root.appendingPathComponent("p703-\(slot.slot)-\(pass).json"),options:.atomic)
                    guard try Data(contentsOf:input)==bytes else { throw Failure.invalid }
                }
            }
        } catch { XCTFail("Private item proof failed; receipt contents suppressed") }
        #else
        throw XCTSkip("Simulator only")
        #endif
    }
}
