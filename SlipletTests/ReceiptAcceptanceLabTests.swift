import XCTest
import CryptoKit
@testable import Sliplet

/// Private development-set evidence probe. It does not choose/apply corrections or mark review.
@MainActor final class ReceiptAcceptanceLabTests: XCTestCase {
    private struct Request: Decodable { let nonce: String; let slots: [Slot] }
    private struct Slot: Decodable { let slot: Int; let image: String; let sha256: String }
    private struct Capture: Decodable { let draft: ReceiptReviewDraft; let observations: [ReceiptOCRLine] }
    private struct Attempt: Encodable {
        let lineID: UUID
        let region: ReceiptOCRBox?
        let status: String
        let milliseconds: Double
        let choices: [ReceiptAssistedChoice]
        let observations: [ReceiptOCRLine]
    }
    func testPrivateSuggestedRegionCandidateCoverage() async throws {
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.environment["SLIPLET_P406_PRIVATE"] == "YES" else { throw XCTSkip("Explicit private acceptance lab only") }
        do {
            guard let nonce = ProcessInfo.processInfo.environment["SLIPLET_P401_NONCE"], UUID(uuidString: nonce) != nil else { throw ReceiptValidationError.invalidEvidence }
            let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("P401Lab").appendingPathComponent(nonce)
            let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: root.appendingPathComponent("request.json")))
            guard request.nonce == nonce, request.slots.count == 5 else { throw ReceiptValidationError.invalidEvidence }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            for slot in request.slots {
                guard (0..<5).contains(slot.slot), !slot.image.contains("/"), !slot.image.contains("..") else { throw ReceiptValidationError.invalidEvidence }
                let bytes = try Data(contentsOf: root.appendingPathComponent(slot.image))
                guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == slot.sha256 else { throw ReceiptValidationError.invalidEvidence }
                let image = try ReceiptImage.decode(bytes)
                let capture = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: root.appendingPathComponent("capture-\(slot.slot)-1.json")))
                var attempts: [Attempt] = []
                // Every existing purchase, without consulting answer labels or amounts.
                // This measures candidate availability, never human-assisted success.
                for line in capture.draft.lines where line.kind == "purchase" {
                    let boxes = capture.observations.filter { line.sourceLineIDs.contains($0.id) }.compactMap(\.boundingBox)
                    let union = boxes.reduce(CGRect.null) { $0.union(CGRect(x: $1.x, y: $1.y, width: $1.width, height: $1.height)) }
                    guard !union.isNull else {
                        attempts.append(Attempt(lineID: line.id, region: nil, status: "no_source_region", milliseconds: 0, choices: [], observations: [])); continue
                    }
                    let r = union.insetBy(dx: -0.025, dy: -0.015).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
                    let region = try ReceiptOCRBox(x: r.minX, y: r.minY, width: r.width, height: r.height)
                    let start = ProcessInfo.processInfo.systemUptime
                    do {
                        let result = try await Task.detached { try ReceiptRegionReadingJob().run(image, region: region) }.value
                        guard result.lines.count <= ReceiptAssistedReading.maximumObservations else { throw ReceiptValidationError.invalidEvidence }
                        attempts.append(Attempt(lineID: line.id, region: region, status: "ok", milliseconds: (ProcessInfo.processInfo.systemUptime-start)*1000,
                            choices: ReceiptAssistedReading.choices(lines: result.lines, field: .amount, currency: ExactInput.currency(capture.draft.currency)), observations: result.lines))
                    } catch {
                        attempts.append(Attempt(lineID: line.id, region: region, status: "unavailable", milliseconds: (ProcessInfo.processInfo.systemUptime-start)*1000, choices: [], observations: []))
                    }
                }
                try encoder.encode(attempts).write(to: root.appendingPathComponent("reread-\(slot.slot).json"), options: .atomic)
            }
        } catch { XCTFail("Private candidate coverage did not complete; inspect local evidence only.") }
        #else
        throw XCTSkip("Simulator only")
        #endif
    }
}
