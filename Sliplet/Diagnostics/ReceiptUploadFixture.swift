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
        // Hold a fictional request open so the reading UI and cancellation can be inspected.
        if ProcessInfo.processInfo.arguments.contains("--import-loading-fixture") { return }
        if ProcessInfo.processInfo.arguments.contains("--p904-offline") {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--p901-failed-read") {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        var row = Dictionary(uniqueKeysWithValues: ReceiptModelAdapter.rowKeys.map { ($0, NSNull() as Any) })
        row["kind"] = "purchase"; row["description"] = "FICTIONAL APPLES"; row["amount"] = "1.00"
        row["raw_text"] = "FICTIONAL APPLES 1.00"
        var candidate = Dictionary(uniqueKeysWithValues: ReceiptModelAdapter.rootKeys.map { ($0, NSNull() as Any) })
        candidate["merchant"] = "FICTIONAL PREVIEW"; candidate["rows"] = [row]; candidate["total"] = "1.00"
        let longRead = ProcessInfo.processInfo.arguments.contains("--p902-long-read")
        let linkedDiscounts = ProcessInfo.processInfo.arguments.contains("--linked-discounts-fixture")
        if longRead || linkedDiscounts || ProcessInfo.processInfo.arguments.contains("--p901-clean-read") {
            candidate["date_raw"] = "2026-10-24"
            candidate["date"] = "2026-10-24"
            candidate["currency_raw"] = "CAD"
            candidate["currency"] = "CAD"
            candidate["subtotal"] = "1.00"
            if longRead {
                candidate["rows"] = (1...36).map { index in
                    var item = row
                    item["description"] = "FICTIONAL ITEM " + String(index)
                    item["raw_text"] = "FICTIONAL ITEM " + String(index) + " 1.00"
                    return item
                }
                candidate["subtotal"] = "36.00"; candidate["total"] = "36.00"
            }
        }
        if linkedDiscounts {
            func discount(_ label: String, _ amount: String, scope: String?) -> [String: Any] {
                var result = row
                result["kind"] = "discount"
                result["description"] = label
                result["amount"] = amount
                result["raw_text"] = label + " " + amount
                result["discount_scope"] = scope ?? NSNull() as Any
                return result
            }
            candidate["rows"] = [row, discount("Item coupon", "-0.20", scope: "1"),
                                 discount("Basket coupon", "-0.10", scope: "subtotal"),
                                 discount("Unclear coupon", "-0.05", scope: nil)]
            candidate["subtotal"] = "1.00"
            candidate["total"] = "0.65"
            candidate["currency"] = "CAD"
            candidate["currency_raw"] = "CAD"
        }
        let text = String(decoding: try! JSONSerialization.data(withJSONObject: candidate), as: UTF8.self)
        let data = try! JSONSerialization.data(withJSONObject: ["candidates": [["finishReason": "STOP", "content": ["parts": [["text": text]]]]]])
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
#endif
