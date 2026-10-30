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
        let upload = ProcessInfo.processInfo.arguments.contains("--p805-upload-fixture") && SyntheticNativePreview.enabled
        guard upload || ProcessInfo.processInfo.arguments.contains("--p804-ai-settings-fixture") else { return nil }
        let suite = "com.sliplet.p804.ui-fixture"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let keys = Keys()
        if upload {
            let credential = ReceiptAICredential(id: UUID(), key: "FICTIONAL_UI_TEST_KEY_NOT_REAL")
            try? keys.save(credential)
            let preferences = ReceiptAIConnection.Preferences(credentialID: credential.id, checkedAt: Date(), privacyVersion: ReceiptAIConnection.privacyVersion, enabled: true)
            defaults.set(try? JSONEncoder().encode(preferences), forKey: "ai.gemini.connection.v1")
        }
        return ReceiptAIConnection(keys: keys, tester: Test(), defaults: defaults)
    }
}
#endif
