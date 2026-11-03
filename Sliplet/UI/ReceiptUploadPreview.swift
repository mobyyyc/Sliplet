import SwiftUI

/// One import session; only an explicit confirmed action can send the flattened payload.
struct ReceiptUploadPreview: View {
    @Bindable var workspace: ReceiptWorkspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var useAI = false
    @State private var drawing = false
    @State private var crop: [CGRect] = [CGRect(x: 0, y: 0, width: 1, height: 1)]
    @State private var cropSelection: Int? = 0
    @State private var redactions: [CGRect] = []
    @State private var coverUndo: [[CGRect]] = []
    @State private var selection: Int?
    @State private var photo: UIImage?
    @State private var prepared: ReceiptImage?
    @State private var preparedPhoto: UIImage?
    @State private var upload: ReceiptUploadImage?
    @State private var preview: UIImage?
    @State private var acknowledged = false
    @State private var preparing = false
    @State private var failure: String?
    @State private var settings = false
    @State private var expandedPreview = false
    private var forward: Bool { workspace.importForward }
    @State private var task: Task<Void, Never>?
    @State private var generation = UUID()
    @State private var initialized = false
    private var step: Int { workspace.importStep }
    private var titles: [String] { ["Adjust photo", "Choose reading method", "Hide sensitive details", "Confirm upload"] }

    var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch step {
                        case 0: photoStep(height: max(160, geometry.size.height - 145))
                        case 1: methodStep
                        case 2: privacyStep(height: max(140, geometry.size.height - 190))
                        default: confirmationStep
                        }
                        if let failure { Label(failure, systemImage: "exclamationmark.circle").font(.callout) }
                        if let message = workspace.errorMessage { Text(message).font(.callout) }
                    }.padding(.horizontal, 20).padding(.bottom, 20)
                }
                .id(step)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }.clipped()
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if preparing { ProgressView("Preparing photo").font(.caption) }
                Button(action: next) {
                    Text(actionTitle).frame(maxWidth: .infinity)
                }.buttonStyle(ReceiptProminentStyle())
                    .disabled(preparing || !canContinue)
                    .accessibilityIdentifier(actionID)
            }.modifier(ReceiptActionBarLayout())
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.3), value: step)
        .onChange(of: step) { old, new in
            acknowledged = false; drawing = false; failure = nil
            if new < old { cancelPreparation() }
        }
        .onChange(of: redactions) { _, _ in acknowledged = false; upload = nil; preview = nil }
        .onChange(of: workspace.aiConnection.preferences.credentialID) { _, _ in acknowledged = false }
        .onChange(of: workspace.aiConnection.canUseAI) { _, _ in acknowledged = false }
        .onChange(of: workspace.privacyCovered) { _, covered in
            if covered { acknowledged = false; cancelPreparation() }
        }
        .task {
            guard !initialized else { return }; initialized = true
            crop = [workspace.importAdjustment.crop]
            if let covers = workspace.retryCovers {
                useAI = true; redactions = covers.drawn
                // Retain covers from an interrupted older session, without offering percentage tools.
                if covers.top { redactions.append(CGRect(x: 0, y: 0, width: 1, height: 0.15)) }
                if covers.bottom { redactions.append(CGRect(x: 0, y: 0.85, width: 1, height: 0.15)) }
            }
            loadPhoto()
        }
        .onDisappear { acknowledged = false; cancelPreparation() }
        .sheet(isPresented: $settings) {
            NavigationStack {
                ReceiptAISettingsView(connection: workspace.aiConnection, privacyCovered: workspace.privacyCovered)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { settings = false } } }
            }
        }
        .sheet(isPresented: $expandedPreview) {
            NavigationStack {
                if let preview, !workspace.privacyCovered {
                    ReceiptImportCanvas(image: preview, regions: .constant([]), selected: .constant(nil))
                        .padding().navigationTitle("Image to upload").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { expandedPreview = false } } }
                }
            }
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0..<(useAI ? 4 : 2), id: \.self) { index in
                    Capsule().fill(index <= step ? Color.primary : Color.primary.opacity(0.12)).frame(height: 4)
                }
            }.accessibilityElement(children: .ignore).accessibilityLabel("Step \(step + 1): \(titles[step])")
            Text(titles[step]).font(.title2.bold()).accessibilityAddTraits(.isHeader)
        }.padding(20)
    }
    @ViewBuilder private func photoStep(height: CGFloat) -> some View {
        if let photo {
            ReceiptImportCanvas(image: photo, cropMode: true, regions: $crop, selected: $cropSelection)
                .frame(height: height).accessibilityIdentifier("photoAdjustmentCanvas")
        }
        HStack {
            Button("Rotate", systemImage: "rotate.right") {
                workspace.importAdjustment.turns = (workspace.importAdjustment.turns + 1) % 4
                crop = [CGRect(x: 0, y: 0, width: 1, height: 1)]; workspace.importAdjustment.crop = crop[0]
                redactions = []; coverUndo = []; loadPhoto()
            }.accessibilityIdentifier("rotateImportPhoto")
            Spacer()
            Button("Reset", systemImage: "arrow.counterclockwise") {
                workspace.importAdjustment = ReceiptPhotoAdjustment(); crop = [workspace.importAdjustment.crop]
                redactions = []; coverUndo = []; loadPhoto()
            }.accessibilityIdentifier("resetImportPhoto")
        }.buttonStyle(ReceiptSecondaryStyle()).disabled(preparing)
        DisclosureGroup("Photo tips") {
            Text("Drag the corners to crop around the receipt. Pinch to zoom. Keep the merchant, items and totals visible. Your original is kept unchanged.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
    private var methodStep: some View {
        VStack(spacing: 14) {
            methodCard("On-device", subtitle: "Offline · stays on your iPhone", icon: "iphone", ai: false)
                .accessibilityIdentifier("readLocal")
            methodCard("AI reading", subtitle: "Gemini · uploads your prepared image", icon: "sparkles", ai: true)
                .accessibilityIdentifier("previewAI")
            HStack {
                Label(workspace.aiConnection.canUseAI ? "AI connected" : "AI setup needed",
                      systemImage: workspace.aiConnection.canUseAI ? "checkmark.circle" : "key")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button(workspace.aiConnection.canUseAI ? "Manage" : "Connect") { settings = true }
            }.padding(.horizontal, 4)
            DisclosureGroup("About reading methods") {
                Text("On-device reading uses Apple Vision without uploading. AI reading uses your connected provider and API allowance. You can hide details and check the upload before anything is sent.")
                    .font(.callout).foregroundStyle(.secondary)
            }.padding(.top, 10)
        }
    }
    private func methodCard(_ title: String, subtitle: String, icon: String, ai: Bool) -> some View {
        Button { useAI = ai } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).frame(width: 30)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: useAI == ai ? "checkmark.circle.fill" : "circle").font(.title3)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.primary.opacity(useAI == ai ? 0.6 : 0.08), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain).accessibilityAddTraits(useAI == ai ? .isSelected : [])
    }
    @ViewBuilder private func privacyStep(height: CGFloat) -> some View {
        if let preparedPhoto {
            ReceiptImportCanvas(image: preparedPhoto, drawing: drawing, onEditBegan: rememberCovers, regions: $redactions, selected: $selection)
                .frame(height: height)
        }
        Group {
            if typeSize.isAccessibilitySize {
                HStack { coverTools }.labelStyle(.iconOnly)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack { coverTools }
                    VStack(spacing: 12) { coverTools }
                }
            }
        }.buttonStyle(ReceiptSecondaryStyle())
        DisclosureGroup("Privacy tips") {
            Text("Cover membership numbers, payment details or personal information. Keep names, quantities, weights and prices visible. Pinch to zoom; drag a cover or its corners to adjust it. Covers are optional and do not guarantee anonymity.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var coverTools: some View {
        Button(drawing ? "Done drawing" : "Add cover", systemImage: drawing ? "checkmark" : "rectangle.dashed") {
            drawing.toggle(); selection = nil
        }.accessibilityIdentifier("drawCovers")
        Button("Undo", systemImage: "arrow.uturn.backward") {
            if let previous = coverUndo.popLast() { redactions = previous }; selection = nil
        }.disabled(coverUndo.isEmpty)
        Button("Delete", systemImage: "trash") {
            if let selection, redactions.indices.contains(selection) { rememberCovers(); redactions.remove(at: selection) }
            selection = nil
        }.disabled(selection == nil).accessibilityLabel("Delete selected cover")
    }
    private var confirmationStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let preview {
                Button { expandedPreview = true } label: {
                    HStack(spacing: 16) {
                        Image(uiImage: preview).resizable().scaledToFit().frame(width: 64, height: 92)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Final image").font(.headline)
                            Text("Tap to inspect").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(); Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }.padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain).accessibilityIdentifier("finalUploadPreview")
            }
            Label("Google · Gemini", systemImage: "sparkles").font(.headline)
            Text("Uses your API key and allowance. Free-tier uploads may be used to improve Google’s products and reviewed by people.")
                .font(.callout)
            DisclosureGroup("Privacy details") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Only the prepared image and reading instructions are sent. Photo metadata and other receipts are not sent. Your original stays on this device. Hiding details does not guarantee anonymity; avoid sending sensitive information.")
                    Text("Model: \(workspace.aiConnection.preferences.model.title)")
                    Link("Google API data-use terms", destination: URL(string: "https://ai.google.dev/gemini-api/terms")!)
                }.font(.callout).foregroundStyle(.secondary)
            }
            Toggle(isOn: $acknowledged) { Text("Allow this image to be sent to Google").fixedSize(horizontal: false, vertical: true) }
                .tint(.green).accessibilityIdentifier("uploadConsent")
            Text("Nothing is sent until you tap Upload and read.").font(.footnote).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Edit hidden areas") { go(2) }.buttonStyle(ReceiptSecondaryStyle())
                Spacer()
            }
        }
    }
    private var actionTitle: String {
        switch step { case 0: "Continue"; case 1: useAI ? "Continue" : "Read receipt"; case 2: "Review upload"; default: "Upload and read" }
    }
    private var actionID: String {
        switch step { case 0: "adjustPhotoContinue"; case 1: "readingMethodContinue"; case 2: "reviewUpload"; default: "sendReceiptAI" }
    }
    private var canContinue: Bool {
        switch step { case 0: photo != nil; case 1: !useAI || workspace.aiConnection.canUseAI; case 2: prepared != nil; default: acknowledged && upload != nil && workspace.aiConnection.canUseAI }
    }
    private func rememberCovers() {
        coverUndo.append(redactions)
        if coverUndo.count > 30 { coverUndo.removeFirst() }
    }
    private func go(_ target: Int) { workspace.importForward = target > step; workspace.importStep = target }
    private func cancelPreparation() { task?.cancel(); task = nil; generation = UUID(); preparing = false }
    private func loadPhoto() {
        guard let original = workspace.image else { return }
        cancelPreparation(); preparing = true
        let adjustment = ReceiptPhotoAdjustment(turns: workspace.importAdjustment.turns)
        let token = generation
        task = Task {
            do {
                let work = Task.detached(priority: .userInitiated) {
                    let result = try adjustment.prepare(original)
                    return (result, try ReceiptPhotoAdjustment.displayImage(result))
                }
                let result = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
                guard !Task.isCancelled, generation == token, !workspace.privacyCovered else { return }
                photo = result.1; preparing = false
                if step == 2 { prepareImage(next: 2) }
            } catch { if !Task.isCancelled && generation == token { preparing = false; failure = "Couldn’t prepare this photo. Try resetting it." } }
        }
    }
    private func prepareImage(next target: Int) {
        guard let original = workspace.image else { return }
        cancelPreparation(); preparing = true
        let adjustment = workspace.importAdjustment, token = generation
        task = Task {
            do {
                let work = Task.detached(priority: .userInitiated) {
                    let result = try adjustment.prepare(original)
                    return (result, try ReceiptPhotoAdjustment.displayImage(result))
                }
                let result = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
                guard !Task.isCancelled, generation == token, !workspace.privacyCovered else { return }
                prepared = result.0; preparedPhoto = result.1; preparing = false; go(target)
            } catch { if !Task.isCancelled && generation == token { preparing = false; failure = "Couldn’t prepare this photo. Try resetting it." } }
        }
    }
    private func next() {
        switch step {
        case 0:
            let value = crop.first ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            if value != workspace.importAdjustment.crop { redactions = []; coverUndo = []; workspace.importAdjustment.crop = value }
            prepareImage(next: 1)
        case 1:
            if useAI { go(2) } else { workspace.readImage() }
        case 2:
            guard let prepared else { return }; cancelPreparation(); preparing = true
            let covers = redactions, token = generation
            task = Task {
                do {
                    let work = Task.detached(priority: .userInitiated) { try ReceiptUploadImage.prepare(prepared, redactions: covers) }
                    let result = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
                    guard !Task.isCancelled, generation == token, !workspace.privacyCovered else { return }
                    upload = result; preview = UIImage(data: result.bytes); preparing = false; go(3)
                } catch { if !Task.isCancelled && generation == token { preparing = false; failure = "Couldn’t prepare the upload. Try again." } }
            }
        default:
            guard acknowledged, let upload, !preparing else { return }
            workspace.sendToAI(upload, covers: .init(drawn: redactions))
        }
    }
}
