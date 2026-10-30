import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Sliplet

private final class UploadProtocol: URLProtocol, @unchecked Sendable {
    final class State: @unchecked Sendable {
        let lock = NSLock()
        var status = 200
        var bytes = Data()
        var calls = 0
        var delay = false
    }
    static let state = State()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, bytes, delay) = Self.state.lock.withLock {
            Self.state.calls += 1; return (Self.state.status, Self.state.bytes, Self.state.delay)
        }
        if delay { return } // Cancellation test: no callback until stopped.
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: bytes); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
private final class UploadKeys: ReceiptAIKeyStore, @unchecked Sendable {
    let lock = NSLock()
    var record: ReceiptAICredential?
    func load() throws -> ReceiptAICredential? { lock.withLock { record } }
    func save(_ credential: ReceiptAICredential) throws { lock.withLock { record = credential } }
    func delete() throws { lock.withLock { record = nil } }
}
private struct UploadTester: ReceiptAIConnectionTesting {
    func verify(key: String, model: ReceiptAIModel) async throws { }
}
@MainActor final class ReceiptUploadTests: XCTestCase {
    func image(width: Int = 400, height: Int = 800, orientation: Int = 1) throws -> ReceiptImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let picture = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let bytes = NSMutableData()
        let dest = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, picture.cgImage!, [kCGImagePropertyOrientation: orientation,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 43.1],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "PRIVATE_TEST_METADATA"]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return try ReceiptImage.decode(bytes as Data)
    }
    func wait(_ predicate: @escaping @MainActor () -> Bool) async throws {
        for _ in 0..<300 { if predicate() { return }; try await Task.sleep(for: .milliseconds(20)) }
        XCTFail("Upload did not reach expected state")
    }
    func reset(status: Int = 200, bytes: Data = Data(), delay: Bool = false) {
        UploadProtocol.state.lock.withLock { UploadProtocol.state.status = status; UploadProtocol.state.bytes = bytes; UploadProtocol.state.calls = 0; UploadProtocol.state.delay = delay }
    }
    var calls: Int { UploadProtocol.state.lock.withLock { UploadProtocol.state.calls } }
    var transport: GeminiReceiptTransport { GeminiReceiptTransport(makeSession: {
        let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [UploadProtocol.self]; return URLSession(configuration: c)
    }) }
    func testMetadataRemovedAndOrientationBakedBeforeRedaction() throws {
        let source = try image(orientation: 6)
        let upload = try ReceiptUploadImage.prepare(source, redactions: [])
        XCTAssertEqual(upload.width, 800); XCTAssertEqual(upload.height, 400)
        let decoded = CGImageSourceCreateWithData(upload.bytes as CFData, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(decoded, 0, nil)! as NSDictionary
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
        // The fresh JPEG encoder adds dimensions; none of the source EXIF survives.
        let exif = properties[kCGImagePropertyExifDictionary] as? [String: Any] ?? [:]
        XCTAssertTrue(Set(exif.keys).isSubset(of: ["PixelXDimension", "PixelYDimension"]))
        XCTAssertNotEqual(properties[kCGImagePropertyOrientation] as? Int, 6)
        XCTAssertFalse(String(decoding: upload.bytes, as: UTF8.self).contains("PRIVATE_TEST_METADATA"))
        XCTAssertEqual(source.orientation.rawValue, 6)
    }
    func testCoversAreFlattenedPixelsAndUndoRebuildsOriginal() throws {
        let source = try image()
        let covered = try ReceiptUploadImage.prepare(source, redactions: [CGRect(x: 0, y: 0, width: 1, height: 0.5)])
        let clear = try ReceiptUploadImage.prepare(source, redactions: [])
        func pixel(_ bytes: Data, y: Int) -> UInt8 {
            let image = UIImage(data: bytes)!.cgImage!
            var values = [UInt8](repeating: 0, count: image.width * image.height * 4)
            values.withUnsafeMutableBytes { buffer in
                let c = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return values[(y * image.width + image.width / 2) * 4]
        }
        XCTAssertLessThan(pixel(covered.bytes, y: 100), 10)
        XCTAssertGreaterThan(pixel(covered.bytes, y: 700), 240)
        XCTAssertGreaterThan(pixel(clear.bytes, y: 100), 240)
        XCTAssertNotEqual(covered.bytes, source.bytes)
    }
    func testLongImageRetainsEntireAspectRatioAndRejectsBadCovers() throws {
        let source = try image(width: 400, height: 4000)
        let upload = try ReceiptUploadImage.prepare(source, redactions: [])
        XCTAssertEqual(upload.height, 1600); XCTAssertEqual(upload.width, 160)
        XCTAssertThrowsError(try ReceiptUploadImage.prepare(source, redactions: [CGRect(x: 0, y: 0, width: -1, height: 1)]))
    }
    func testRequestUsesExactPreviewNoSourceMetadataOrOCR() throws {
        let upload = try ReceiptUploadImage.prepare(image(), redactions: [CGRect(x: 0, y: 0, width: 1, height: 0.2)])
        let request = try GeminiReceiptTransport.request(upload: upload, key: "FICTIONAL_KEY", model: .flash)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "FICTIONAL_KEY")
        XCTAssertFalse(request.url!.absoluteString.contains("FICTIONAL_KEY"))
        let object = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let parts = ((object["contents"] as! [[String: Any]])[0]["parts"] as! [[String: Any]])
        XCTAssertEqual(parts.count, 2)
        let inline = parts[0]["inlineData"] as! [String: String]
        XCTAssertEqual(Data(base64Encoded: inline["data"]!), upload.bytes)
        XCTAssertEqual(parts[1]["text"] as? String, GeminiReceiptTransport.prompt + "\nFollow this JSON schema:\n" + GeminiReceiptTransport.schema)
        XCTAssertFalse(String(decoding: request.httpBody!, as: UTF8.self).contains("FICTIONAL_KEY"))
    }
    func testTransportBoundsErrorsAndNoRetry() async throws {
        let upload = try ReceiptUploadImage.prepare(image(), redactions: [])
        for (status, bytes, expected) in [(429, Data(), ReceiptAIError.rateOrQuotaLimit), (503, Data(), .serviceUnavailable), (200, Data(repeating: 65, count: 262_145), .invalidResponse)] {
            reset(status: status, bytes: bytes)
            do { _ = try await transport.read(upload: upload, key: "FICTIONAL_KEY", model: .flash); XCTFail("Expected failure") }
            catch { XCTAssertEqual(error as? ReceiptAIError, expected) }
            XCTAssertEqual(calls, 1)
        }
    }
    func workspace() async throws -> ReceiptWorkspace {
        let keys = UploadKeys(), suite = "P805-\(UUID())", directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: suite)!
        let connection = ReceiptAIConnection(keys: keys, tester: UploadTester(), defaults: defaults)
        connection.verify(replacement: "FICTIONAL_UPLOAD_KEY_NOT_REAL")
        try await wait { !connection.checking }
        connection.setPrivacyConfirmed(true); connection.setEnabled(true)
        let w = ReceiptWorkspace(directory: directory, keyProvider: ReceiptModelTests.Key(), aiConnection: connection, aiTransport: transport)
        w.activate(protectedDataAvailable: true); try await wait { w.availability == .ready }
        addTeardownBlock { @MainActor in w.suspend(); defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        return w
    }
    func testChoiceDoesNotSendAndExplicitUploadSavesOriginalWithReviewGates() async throws {
        reset(bytes: try ReceiptModelTests().envelope())
        let w = try await workspace(), original = try image()
        w.startImport(chooseRecognition: true) { original.bytes }
        try await wait { w.flow == .preparingUpload }; XCTAssertEqual(calls, 0)
        let upload = try ReceiptUploadImage.prepare(original, redactions: [CGRect(x: 0, y: 0, width: 1, height: 0.2)])
        w.sendToAI(upload); try await wait { w.flow == .review }
        XCTAssertEqual(calls, 1); XCTAssertEqual(w.image?.bytes, original.bytes)
        XCTAssertFalse(w.draft.sourceChecked); XCTAssertFalse(w.draft.canFinalize)
        XCTAssertEqual(w.draft.currencyOrigin, .defaultCAD); XCTAssertNil(w.extraction?.fields.currency)
        w.save(asDraft: true); try await wait { w.flow == .detail && !w.saving }
        w.open(try XCTUnwrap(w.selected)); try await wait { w.image != nil }
        XCTAssertEqual(w.image?.bytes, original.bytes)
    }
    func testCancelAfterSendPreservesOriginalAndLocalRecovery() async throws {
        reset(delay: true)
        let w = try await workspace(), source = try image()
        w.startImport(chooseRecognition: true) { source.bytes }; try await wait { w.flow == .preparingUpload }
        w.sendToAI(try ReceiptUploadImage.prepare(source, redactions: [])); try await wait { self.calls == 1 }
        w.stopAIReading(); XCTAssertEqual(w.flow, .failed); XCTAssertEqual(w.image?.bytes, source.bytes)
        XCTAssertTrue(w.errorMessage!.contains("cannot recall")); w.manualReview()
        try await Task.sleep(for: .milliseconds(100)); XCTAssertEqual(w.flow, .review); XCTAssertEqual(calls, 1)
    }
    func testDisabledConnectionAndBackgroundCannotUpload() async throws {
        reset()
        let w = try await workspace(), source = try image(), upload = try ReceiptUploadImage.prepare(source, redactions: [])
        w.startImport(chooseRecognition: true) { source.bytes }; try await wait { w.flow == .preparingUpload }
        w.aiConnection.setEnabled(false); w.sendToAI(upload); XCTAssertEqual(calls, 0); XCTAssertEqual(w.flow, .preparingUpload)
        w.suspend(); w.sendToAI(upload); XCTAssertEqual(calls, 0); XCTAssertNil(w.image)
    }
}
