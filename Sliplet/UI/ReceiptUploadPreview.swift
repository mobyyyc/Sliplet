import SwiftUI

/// Redaction edits invalidate confirmation. The final preview decodes the very
/// same JPEG bytes captured by Send, not an overlay on the original photograph.
struct ReceiptUploadPreview: View {
    @Bindable var workspace: ReceiptWorkspace
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var ai = false
    @State private var drawing = false
    @State private var redactions: [CGRect] = []
    @State private var drag: CGRect?
    @State private var upload: ReceiptUploadImage?
    @State private var preview: UIImage?
    @State private var confirming = false
    @State private var acknowledged = false
    @State private var preparing = false
    @State private var failure: String?
    @State private var settings = false
    @State private var hideTop = false
    @State private var hideBottom = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !ai {
                    Label("Choose how to read", systemImage: "doc.viewfinder").font(.title2.bold())
                    Text("Your original stays in your wallet. Both options create a draft for you to check.").foregroundStyle(.secondary)
                    Button("Read on device", systemImage: "iphone") { workspace.readImage() }
                        .buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("readLocal")
                    Text("Private, offline reading with Apple Vision. No image is uploaded.").font(.footnote)
                    Divider()
                    Button("Preview for Gemini", systemImage: "sparkles") { ai = true }
                        .buttonStyle(ReceiptSecondaryStyle()).disabled(!workspace.aiConnection.canUseAI)
                        .accessibilityIdentifier("previewAI")
                    Text(workspace.aiConnection.statusText).font(.footnote)
                    Button("AI settings", systemImage: "gearshape") { settings = true }
                        .buttonStyle(ReceiptSecondaryStyle())
                } else {
                    Label(confirming ? "Check the upload" : "Prepare your image", systemImage: confirming ? "checkmark.shield" : "hand.draw")
                        .font(.title2.bold())
                    Text(confirming
                         ? "This is the exact image Google will receive. Your unmodified original stays on this device."
                         : "Tap Draw, then drag across anything to hide it. Tap Scroll to move through the image. Cover membership numbers, payment details or personal information. Keep product names, weights, quantities and prices visible.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let preview {
                        let ratio = CGFloat(preview.cgImage!.height) / CGFloat(preview.cgImage!.width)
                        GeometryReader { geometry in
                            ZStack(alignment: .topLeading) {
                                Image(uiImage: preview).resizable().scaledToFit()
                                if let drag {
                                    Rectangle().fill(.black.opacity(0.7))
                                        .frame(width: drag.width * geometry.size.width, height: drag.height * geometry.size.height)
                                        .offset(x: drag.minX * geometry.size.width, y: drag.minY * geometry.size.height)
                                }
                            }
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 4)
                                .onChanged { value in if !confirming { drag = rectangle(value, size: geometry.size) } }
                                .onEnded { value in
                                    guard !confirming else { return }
                                    let rect = rectangle(value, size: geometry.size); drag = nil
                                    if rect.width > 0.003 && rect.height > 0.003 && redactions.count < 98 {
                                        invalidate(); redactions.append(rect)
                                    }
                                }, including: confirming || !drawing ? .none : .all)
                            .accessibilityLabel("Upload image. Use the cover controls below if drawing is difficult.")
                        }.aspectRatio(1 / ratio, contentMode: .fit)
                            .accessibilityIdentifier("uploadImage")
                    }
                    if preparing { ProgressView("Preparing private preview") }
                    if let failure { Text(failure).foregroundStyle(.secondary) }
                    if !confirming {
                        HStack {
                            Button("Undo", systemImage: "arrow.uturn.backward") { invalidate(); _ = redactions.popLast() }
                                .disabled(redactions.isEmpty)
                            Spacer()
                            Button("Reset") { invalidate(); redactions = []; hideTop = false; hideBottom = false }
                        }.buttonStyle(ReceiptSecondaryStyle())
                        DisclosureGroup("Cover controls") {
                            Text("Optional broad covers. Check they do not hide the merchant or totals.").font(.footnote)
                            Toggle("Cover top 15%", isOn: $hideTop).tint(.green)
                            Toggle("Cover bottom 15%", isOn: $hideBottom).tint(.green)
                        }
                        Text(redactions.count >= 98 ? "Cover limit reached. Undo or reset to change covers." : "\(redactions.count) drawn covers · no automatic redaction").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Google · \(workspace.aiConnection.preferences.model.title)").font(.headline)
                        Text("Uses your API key and allowance. Free-tier submissions can be used to improve Google’s products and reviewed by people. Do not send sensitive or personal information. Redaction does not guarantee anonymity. Only this image and fixed reading instructions are sent; no OCR text, photo metadata or other receipts.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Link("Google API data-use terms", destination: URL(string: "https://ai.google.dev/gemini-api/terms")!)
                        Toggle("Send this image to Google using my allowance", isOn: $acknowledged)
                            .tint(.green).accessibilityIdentifier("uploadConsent")
                        Button("Send to Gemini", systemImage: "arrow.up") {
                            guard acknowledged, let upload, !preparing else { return }
                            workspace.sendToAI(upload)
                        }.buttonStyle(ReceiptProminentStyle())
                            .disabled(!acknowledged || upload == nil || preparing || !workspace.aiConnection.canUseAI)
                            .accessibilityIdentifier("sendReceiptAI")
                        Button("Edit covers") { invalidate() }.buttonStyle(ReceiptSecondaryStyle())
                    }
                    if let message = workspace.errorMessage { Text(message).font(.footnote) }
                    Button("Use on-device reading instead") { workspace.readImage() }.buttonStyle(ReceiptSecondaryStyle())
                    Text("Nothing is sent until you tap Send to Gemini.").font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(20)
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            if ai && !confirming {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    Button(drawing ? "Scroll" : "Draw", systemImage: drawing ? "hand.draw" : "pencil.tip.crop.circle") { drawing.toggle() }
                        .buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("drawCovers")
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    Button("Review upload", systemImage: "eye") { confirming = true; drawing = false; acknowledged = false }
                        .buttonStyle(ReceiptProminentStyle()).disabled(upload == nil || preparing)
                        .accessibilityIdentifier("reviewUpload")
                }.modifier(ReceiptActionBarLayout())
            }
        }
        .sheet(isPresented: $settings) {
            NavigationStack { ReceiptAISettingsView(connection: workspace.aiConnection, privacyCovered: workspace.privacyCovered)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { settings = false } } } }
        }
        .task(id: covers) {
            guard ai, let original = workspace.image else { return }
            invalidate(); preparing = true; failure = nil; upload = nil; preview = nil
            let covers = covers
            let work = Task.detached(priority: .userInitiated) { try ReceiptUploadImage.prepare(original, redactions: covers) }
            do {
                let result = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
                try Task.checkCancellation()
                guard !workspace.privacyCovered else { return }
                upload = result; preview = UIImage(data: result.bytes); preparing = false
            } catch {
                guard !Task.isCancelled else { return }
                preparing = false; failure = "The preview could not be prepared. Try a different image or read on device."
            }
        }
        .onChange(of: ai) { _, _ in hideTop = false; hideBottom = false }
        .onChange(of: workspace.aiConnection.canUseAI) { _, _ in invalidate() }
        .onChange(of: workspace.aiConnection.preferences.credentialID) { _, _ in invalidate() }
        .onChange(of: workspace.privacyCovered) { _, covered in if covered { acknowledged = false; drag = nil } }
        // State is released with this view. Do not erase the prepared image on a
        // temporary presentation: returning from Original must remain usable.
        .onDisappear { acknowledged = false; drag = nil }
    }
    // Include selection state so the first AI preview always triggers preparation.
    private var covers: [CGRect] {
        guard ai else { return [CGRect(x: -1, y: -1, width: 0, height: 0)] }
        return redactions + (hideTop ? [CGRect(x: 0, y: 0, width: 1, height: 0.15)] : [])
            + (hideBottom ? [CGRect(x: 0, y: 0.85, width: 1, height: 0.15)] : [])
    }
    private func invalidate() { confirming = false; acknowledged = false }
    private func rectangle(_ value: DragGesture.Value, size: CGSize) -> CGRect {
        let x0 = min(max(value.startLocation.x / max(size.width, 1), 0), 1)
        let y0 = min(max(value.startLocation.y / max(size.height, 1), 0), 1)
        let x1 = min(max(value.location.x / max(size.width, 1), 0), 1)
        let y1 = min(max(value.location.y / max(size.height, 1), 0), 1)
        return CGRect(x: min(x0, x1), y: min(y0, y1), width: abs(x1 - x0), height: abs(y1 - y0))
    }
}
