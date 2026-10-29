import XCTest
import Security
@testable import Sliplet

private final class AIKeys: ReceiptAIKeyStore, @unchecked Sendable {
    let lock = NSLock()
    private var record: ReceiptAICredential?
    var failSave = false
    var failDelete = false
    func load() throws -> ReceiptAICredential? { lock.withLock { record } }
    func save(_ credential: ReceiptAICredential) throws {
        try lock.withLock { if failSave { throw ReceiptAIError.secureStorage }; record = credential }
    }
    func delete() throws { try lock.withLock { if failDelete { throw ReceiptAIError.secureStorage }; record = nil } }
}
private struct AITester: ReceiptAIConnectionTesting {
    let body: @Sendable (String) async throws -> Void
    func verify(key: String, model: ReceiptAIModel) async throws { try await body(key) }
}
@MainActor final class ReceiptAIConnectionTests: XCTestCase {
    let first = "FICTIONAL_KEY_FIRST_NOT_REAL"
    let second = "FICTIONAL_KEY_SECOND_NOT_REAL"
    func defaults() -> UserDefaults {
        let suite = "P804-\(UUID())"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return UserDefaults(suiteName: suite)!
    }
    func wait(_ condition: @escaping @MainActor () -> Bool) async throws {
        for _ in 0..<200 { if condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
        XCTFail("Connection did not finish")
    }
    func connect(_ model: ReceiptAIConnection, key: String) async throws {
        model.verify(replacement: key); try await wait { !model.checking }
    }
    func testVerificationConsentAndEnableAreSeparateAndSurviveRestart() async throws {
        let keys = AIKeys(), defaults = defaults(), tester = AITester { _ in }
        let c = ReceiptAIConnection(keys: keys, tester: tester, defaults: defaults)
        XCTAssertEqual(c.status, .disconnected)
        try await connect(c, key: first)
        XCTAssertEqual(c.status, .verified); XCTAssertFalse(c.enabled); XCTAssertFalse(c.privacyConfirmed)
        c.setEnabled(true); XCTAssertFalse(c.enabled)
        c.setPrivacyConfirmed(true); c.setEnabled(true); XCTAssertTrue(c.enabled)
        let reopened = ReceiptAIConnection(keys: keys, tester: tester, defaults: defaults)
        XCTAssertTrue(reopened.enabled); XCTAssertNotNil(reopened.preferences.checkedAt)
        let values = defaults.dictionaryRepresentation()
        XCTAssertFalse(String(describing: values).contains(first))
        c.setEnabled(false); XCTAssertNotNil(try keys.load()); XCTAssertFalse(c.enabled)
    }
    func testFailedReplacementPreservesWorkingKeyAndConsent() async throws {
        let cKeys = AIKeys(), d = defaults()
        let c = ReceiptAIConnection(keys: cKeys, tester: AITester { if $0.contains("SECOND") { throw ReceiptAIError.invalidKey } }, defaults: d)
        try await connect(c, key: first); c.setPrivacyConfirmed(true); c.setEnabled(true)
        let id = try cKeys.load()?.id
        try await connect(c, key: second)
        XCTAssertEqual(c.status, .verified); XCTAssertEqual(c.replacementError, .invalidKey)
        XCTAssertEqual(try cKeys.load()?.id, id); XCTAssertTrue(c.enabled)
    }
    func testSuccessfulReplacementRequiresNewPrivacyConfirmation() async throws {
        let c = ReceiptAIConnection(keys: AIKeys(), tester: AITester { _ in }, defaults: defaults())
        try await connect(c, key: first); c.setPrivacyConfirmed(true); c.setEnabled(true)
        try await connect(c, key: second)
        XCTAssertFalse(c.privacyConfirmed); XCTAssertFalse(c.enabled); XCTAssertEqual(c.status, .verified)
    }
    func testRevokedKeyFailureRemainsFailureAfterRestart() async throws {
        let keys = AIKeys(), d = defaults()
        let first = ReceiptAIConnection(keys: keys, tester: AITester { _ in }, defaults: d)
        try await connect(first, key: self.first); first.setPrivacyConfirmed(true); first.setEnabled(true)
        let failing = ReceiptAIConnection(keys: keys, tester: AITester { _ in throw ReceiptAIError.invalidKey }, defaults: d)
        failing.verify(); try await wait { !failing.checking }
        let reopened = ReceiptAIConnection(keys: keys, tester: AITester { _ in }, defaults: d)
        XCTAssertEqual(reopened.status, .failed(.invalidKey)); XCTAssertFalse(reopened.enabled)
        XCTAssertNotNil(reopened.preferences.checkedAt) // Historical success is not current validity.
    }
    func testDisconnectCancelsAndRejectsLateSuccess() async throws {
        let keys = AIKeys()
        let delayed = ReceiptAIConnection(keys: keys, tester: AITester { _ in try? await Task.sleep(for: .milliseconds(150)) }, defaults: defaults())
        delayed.verify(replacement: first); delayed.disconnect()
        try await Task.sleep(for: .milliseconds(220))
        XCTAssertNil(try keys.load()); XCTAssertEqual(delayed.status, .disconnected)
    }
    func testCancelDoesNotStoreCandidateOrClearExistingKey() async throws {
        let keys = AIKeys(), d = defaults(), c = ReceiptAIConnection(keys: keys, tester: AITester { _ in }, defaults: d)
        try await connect(c, key: first)
        let slow = ReceiptAIConnection(keys: keys, tester: AITester { _ in try? await Task.sleep(for: .milliseconds(150)) }, defaults: d)
        slow.verify(replacement: second); slow.cancel()
        try await Task.sleep(for: .milliseconds(220)); XCTAssertEqual(try keys.load()?.key, first)
    }
    func testKeychainWriteAndDeletionFailureAreNotSuccessfulStates() async throws {
        let keys = AIKeys(), c = ReceiptAIConnection(keys: keys, tester: AITester { _ in }, defaults: defaults())
        keys.failSave = true; try await connect(c, key: first)
        XCTAssertEqual(c.status, .failed(.secureStorage)); XCTAssertFalse(c.hasKey)
        keys.failSave = false; try await connect(c, key: first); c.setPrivacyConfirmed(true); c.setEnabled(true)
        keys.failDelete = true; c.disconnect()
        XCTAssertEqual(c.status, .failed(.secureStorage)); XCTAssertFalse(c.enabled); XCTAssertNotNil(try keys.load())
    }
    func testCredentialIdentityMismatchDoesNotReuseRestoredConsent() async throws {
        let keys = AIKeys(), d = defaults(), c = ReceiptAIConnection(keys: keys, tester: AITester { _ in }, defaults: d)
        try await connect(c, key: first); c.setPrivacyConfirmed(true); c.setEnabled(true)
        try keys.save(.init(id: UUID(), key: second))
        let reopened = ReceiptAIConnection(keys: keys, tester: AITester { _ in }, defaults: d)
        XCTAssertEqual(reopened.status, .unverified); XCTAssertFalse(reopened.privacyConfirmed); XCTAssertFalse(reopened.enabled)
    }
    func testAllServiceFailuresAreSafeAndDisableAI() async throws {
        for error in [ReceiptAIError.offline, .timedOut, .modelUnavailable, .rateOrQuotaLimit, .billingRequired, .accessDenied, .serviceUnavailable, .invalidResponse] {
            let c = ReceiptAIConnection(keys: AIKeys(), tester: AITester { _ in throw error }, defaults: defaults())
            try await connect(c, key: first); XCTAssertEqual(c.status, .failed(error)); XCTAssertFalse(c.enabled)
            XCTAssertFalse(c.statusText.contains(first))
        }
    }
    func testSpontaneousCancellationEndsChecking() async throws {
        let c = ReceiptAIConnection(keys: AIKeys(), tester: AITester { _ in throw CancellationError() }, defaults: defaults())
        try await connect(c, key: first)
        XCTAssertFalse(c.checking); XCTAssertFalse(c.hasKey)
    }
    func testDisableCancelsVerificationButPreservesCredential() async throws {
        let keys = AIKeys(), d = defaults()
        let c = ReceiptAIConnection(keys: keys, tester: AITester { _ in }, defaults: d)
        try await connect(c, key: first); c.setPrivacyConfirmed(true); c.setEnabled(true)
        let slow = ReceiptAIConnection(keys: keys, tester: AITester { _ in try? await Task.sleep(for: .milliseconds(150)) }, defaults: d)
        slow.verify(); XCTAssertTrue(slow.enabled); XCTAssertFalse(slow.canUseAI)
        slow.setEnabled(false)
        try await Task.sleep(for: .milliseconds(220))
        XCTAssertFalse(slow.enabled); XCTAssertNotNil(try keys.load())
    }
    func testErrorMappingNeverShowsProviderMessageOrInventsBalance() throws {
        let data = try JSONSerialization.data(withJSONObject: ["error": ["message": first, "details": [["reason": "API_KEY_INVALID"]]]])
        XCTAssertEqual(GeminiConnectionTest.error(status: 400, data: data), .invalidKey)
        for (code, expected) in [(403, ReceiptAIError.accessDenied), (404, .modelUnavailable), (429, .rateOrQuotaLimit), (402, .billingRequired), (503, .serviceUnavailable), (504, .timedOut)] {
            XCTAssertEqual(GeminiConnectionTest.error(status: code, data: Data()), expected)
        }
    }
    func testRequestUsesOnlyFixedProviderHeaderAndFictionalImage() async throws {
        let bytes = try GeminiConnectionTest.fictionalImage()
        let request = try GeminiConnectionTest.request(key: first, model: .flash, image: bytes)
        XCTAssertEqual(request.url?.host, "generativelanguage.googleapis.com"); XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), first)
        XCTAssertFalse(String(decoding: request.httpBody!, as: UTF8.self).contains(first))
        let object = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertNil(object["tools"]); XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertLessThan(request.httpBody!.count, 300_000)
    }
    func testImageCapabilityRequiresCorrectFictionalContent() throws {
        func response(_ total: String) throws -> Data {
            let text = "{\"merchant\":\"SLIPLET TEST\",\"total\":\"\(total)\",\"items\":[{\"description\":\"TEST APPLES\",\"amount\":\"1.00\"}]}"
            return try JSONSerialization.data(withJSONObject: ["candidates": [["finishReason":"STOP","content":["parts":[["text":text]]]]]])
        }
        XCTAssertNoThrow(try GeminiConnectionTest.validate(response("1.00")))
        XCTAssertThrowsError(try GeminiConnectionTest.validate(response("9.00")))
        XCTAssertThrowsError(try GeminiConnectionTest.validate(Data("{}".utf8)))
    }
    func testKeychainIsDeviceOnlyNonSynchronizingAndDeletionWorks() throws {
        let account = UUID().uuidString, service = "com.sliplet.ai.unit-tests"
        let keys = ReceiptAIKeychain(service: service, account: account)
        defer { try? keys.delete() }
        try keys.save(.init(id: UUID(), key: first))
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account,kSecReturnAttributes as String:true]
        var result: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        let attrs = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(attrs[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertFalse(attrs[kSecAttrSynchronizable as String] as? Bool ?? false)
        try keys.delete(); XCTAssertNil(try keys.load())
    }
}
