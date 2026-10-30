#if DEBUG
import Foundation

/// A fictional end-to-end Simulator flow. URLProtocol never contacts a provider.
final class ReceiptUploadFixture: URLProtocol, @unchecked Sendable {
    @MainActor static var enabled: Bool { SyntheticNativePreview.enabled && ProcessInfo.processInfo.arguments.contains("--p805-upload-fixture") }
    static var transport: GeminiReceiptTransport { GeminiReceiptTransport(makeSession: {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ReceiptUploadFixture.self]
        return URLSession(configuration: config)
    }) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var row = Dictionary(uniqueKeysWithValues: ReceiptModelAdapter.rowKeys.map { ($0, NSNull() as Any) })
        row["kind"] = "purchase"; row["description"] = "FICTIONAL APPLES"; row["amount"] = "1.00"
        row["raw_text"] = "FICTIONAL APPLES 1.00"
        var candidate = Dictionary(uniqueKeysWithValues: ReceiptModelAdapter.rootKeys.map { ($0, NSNull() as Any) })
        candidate["merchant"] = "FICTIONAL PREVIEW"; candidate["rows"] = [row]; candidate["total"] = "1.00"
        let text = String(decoding: try! JSONSerialization.data(withJSONObject: candidate), as: UTF8.self)
        let data = try! JSONSerialization.data(withJSONObject: ["candidates": [["finishReason": "STOP", "content": ["parts": [["text": text]]]]]])
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
#endif
