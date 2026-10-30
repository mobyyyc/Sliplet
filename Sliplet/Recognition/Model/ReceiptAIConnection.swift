import Foundation
import Observation

enum ReceiptAIModel: String, Codable, CaseIterable, Identifiable, Sendable {
    case flash = "gemini-3.6-flash"
    var id: String { rawValue }
    var title: String { "Gemini 3.6 Flash" }
}
enum ReceiptAIError: String, Error, Codable, Sendable, Equatable {
    case invalidKey, accessDenied, modelUnavailable, rateOrQuotaLimit, billingRequired, offline, serviceUnavailable, timedOut, invalidResponse, secureStorage
    var message: String {
        switch self {
        case .invalidKey: "The key was rejected. Check or replace it in Google AI Studio."
        case .accessDenied: "This project cannot access the model. Check permissions and availability in Google AI Studio."
        case .modelUnavailable: "This model is unavailable for your account. Local recognition still works."
        case .rateOrQuotaLimit: "A rate or allowance limit was reached. Check Google AI Studio before trying again."
        case .billingRequired: "The provider requires billing or an account change. Sliplet has not enabled billing."
        case .offline: "No connection. Check your internet access and try again."
        case .serviceUnavailable: "Google could not complete the request. Try again later."
        case .timedOut: "The connection test timed out. You can try again."
        case .invalidResponse: "The model did not pass the fictional image check. It has not been verified."
        case .secureStorage: "Secure key storage is unavailable. Unlock your device and try again."
        }
    }
}
protocol ReceiptAIConnectionTesting: Sendable {
    func verify(key: String, model: ReceiptAIModel) async throws
}

/// Preferences contain only nonsecret metadata. A random credential ID binds checks
/// and consent to the exact Keychain record, including across app reinstalls/restores.
@MainActor @Observable final class ReceiptAIConnection {
    struct Preferences: Codable {
        var credentialID: UUID?
        var model: ReceiptAIModel = .flash
        var checkedAt: Date?
        var lastFailure: ReceiptAIError?
        var privacyVersion: Int?
        var enabled = false
    }
    enum Status: Equatable { case disconnected, unverified, checking, verified, failed(ReceiptAIError) }
    static let privacyVersion = 1
    private(set) var status: Status = .disconnected
    private(set) var hasKey = false
    private(set) var preferences = Preferences()
    private(set) var replacementError: ReceiptAIError?
    private(set) var message: String?
    @ObservationIgnored private let keys: any ReceiptAIKeyStore
    @ObservationIgnored private let tester: any ReceiptAIConnectionTesting
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var job: Task<Void, Never>?
    @ObservationIgnored private var operation = UUID()
    private let preferencesKey = "ai.gemini.connection.v1"
    var checking: Bool { status == .checking }
    var privacyConfirmed: Bool { preferences.privacyVersion == Self.privacyVersion }
    var enabled: Bool { preferences.enabled && hasKey && privacyConfirmed }
    var canUseAI: Bool { enabled && status == .verified }
    var statusText: String {
        switch status {
        case .disconnected: "Not connected"
        case .unverified: "Not verified"
        case .checking: "Checking fictional image…"
        case .verified: enabled ? "Ready · last check passed" : "Verified · AI disabled"
        case .failed(let error): error.message
        }
    }
    init(keys: any ReceiptAIKeyStore = ReceiptAIKeychain(), tester: any ReceiptAIConnectionTesting = GeminiConnectionTest(), defaults: UserDefaults = .standard) {
        self.keys = keys; self.tester = tester; self.defaults = defaults
        if let data = defaults.data(forKey: preferencesKey), let saved = try? JSONDecoder().decode(Preferences.self, from: data) { preferences = saved }
        reload()
    }
    private func persist() { if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: preferencesKey) } }
    func reload() {
        guard !checking else { return }
        do {
            guard let credential = try keys.load() else {
                hasKey = false; preferences = Preferences(); persist(); status = .disconnected; return
            }
            hasKey = true
            if preferences.credentialID != credential.id { preferences = Preferences(); persist() }
            // Last success is historical; do not infer present provider availability.
            status = preferences.lastFailure.map(Status.failed) ?? (preferences.checkedAt == nil ? .unverified : .verified)
        } catch { status = .failed(.secureStorage); preferences.enabled = false; persist() }
    }
    /// Re-read Keychain at explicit send time, never cache a developer or old key.
    func uploadCredential() throws -> ReceiptAICredential {
        guard canUseAI, let credential = try keys.load(), credential.id == preferences.credentialID else {
            throw ReceiptAIError.secureStorage
        }
        return credential
    }
    func recordUploadFailure(_ error: ReceiptAIError, credentialID: UUID) {
        guard preferences.credentialID == credentialID else { return }
        if [.invalidKey, .accessDenied, .modelUnavailable, .billingRequired].contains(error) {
            preferences.lastFailure = error; preferences.enabled = false; status = .failed(error); persist()
        }
    }
    func setPrivacyConfirmed(_ value: Bool) {
        preferences.privacyVersion = value ? Self.privacyVersion : nil
        if !value { setEnabled(false) }
        persist()
    }
    func setEnabled(_ value: Bool) {
        if !value { cancel(); preferences.enabled = false; persist(); return }
        guard hasKey, status == .verified, preferences.checkedAt != nil, privacyConfirmed else { return }
        preferences.enabled = true; persist()
    }
    func changeModel(_ model: ReceiptAIModel) {
        guard model != preferences.model else { return }
        cancel(); preferences.model = model; preferences.checkedAt = nil; preferences.enabled = false
        status = hasKey ? .unverified : .disconnected; persist()
    }
    func cancel() {
        operation = UUID(); job?.cancel(); job = nil
        if checking { status = preferences.lastFailure.map(Status.failed) ?? (hasKey && preferences.checkedAt != nil ? .verified : (hasKey ? .unverified : .disconnected)) }
    }
    func disconnect() {
        cancel(); replacementError = nil; message = nil
        preferences.enabled = false; preferences.checkedAt = nil; preferences.privacyVersion = nil; persist()
        do { try keys.delete(); hasKey = false; preferences = Preferences(); persist(); status = .disconnected; message = "Key removed from this device. Revoke it separately in Google AI Studio if needed." }
        catch { status = .failed(.secureStorage) }
    }
    /// Candidate replacements remain only in memory until verification succeeds.
    func verify(replacement: String? = nil) {
        guard !checking else { return }
        let credential: ReceiptAICredential
        do {
            if let replacement {
                let key = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
                guard (16...512).contains(key.utf8.count), key.utf8.allSatisfy({ (33...126).contains($0) }) else { replacementError = .invalidKey; return }
                credential = .init(id: UUID(), key: key)
            } else {
                guard let stored = try keys.load() else { status = .disconnected; hasKey = false; return }
                credential = stored
            }
        } catch { status = .failed(.secureStorage); return }
        let replacing = replacement != nil, previousStatus = status
        cancel(); let token = operation, model = preferences.model
        status = .checking; replacementError = nil; message = nil
        let tester = tester
        job = Task { [weak self] in
            do {
                try await tester.verify(key: credential.key, model: model)
                try Task.checkCancellation()
                guard let self, self.operation == token, self.preferences.model == model else { return }
                if replacing { try self.keys.save(credential) }
                if replacing || self.preferences.credentialID != credential.id {
                    self.preferences.privacyVersion = nil; self.preferences.enabled = false
                }
                self.preferences.credentialID = credential.id; self.preferences.checkedAt = Date(); self.preferences.lastFailure = nil
                self.hasKey = true; self.status = .verified; self.persist(); self.job = nil
            } catch is CancellationError {
                guard let self, self.operation == token else { return }
                self.cancel()
            }
            catch {
                guard let self, !Task.isCancelled, self.operation == token else { return }
                let safe = error as? ReceiptAIError ?? .serviceUnavailable
                if replacing && self.hasKey {
                    self.status = previousStatus; self.replacementError = safe
                    self.message = "The replacement was not saved. Your existing connection is unchanged."
                } else {
                    self.status = .failed(safe); self.preferences.lastFailure = safe; self.preferences.enabled = false; self.persist()
                }
                self.job = nil
            }
        }
    }
}
