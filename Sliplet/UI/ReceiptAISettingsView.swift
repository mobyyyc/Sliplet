import SwiftUI

struct ReceiptAISettingsView: View {
    @Bindable var connection: ReceiptAIConnection
    let privacyCovered: Bool
    @State private var key = ""
    @State private var enteringKey = false
    @State private var reviewingTerms = false
    @State private var confirmDisconnect = false
    @State private var choosingModel = false
    @State private var managing = false
    @FocusState private var keyFocused: Bool

    var body: some View {
        Form {
            if privacyCovered {
                ContentUnavailableView("Unlock to continue", systemImage: "lock")
            } else {
                connectionSection
                if connection.hasKey && !enteringKey && !reviewingTerms && !connection.checking {
                    managementSection
                }
            }
        }
        .labeledContentStyle(ReceiptAdaptiveLabeledContentStyle())
        .navigationTitle("AI recognition")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Disconnect Gemini?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Remove key from this device", role: .destructive) { connection.disconnect(); managing = false }
        } message: {
            Text("To revoke the key for other apps or devices, manage it in Google AI Studio.")
        }
        .confirmationDialog("Choose a Gemini model", isPresented: $choosingModel, titleVisibility: .visible) {
            ForEach(ReceiptAIModel.allCases) { model in
                Button(model.title) {
                    connection.changeModel(model)
                    managing = false
                }
            }
        } message: {
            Text("Changing models keeps your API key. Verify the model before turning AI recognition back on.")
        }
        .onAppear { connection.reload() }
        .onDisappear(perform: resetForm)
        .onChange(of: privacyCovered) { _, covered in if covered { resetForm() } }
        .onChange(of: connection.preferences.credentialID) { _, id in
            if enteringKey && id != nil { closeKeyEntry(); managing = false }
        }
    }

    private var connectionSection: some View {
        Section {
            Label(connection.settingsSummary, systemImage: statusIcon)
                .font(.headline)
                .accessibilityIdentifier("aiConnectionStatus")
            LabeledContent("Model", value: connection.preferences.model.title)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Model")
                .accessibilityValue(connection.preferences.model.title)
                .accessibilityIdentifier("aiCurrentModel")
            if connection.checking {
                ProgressView("Reading a test image")
                Button("Cancel check") { connection.cancel() }
            } else if enteringKey {
                keyEntry
            } else if reviewingTerms {
                terms
            } else {
                nextAction
            }
        } header: {
            Text("Google Gemini")
        } footer: {
            if let message = feedback {
                Text(message).accessibilityIdentifier("aiConnectionFeedback")
            } else if !connection.hasKey && !enteringKey && !connection.checking {
                Text("Use your own Gemini API key to read receipts. On-device reading is always available.")
            } else if connection.canUseAI {
                Text("You approve each receipt image before Sliplet sends it to Google.")
            }
        }
    }

    @ViewBuilder private var nextAction: some View {
        if connection.status == .failed(.secureStorage) {
            Button("Check secure storage", action: connection.reload)
        } else if !connection.hasKey {
            Button("Connect Gemini") { enteringKey = true }
                .accessibilityIdentifier("connectGemini")
        } else if connection.status == .failed(.invalidKey) {
            Button("Replace key") { enteringKey = true }
                .accessibilityIdentifier("replaceGeminiKey")
        } else if connection.status != .verified {
            if connection.status == .failed(.modelUnavailable) || connection.status == .failed(.accessDenied) {
                Button("Choose another model") { choosingModel = true }
                    .accessibilityIdentifier("aiModelName")
            } else {
                Button("Verify model") { connection.verify() }
                    .accessibilityIdentifier("verifyAIConnection")
                Text(testDisclosure).font(.footnote).foregroundStyle(.secondary)
            }
        } else if connection.canUseAI {
            Toggle("AI recognition", isOn: Binding(get: { connection.canUseAI }, set: { connection.setEnabled($0) }))
                .tint(.green)
                .accessibilityIdentifier("enableAIRecognition")
        } else {
            Button("Turn on AI recognition") {
                if connection.privacyConfirmed { connection.setEnabled(true) }
                else { reviewingTerms = true }
            }
            .accessibilityIdentifier("turnOnAIRecognition")
        }
    }

    private var keyEntry: some View {
        Group {
            SecureField("Gemini API key", text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($keyFocused)
                .submitLabel(.done)
                .onSubmit { keyFocused = false }
                .privacySensitive()
                .accessibilityIdentifier("geminiAPIKey")
            Link("Get a Gemini API key", destination: Self.keysURL)
            Text(testDisclosure).font(.footnote).foregroundStyle(.secondary)
            Button("Verify and save key") {
                let candidate = key
                clearKey()
                connection.verify(replacement: candidate)
            }
            .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("verifyAIConnection")
            Button("Cancel") { closeKeyEntry() }
        }
    }

    private var terms: some View {
        Group {
            Text("Google processes the images you approve. Free-tier submissions may be reviewed by people and used to improve Google’s products. Avoid sending personal or sensitive information.")
                .font(.subheadline)
            Link("Google data-use terms", destination: Self.termsURL)
            Button("Agree and turn on") {
                connection.setPrivacyConfirmed(true)
                connection.setEnabled(true)
                reviewingTerms = false
            }
            .accessibilityIdentifier("agreeAndEnableAI")
            Button("Cancel") { reviewingTerms = false }
        }
    }

    private var managementSection: some View {
        Section {
            Button {
                withAnimation { managing.toggle() }
            } label: {
                Label("Manage connection", systemImage: managing ? "chevron.down" : "chevron.right")
            }
            .accessibilityValue(managing ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("manageAIConnection")
            if managing {
                if connection.status != .failed(.modelUnavailable) && connection.status != .failed(.accessDenied) {
                    Button("Change model") { choosingModel = true }
                        .accessibilityIdentifier("aiModelName")
                }
                if let date = connection.preferences.checkedAt {
                    LabeledContent("Last successful check") { Text(date, format: .dateTime.month().day().hour().minute()) }
                }
                if connection.status == .verified {
                    Button("Test connection") { connection.verify() }
                    Text(testDisclosure).font(.footnote).foregroundStyle(.secondary)
                }
                if connection.status != .failed(.invalidKey) {
                    Button("Replace key") { enteringKey = true }
                }
                Link("Usage and limits", destination: URL(string: "https://aistudio.google.com/usage")!)
                Link("Google data-use terms", destination: Self.termsURL)
                Button("Disconnect", role: .destructive) { confirmDisconnect = true }
                    .accessibilityIdentifier("disconnectAI")
            }
        }
    }

    private var feedback: String? {
        if enteringKey, let error = connection.replacementError {
            return connection.hasKey ? error.message + " Your current key is still saved." : error.message
        }
        if case .failed(let error) = connection.status { return error.message }
        return connection.message
    }

    private var testDisclosure: String {
        "Verification sends one fictional test image to Google using your API allowance. Your receipts stay on this device during the test."
    }

    private var statusIcon: String {
        switch connection.status {
        case .disconnected: "link"
        case .unverified: "checkmark.shield"
        case .checking: "hourglass"
        case .verified: connection.canUseAI ? "checkmark.circle" : "pause.circle"
        case .failed: "exclamationmark.circle"
        }
    }

    private static let keysURL = URL(string: "https://aistudio.google.com/apikey")!
    private static let termsURL = URL(string: "https://ai.google.dev/gemini-api/terms")!

    private func clearKey() { key = ""; keyFocused = false }
    private func closeKeyEntry() { clearKey(); enteringKey = false; connection.clearReplacementFeedback() }

    private func resetForm() {
        closeKeyEntry()
        reviewingTerms = false
        confirmDisconnect = false
        choosingModel = false
        connection.cancel()
    }
}
