import XCTest
import CryptoKit
import Vision
@testable import Sliplet

/// Explicit, local-only hosted Simulator lab. No references are supplied to the app.
/// The runner stages originals in this disposable app container; results remain private.
@MainActor final class ReceiptRecognitionLabTests: XCTestCase {
    private struct Key: ReceiptStoreKeyProvider {
        let bytes = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        func loadKey() throws -> Data? { bytes }
        func createKey() throws -> Data { bytes }
    }
    private struct Request: Decodable { let nonce: String; let slots: [Slot] }
    private struct Slot: Decodable { let slot: Int; let image: String; let sha256: String }
    private struct Row: Encodable { let text: String; let ids: [UUID] }
    private struct Response: Encodable {
        let status: String
        let guidanceCounts: [String: Int]
        let nonce: String
        let slot: Int
        let pass: Int
        let readingEvidence: ReceiptReadingEvidence?
        let observations: [ReceiptOCRLine]
        let groupedRowIDs: [[UUID]]
        let interpretedRowIDs: [[UUID]]
        let groupedRows: [Row]
        let interpretedRows: [Row]
        let parsed: ParsedReceipt
        let fields: ReceiptFields
        let draftFields: ReceiptFields
        let draft: ReceiptReviewDraft
        let replayEqual: Bool
        let originalBytesEqual: Bool
        let draftCanSave: Bool
        let draftCanFinalize: Bool
        let storeRoundtripEqual: Bool?
        let reloadedFields: ReceiptFields?
        let reviewInputEqual: Bool?
        let importToReviewMS: Double
        let mainActorPollMaxGapMS: Double
        let parserVersion: String
        let recognitionRevision: String
        let supportedLanguages: [String]
        let pixelWidth: Int
        let pixelHeight: Int
        let orientation: UInt32
    }
    private enum LabFailure: Error { case unavailable, timedOut, invalidInput, captureFailed }
    private func wait(_ predicate: () -> Bool, seconds: Double = 120) async throws -> Double {
        let start = ProcessInfo.processInfo.systemUptime
        var previous = start, gap = 0.0
        while !predicate() {
            if ProcessInfo.processInfo.systemUptime - start > seconds { throw LabFailure.timedOut }
            try await Task.sleep(for: .milliseconds(20))
            let now = ProcessInfo.processInfo.systemUptime
            gap = max(gap, now - previous); previous = now
        }
        return gap * 1000
    }
    func testExplicitPrivateSimulatorBaseline() async throws {
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.environment["SLIPLET_P401_PRIVATE"] == "YES" else {
            throw XCTSkip("Explicit private Simulator lab only")
        }
        guard let nonce = ProcessInfo.processInfo.environment["SLIPLET_P401_NONCE"], UUID(uuidString: nonce) != nil else {
            XCTFail("Private lab requires a valid run identity"); return
        }
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("P401Lab").appendingPathComponent(nonce)
        var activeAttempt: URL?
        do {
            let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: root.appendingPathComponent("request.json")))
            guard request.nonce == ProcessInfo.processInfo.environment["SLIPLET_P401_NONCE"],
                  request.slots.count == 5, Set(request.slots.map(\.slot)).count == 5 else { throw LabFailure.invalidInput }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            for slot in request.slots {
                guard (0..<5).contains(slot.slot), !slot.image.contains("/"), !slot.image.contains("..") else { throw LabFailure.invalidInput }
                let input = root.appendingPathComponent(slot.image)
                let sourceBytes = try Data(contentsOf: input)
                guard SHA256.hash(data: sourceBytes).map({ String(format: "%02x", $0) }).joined() == slot.sha256 else { throw LabFailure.invalidInput }
                for pass in 1...2 {
                    activeAttempt = root.appendingPathComponent("attempt-\(slot.slot)-\(pass).json")
                    try JSONSerialization.data(withJSONObject: ["status": "started"]).write(to: activeAttempt!, options: .atomic)
                    let directory = root.appendingPathComponent("store-\(slot.slot)-\(pass)")
                    guard !FileManager.default.fileExists(atPath: directory.path) else { throw LabFailure.invalidInput }
                    let model = ReceiptWorkspace(directory: directory, keyProvider: Key())
                    model.adaptiveReading = ProcessInfo.processInfo.environment["SLIPLET_P403_ADAPTIVE"] == "YES"
                    defer { model.suspend() }
                    model.activate(protectedDataAvailable: true)
                    _ = try await wait { model.availability == .ready || { if case .failed = model.availability { return true }; return false }() }
                    guard model.availability == .ready else { throw LabFailure.unavailable }
                    let start = ProcessInfo.processInfo.systemUptime
                    model.importFile(input) // Same entry point as the native Files picker.
                    let gap = try await wait { model.flow == .review || model.flow == .failed }
                    let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1000
                    guard model.flow == .review, let extraction = model.extraction, let image = model.image else { throw LabFailure.captureFailed }
                    let parsed = try JSONDecoder().decode(ParsedReceipt.self, from: extraction.rawParserOutput)
                    let replay = ReceiptParser.parse(extraction.rawOCR)
                    // Compare semantic values only; fresh parse creates new line IDs.
                    func semantic(_ value: ParsedReceipt) throws -> Data {
                        var object = try JSONSerialization.jsonObject(with: encoder.encode(value)) as! [String: Any]
                        var lines = object["lines"] as! [[String: Any]]
                        for i in lines.indices { lines[i].removeValue(forKey: "id") }
                        object["lines"] = lines
                        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
                    }
                    let grouped = ReceiptParser.rows(extraction.rawOCR)
                    let interpreted = ReceiptParser.interpretationRows(grouped, knownRetailer: parsed.merchant != nil)
                    let draft = model.draft, fields = draft.fields
                    var roundtrip: Bool?, reviewEqual: Bool?, loaded: ReceiptFields?
                    if draft.canSaveDraft {
                        model.save(asDraft: true)
                        _ = try await wait { (!model.saving && model.flow == .detail) || model.errorMessage != nil }
                        guard let record = model.selected, model.errorMessage == nil else { throw LabFailure.captureFailed }
                        model.suspend(); model.activate(protectedDataAvailable: true)
                        _ = try await wait { model.availability == .ready }
                        guard let reloaded = model.receipts.first(where: { $0.id == record.id }) else { throw LabFailure.captureFailed }
                        model.open(reloaded)
                        _ = try await wait { model.image != nil || model.errorMessage != nil }
                        loaded = reloaded.current.fields
                        roundtrip = loaded == fields && model.image?.bytes == sourceBytes
                            && reloaded.original.rawParserOutput == extraction.rawParserOutput
                            && reloaded.original.rawOCR == extraction.rawOCR && reloaded.original.readingEvidence == extraction.readingEvidence && reloaded.current.review == .draft
                        reviewEqual = model.readerInput == draft
                    }
                    let checks = ReceiptReviewGuidance.checks(draft: draft, extraction: extraction)
                    let actionable = extraction.issues.filter {
                        !["geometry_incomplete", "merchant_missing", "date_missing", "currency_missing", "total_missing", "source_review_required"].contains($0.code)
                    }
                    let guidanceCounts = [
                        "checks": checks.count,
                        "highlighted_checks": checks.filter { !$0.sourceLineIDs.isEmpty }.count,
                        "required_highlighted_checks": checks.filter { $0.requiresCorrection && !$0.sourceLineIDs.isEmpty }.count,
                        "actionable_warnings": actionable.count,
                        "warnings_with_all_sources_guided": actionable.filter { issue in
                            !issue.sourceLineIDs.isEmpty && checks.contains { Set(issue.sourceLineIDs).isSubset(of: Set($0.sourceLineIDs)) }
                        }.count
                    ]
                    let response = Response(status: "ok", guidanceCounts: guidanceCounts, nonce: request.nonce, slot: slot.slot, pass: pass,
                        readingEvidence: extraction.readingEvidence, observations: extraction.rawOCR, groupedRowIDs: grouped.map(\.ids), interpretedRowIDs: interpreted.map(\.ids),
                        groupedRows: grouped.map { Row(text: $0.text, ids: $0.ids) }, interpretedRows: interpreted.map { Row(text: $0.text, ids: $0.ids) },
                        parsed: parsed, fields: extraction.fields, draftFields: fields, draft: draft,
                        replayEqual: try semantic(parsed) == semantic(replay), originalBytesEqual: image.bytes == sourceBytes,
                        draftCanSave: draft.canSaveDraft, draftCanFinalize: draft.canFinalize,
                        storeRoundtripEqual: roundtrip, reloadedFields: loaded, reviewInputEqual: reviewEqual,
                        importToReviewMS: elapsed, mainActorPollMaxGapMS: gap, parserVersion: extraction.parserVersion,
                        recognitionRevision: extraction.recognizerVersion, supportedLanguages: try VNRecognizeTextRequest().supportedRecognitionLanguages(),
                        pixelWidth: image.pixelWidth, pixelHeight: image.pixelHeight, orientation: image.orientation.rawValue)
                    try encoder.encode(response).write(to: root.appendingPathComponent("capture-\(slot.slot)-\(pass).json"), options: .atomic)
                    guard response.originalBytesEqual, response.replayEqual, !response.draftCanFinalize,
                          roundtrip != false, reviewEqual != false else { throw LabFailure.captureFailed }
                    try JSONSerialization.data(withJSONObject: ["status": "ok"]).write(to: activeAttempt!, options: .atomic)
                    activeAttempt = nil
                    model.suspend()
                }
            }
        } catch {
            if let activeAttempt {
                let status: String
                switch error { case LabFailure.timedOut: status = "timed_out"; default: status = "failed" }
                try? JSONSerialization.data(withJSONObject: ["status": status]).write(to: activeAttempt, options: .atomic)
            }
            // Never stringify a private error, object, image or extracted value in XCTest logs.
            XCTFail("Private recognition lab did not complete; inspect local captured status only.")
        }
        #else
        throw XCTSkip("The private recognition lab is Simulator-only")
        #endif
    }
}
