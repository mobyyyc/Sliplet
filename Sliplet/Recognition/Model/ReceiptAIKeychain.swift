import Foundation
import Security

struct ReceiptAICredential: Codable, Sendable {
    let id: UUID
    let key: String
}
protocol ReceiptAIKeyStore: Sendable {
    func load() throws -> ReceiptAICredential?
    func save(_ credential: ReceiptAICredential) throws
    func delete() throws
}
struct ReceiptAIKeychain: ReceiptAIKeyStore {
    var service = "com.sliplet.ai.gemini"
    var account = "personal-api-key-v1"
    private var identity: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false]
    }
    func load() throws -> ReceiptAICredential? {
        var query = identity; query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = try? JSONDecoder().decode(ReceiptAICredential.self, from: data) else { throw ReceiptAIError.secureStorage }
        return value
    }
    func save(_ credential: ReceiptAICredential) throws {
        let data = try JSONEncoder().encode(credential)
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let updated = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if updated == errSecItemNotFound {
            let added = SecItemAdd(identity.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard added == errSecSuccess else { throw ReceiptAIError.secureStorage }
        } else if updated != errSecSuccess { throw ReceiptAIError.secureStorage }
    }
    func delete() throws {
        let status = SecItemDelete(identity as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ReceiptAIError.secureStorage }
    }
}
