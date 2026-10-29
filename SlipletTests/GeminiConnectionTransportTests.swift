import XCTest
@testable import Sliplet

/// Intercepts only this test session. No live endpoints or real keys are contacted.
private final class FictionalGeminiProtocol: URLProtocol, @unchecked Sendable {
    final class State: @unchecked Sendable {
        let lock = NSLock()
        var status = 200
        var bytes = Data()
        var error: URLError?
        var calls = 0
    }
    static let state = State()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let values = Self.state.lock.withLock { () -> (Int, Data, URLError?) in
            Self.state.calls += 1; return (Self.state.status, Self.state.bytes, Self.state.error)
        }
        if let error = values.2 { client?.urlProtocol(self, didFailWithError: error); return }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: values.0, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: values.1); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
@MainActor final class GeminiConnectionTransportTests: XCTestCase {
    func run(status: Int = 200, bytes: Data = Data(), error: URLError? = nil) async throws {
        FictionalGeminiProtocol.state.lock.withLock {
            FictionalGeminiProtocol.state.status = status; FictionalGeminiProtocol.state.bytes = bytes
            FictionalGeminiProtocol.state.error = error; FictionalGeminiProtocol.state.calls = 0
        }
        let tester = GeminiConnectionTest(makeSession: {
            let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [FictionalGeminiProtocol.self]
            return URLSession(configuration: config)
        })
        try await tester.verify(key: "FICTIONAL_TRANSPORT_KEY", model: .flash)
    }
    func testTransportMapsStatusWithoutRetry() async throws {
        for (status, expected) in [(401, ReceiptAIError.invalidKey), (403, .accessDenied), (404, .modelUnavailable), (429, .rateOrQuotaLimit), (503, .serviceUnavailable)] {
            do { try await run(status: status); XCTFail("Expected failure") }
            catch { XCTAssertEqual(error as? ReceiptAIError, expected) }
            XCTAssertEqual(FictionalGeminiProtocol.state.lock.withLock { FictionalGeminiProtocol.state.calls }, 1)
        }
    }
    func testTransportRejectsOversizedResponse() async throws {
        do { try await run(bytes: Data(repeating: 65, count: 65_537)); XCTFail("Expected bound") }
        catch { XCTAssertEqual(error as? ReceiptAIError, .invalidResponse) }
    }
    func testTransportMapsOfflineAndTimeout() async throws {
        for (code, expected) in [(URLError.Code.notConnectedToInternet, ReceiptAIError.offline), (.timedOut, .timedOut)] {
            do { try await run(error: URLError(code)); XCTFail("Expected failure") }
            catch { XCTAssertEqual(error as? ReceiptAIError, expected) }
        }
    }
    func testTransportAcceptsOnlyValidImageReading() async throws {
        let text = "{\"merchant\":\"SLIPLET TEST\",\"total\":\"1.00\",\"items\":[{\"description\":\"TEST APPLES\",\"amount\":\"1.00\"}]}"
        let bytes = try JSONSerialization.data(withJSONObject: ["candidates": [["finishReason":"STOP","content":["parts":[["text":text]]]]]])
        try await run(bytes: bytes)
    }
    func testRedirectDelegateRejectsDestination() async throws {
        let request = URLRequest(url: URL(string: "https://example.invalid")!)
        let session = URLSession(configuration: .ephemeral); defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: request) // Not resumed.
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<URLRequest?, Never>) in
            ReceiptAIRedirectBlocker().urlSession(session, task: task,
                willPerformHTTPRedirection: HTTPURLResponse(url: request.url!, statusCode: 302, httpVersion: nil, headerFields: nil)!,
                newRequest: request) { continuation.resume(returning: $0) }
        }
        XCTAssertNil(result)
    }
}
