import SwiftUI
import CryptoKit

/// This sheet returns an edit event to the focused editor's working copy only.
struct ReceiptRereadView: View {
    @Bindable var workspace: ReceiptWorkspace
    let image: ReceiptImage
    let fields: [ReceiptAssistedField]
    let lineID: UUID?
    let input: ReceiptReviewDraft
    let use: (ReceiptAssistedReading) -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var region: ReceiptOCRBox
    @State private var field: ReceiptAssistedField
    @State private var drawing = false
    @State private var zoomTarget = UUID()
    @State private var observations: [ReceiptOCRLine] = []
    @State private var revision = 0
    @State private var chosen: String?
    @State private var busy = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var job: ReceiptRegionReadingJob?
    @State private var generation = UUID()
    private let session: UUID
    private let assetSHA256: Data

    init(workspace: ReceiptWorkspace, image: ReceiptImage, boxes: [ReceiptOCRBox], fields: [ReceiptAssistedField], lineID: UUID?, input: ReceiptReviewDraft, use: @escaping (ReceiptAssistedReading) -> Bool) {
        self.workspace = workspace; self.image = image; self.fields = fields; self.lineID = lineID; self.input = input; self.use = use
        session = workspace.sessionID; assetSHA256 = Data(SHA256.hash(data: image.bytes))
        _field = State(initialValue: fields.first ?? .merchant)
        let union = boxes.reduce(CGRect.null) { $0.union(CGRect(x: $1.x, y: $1.y, width: $1.width, height: $1.height)) }
        let padded = union.isNull ? CGRect(x: 0.02, y: 0.4, width: 0.96, height: 0.2) : union.insetBy(dx: -0.025, dy: -0.015).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        _region = State(initialValue: (try? ReceiptOCRBox(x: padded.minX, y: padded.minY, width: padded.width, height: padded.height)) ?? (try! ReceiptOCRBox(x: 0.02, y: 0.4, width: 0.96, height: 0.2)))
    }
    private var choices: [ReceiptAssistedChoice] {
        ReceiptAssistedReading.choices(lines: observations, field: field, currency: ExactInput.currency(input.currency))
    }
    private var current: String { input.assistedValue(field: field, lineID: lineID) ?? "" }
    private var available: Bool { workspace.active && !workspace.privacyCovered && workspace.sessionID == session && workspace.image?.bytes == image.bytes }
    var body: some View {
        NavigationStack {
            if available {
                Form {
                    Section {
                        ZoomReceiptImage(bytes: image.bytes, boxes: [region], reduceMotion: reduceMotion, zoomTarget: zoomTarget, rasterID: "rereadRaster", selection: drawing ? $region : nil)
                            .frame(height: 300).accessibilityIdentifier("rereadImage")
                        HStack {
                            ReceiptSourceZoomControls(target: zoomTarget, prefix: "reread")
                            Spacer()
                            Button(drawing ? "Done selecting" : "Select area") { drawing.toggle() }
                                .buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("rereadSelectArea")
                        }
                        Text(drawing ? "Drag a rectangle around the text. Use two fingers to scroll or pinch to zoom." : "The outlined area will be read. Select a smaller area for difficult text.")
                            .font(.footnote).foregroundStyle(.secondary)
                        DisclosureGroup("Adjust area precisely") {
                            areaSlider("Left", key: \.x)
                            areaSlider("Bottom", key: \.y)
                            areaSlider("Width", key: \.width)
                            areaSlider("Height", key: \.height)
                        }.accessibilityIdentifier("rereadAreaAdjustments")
                        Button { read() } label: {
                            HStack { if busy { ProgressView() }; Label(busy ? "Reading…" : "Read selected area", systemImage: "text.viewfinder") }
                        }.buttonStyle(ReceiptProminentStyle()).disabled(busy).accessibilityIdentifier("rereadRun")
                    } header: { Text("Original comparison") }
                    Section {
                        Picker("Field to update", selection: $field) {
                            ForEach(fields, id: \.self) { Text($0.title).tag($0) }
                        }.accessibilityIdentifier("rereadField")
                        LabeledContent("Current value", value: current.isEmpty ? "Missing" : current)
                        if observations.isEmpty && !busy { Text("Read an area to see possible values. Nothing changes automatically.").font(.footnote) }
                        ForEach(choices) { choice in
                            Button { chosen = choice.id } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(choice.value).foregroundStyle(.primary)
                                        Text("Read: “" + choice.literal + "”").font(.caption).foregroundStyle(.secondary)
                                        if let source = observations.first(where: { $0.id == choice.observationID }) {
                                            Text(source.text).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: chosen == choice.id ? "checkmark.circle.fill" : "circle")
                                        .symbolRenderingMode(.monochrome).foregroundStyle(.primary)
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("rereadChoice-\(choice.id)")
                                .accessibilityAddTraits(chosen == choice.id ? .isSelected : [])
                        }
                        if !observations.isEmpty && choices.isEmpty {
                            Text("No unambiguous value for this field. Adjust the area or cancel and type the value from the photo.").font(.footnote)
                        }
                        if !observations.isEmpty {
                            DisclosureGroup("All text from this area") {
                                ForEach(observations) { Text($0.text).textSelection(.enabled) }
                            }
                        }
                        if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.secondary) }
                    } header: { Text("Choose a reading") }
                    footer: { Text("Check the photo before using a value. The focused editor still needs Apply; this does not mark the whole receipt reviewed.") }
                }.scrollDismissesKeyboard(.interactively).scrollEdgeEffectStyle(.soft, for: .vertical)
                    .navigationTitle("Reread area").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { stop(); dismiss() }.accessibilityIdentifier("rereadCancel") }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Use reading") { accept() }.disabled(busy || chosen == nil).accessibilityIdentifier("rereadUse")
                        }
                    }
            } else { ContentUnavailableView("Receipt locked", systemImage: "lock") }
        }.tint(.primary).accessibilityIdentifier("rereadScreen")
            .onChange(of: region) { _, _ in stop(); observations = []; chosen = nil; error = nil }
            .onChange(of: field) { _, _ in chosen = nil }
            .onChange(of: workspace.active) { _, active in if !active { stop(); dismiss() } }
            .onChange(of: workspace.privacyCovered) { _, covered in if covered { stop(); dismiss() } }
            .onChange(of: workspace.sessionID) { _, _ in stop(); dismiss() }
            .onDisappear { stop() }
    }
    private func areaSlider(_ title: String, key: KeyPath<ReceiptOCRBox, Double>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption)
            Slider(value: Binding(get: { region[keyPath: key] }, set: { value in
                var x = region.x, y = region.y, width = region.width, height = region.height
                switch key {
                case \.x: x = min(value, 1-width)
                case \.y: y = min(value, 1-height)
                case \.width: width = max(0.02, min(value, 1-x))
                default: height = max(0.01, min(value, 1-y))
                }
                if let box = try? ReceiptOCRBox(x: x, y: y, width: width, height: height) { region = box }
            }), in: 0...1).accessibilityLabel("Selected area " + title.lowercased())
        }
    }
    private func stop() {
        generation = UUID(); job?.cancel(); task?.cancel(); job = nil; task = nil; busy = false
    }
    private func read() {
        stop(); guard available else { return }
        drawing = false; observations = []; chosen = nil; error = nil; busy = true
        let token = generation, region = region, image = image
        let reader = ReceiptRegionReadingJob(); job = reader
        task = Task {
            let work = Task.detached(priority: .userInitiated) { try reader.run(image, region: region) }
            do {
                let result = try await withTaskCancellationHandler { try await work.value } onCancel: { reader.cancel(); work.cancel() }
                guard !Task.isCancelled, token == generation, available else { return }
                guard result.lines.count <= 128 else { throw ImportFailure.recognitionFailed }
                observations = result.lines; revision = result.revision; busy = false; job = nil
                if observations.isEmpty { error = "No text found. Try a larger area or type from the original." }
            } catch {
                guard !Task.isCancelled, token == generation, available else { return }
                busy = false; job = nil; self.error = "Couldn’t read this area. Adjust the selection and try again, or enter the value manually."
            }
        }
    }
    private func accept() {
        guard available, !busy, let choice = choices.first(where: { $0.id == chosen }) else { return }
        let event = ReceiptAssistedReading(id: UUID(), date: Date(), assetSHA256: assetSHA256, region: region, revision: revision,
            observations: observations, choice: choice, field: field, lineID: field == .description || field == .amount || field == .quantity ? lineID : nil,
            previousValue: current, currency: ExactInput.currency(input.currency))
        if use(event) { stop(); dismiss() }
        else { error = "The receipt changed or this reading could not be applied. Cancel and reopen the check." }
    }
}
