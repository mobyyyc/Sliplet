#if DEBUG
import Foundation

/// Explicit UI test only. No network, persistent credentials, or production preferences.
@MainActor enum ReceiptAISettingsFixture {
    private final class Keys: ReceiptAIKeyStore, @unchecked Sendable {
        private let lock = NSLock()
        private var value: ReceiptAICredential?
        func load() throws -> ReceiptAICredential? { lock.withLock { value } }
        func save(_ credential: ReceiptAICredential) throws { lock.withLock { value = credential } }
        func delete() throws { lock.withLock { value = nil } }
    }
    private struct Test: ReceiptAIConnectionTesting {
        func verify(key: String, model: ReceiptAIModel) async throws {
            try await Task.sleep(for: .milliseconds(150))
            guard key == "FICTIONAL_UI_TEST_KEY_NOT_REAL" else { throw ReceiptAIError.invalidKey }
        }
    }
    static func requested() -> ReceiptAIConnection? {
        guard ProcessInfo.processInfo.arguments.contains("--p804-ai-settings-fixture") else { return nil }
        let suite = "com.sliplet.p804.ui-fixture"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ReceiptAIConnection(keys: Keys(), tester: Test(), defaults: defaults)
    }
}
#endif
