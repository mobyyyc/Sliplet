import SwiftUI

struct ReceiptAISettingsView: View {
    @Bindable var connection: ReceiptAIConnection
    let privacyCovered: Bool
    @State private var key = ""
    @State private var replacing = false
    @State private var choosingModel = false
    @State private var confirmDisconnect = false
    @State private var testAcknowledged = false
    @FocusState private var keyFocused: Bool
    var body: some View {
        Form {
            if privacyCovered {
                ContentUnavailableView("Unlock to continue", systemImage: "lock")
            } else {
                Section {
                    Label(connection.statusText, systemImage: connection.checking ? "hourglass" : (connection.status == .verified ? "checkmark.circle" : "network"))
                        .accessibilityIdentifier("aiConnectionStatus")
                    LabeledContent("Provider", value: "Google Gemini")
                    Button {
                        choosingModel = true
                    } label: {
                        LabeledContent("Model") {
                            Label(connection.preferences.model.title, systemImage: "chevron.up.chevron.down")
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .accessibilityValue(connection.preferences.model.title)
                    .accessibilityIdentifier("aiModelName")
                    .disabled(connection.checking || replacing)
                    if let date = connection.preferences.checkedAt {
                        LabeledContent("Last successful check") { Text(date, format: .dateTime.month().day().hour().minute()) }
                    }
                } header: { Text("Connection") } footer: {
                    Text("Changing models requires a new connection test. You can reuse your saved API key.")
                }
                if !connection.hasKey || replacing {
                    Section {
                        SecureField("Gemini API key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($keyFocused).submitLabel(.done).onSubmit { keyFocused = false }.privacySensitive().accessibilityIdentifier("geminiAPIKey")
                        Link("Create or manage a key", destination: URL(string: "https://aistudio.google.com/apikey")!)
                        if replacing { Button("Cancel replacement") { clearEntry(); replacing = false } }
                    } header: { Text(replacing ? "Replace key" : "Connect your account") } footer: {
                        Text("Your key stays in this device’s Keychain and is excluded from Sliplet backups. A replacement is saved only after it passes the check.")
                    }
                }
                if connection.hasKey {
                    Section {
                        Toggle("I have reviewed Google’s data-use terms", isOn: Binding(get: { connection.privacyConfirmed }, set: { connection.setPrivacyConfirmed($0) }))
                            .tint(.green).accessibilityIdentifier("aiPrivacyConfirmation")
                        Toggle("Enable AI recognition", isOn: Binding(get: { connection.enabled }, set: { connection.setEnabled($0) }))
                            .tint(.green)
                            .disabled(!connection.enabled && (!connection.privacyConfirmed || connection.status != .verified))
                            .accessibilityIdentifier("enableAIRecognition")
                        if !connection.privacyConfirmed {
                            Text("Review the data-use terms before enabling AI.").font(.footnote).foregroundStyle(.secondary)
                        } else if connection.status != .verified {
                            Text("Test the connection before enabling AI.").font(.footnote).foregroundStyle(.secondary)
                        }
                    } header: { Text("AI recognition") } footer: {
                        Text("Google’s free-tier terms may allow submitted content to improve its products. Connection verification does not establish private processing or zero retention. Each import offers on-device reading or an image preview. Nothing is uploaded until you explicitly approve that image.")
                    }
                }
                if connection.hasKey && !replacing && !connection.checking {
                    Section {
                        DisclosureGroup("Test connection") { connectionTest }
                    }
                } else { Section("Connection test") { connectionTest } }
                if connection.hasKey {
                    Section {
                        Button("Replace key") { replacing = true; key = "" }.disabled(connection.checking || replacing)
                        Button("Disconnect", role: .destructive) { confirmDisconnect = true }.accessibilityIdentifier("disconnectAI")
                    } footer: { Text("Disabling keeps the key. Disconnect removes it from this device and cancels the check; revoke the key in Google AI Studio to disable it elsewhere.") }
                }
                Section("Google AI Studio") {
                    Link("Usage and limits", destination: URL(string: "https://aistudio.google.com/usage")!)
                    Link("Pricing and data use", destination: URL(string: "https://ai.google.dev/gemini-api/docs/pricing")!)
                    Link("API terms", destination: URL(string: "https://ai.google.dev/gemini-api/terms")!)
                }
            }
        }
        .labeledContentStyle(ReceiptAdaptiveLabeledContentStyle())
        .navigationTitle("AI recognition").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Disconnect Gemini?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Remove key from this device", role: .destructive) { clearEntry(); connection.disconnect(); replacing = false }
        }
        .confirmationDialog("Choose a Gemini model", isPresented: $choosingModel, titleVisibility: .visible) {
            ForEach(ReceiptAIModel.allCases) { model in
                Button(model.title) { connection.changeModel(model) }
            }
        }
        .onAppear { connection.reload() }
        .onDisappear { clearEntry(); connection.cancel() }
        .onChange(of: privacyCovered) { _, covered in if covered { clearEntry(); connection.cancel() } }
        .onChange(of: connection.status) { _, status in if status == .verified { replacing = false } }
    }
    private var connectionTest: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("I understand this test uses my API allowance", isOn: $testAcknowledged)
                .tint(.green).accessibilityIdentifier("aiTestAcknowledgement")
            if connection.checking {
                HStack { ProgressView(); Text("Reading a fictional test image") }
                Button("Cancel check") { connection.cancel(); clearEntry() }
            } else {
                Button(connection.hasKey && !replacing ? "Test connection" : "Verify and save key") {
                    let candidate = (!connection.hasKey || replacing) ? key : nil
                    clearEntry(); connection.verify(replacement: candidate)
                }.buttonStyle(ReceiptProminentStyle())
                    .disabled(!testAcknowledged || ((!connection.hasKey || replacing) && key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .accessibilityIdentifier("verifyAIConnection")
            }
            if let error = connection.replacementError { Text(error.message).foregroundStyle(.secondary) }
            if let message = connection.message { Text(message).foregroundStyle(.secondary) }
            Text("Sends one generated test image to Google, never your receipts. No automatic retries. Check your project’s billing and limits first; Sliplet cannot verify your free-tier balance or guarantee a request is free.").font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func clearEntry() { key = ""; keyFocused = false }
}
