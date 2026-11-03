import SwiftUI

/// One import session; only an explicit confirmed action can send the flattened payload.
struct ReceiptUploadPreview: View {
    @Bindable var workspace: ReceiptWorkspace
    var retake: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var useAI = false
    @State private var drawing = false
    private var cropEditing: Bool {
        get { workspace.importCropping }
        nonmutating set { workspace.importCropping = newValue }
    }
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
    private var titles: [String] { [cropEditing ? "Crop photo" : "Check photo", "Choose reading method", "Hide sensitive details", "Confirm upload"] }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch step {
                    case 0: photoStep(height: geometry.size.height - 24)
                    case 1: methodStep
                    case 2: privacyStep(height: geometry.size.height - 24)
                    default: confirmationStep
                    }
                    if let failure { Label(failure, systemImage: "exclamationmark.circle").font(.callout) }
                    if let message = workspace.errorMessage { Text(message).font(.callout) }
                }.padding(.horizontal, 20).padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollClipDisabled()
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .accessibilityIdentifier("importStepContent")
            .id(step)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
        }
        .safeAreaBar(edge: .top, spacing: 0) { header }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                if step == 0 { photoControls }
                if step == 2 { coverControls }
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
        .onChange(of: cropEditing) { _, editing in
            if !editing { crop = [workspace.importAdjustment.crop] }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(0..<(useAI ? 4 : 2), id: \.self) { index in
                    VStack(spacing: 7) {
                        Capsule().fill(index <= step ? Color.primary : Color.primary.opacity(0.12)).frame(height: 4)
                        if !typeSize.isAccessibilitySize {
                            Text(["Photo", "Method", "Privacy", "Upload"][index])
                                .font(.caption.weight(index == step ? .semibold : .regular))
                                .foregroundStyle(index <= step ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }.accessibilityElement(children: .ignore).accessibilityLabel("Step \(step + 1): \(titles[step])")
            if typeSize.isAccessibilitySize {
                Text(useAI ? "Photo · Method · Privacy · Upload" : "Photo · Method")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Text(titles[step]).font(typeSize.isAccessibilitySize ? .headline : .title2.bold()).accessibilityAddTraits(.isHeader)
        }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 10)
            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: useAI)
    }
    private func photoStep(height: CGFloat) -> some View {
        ReceiptImportPageLayout(availableHeight: height) {
            Group {
                if let photo {
                    if cropEditing {
                        ReceiptImportCanvas(image: photo, cropMode: true, regions: $crop, selected: $cropSelection)
                            .accessibilityIdentifier("photoAdjustmentCanvas")
                    } else {
                        ReceiptImportCanvas(image: preparedPhoto ?? photo, regions: .constant([]), selected: .constant(nil))
                            .accessibilityIdentifier("photoCheckCanvas")
                    }
                } else { ProgressView("Opening photo") }
            }
            guidance("Photo tips", text: cropEditing
                ? "Drag the white corners. Keep the merchant, items and totals inside. Pinch to zoom."
                : "Check that the receipt is sharp, upright and complete. Your original stays unchanged.")
            if workspace.importFromCamera && !cropEditing {
                Button("Retake photo", systemImage: "camera", action: retake)
                    .buttonStyle(ReceiptSecondaryStyle()).frame(maxWidth: .infinity).accessibilityIdentifier("cameraRetake")
            }
        }
    }
    private var photoControls: some View {
        HStack(spacing: 10) {
                tool(cropEditing ? "Cancel" : "Crop", icon: cropEditing ? "xmark" : "crop") {
                    if cropEditing { crop = [workspace.importAdjustment.crop] }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { cropEditing.toggle() }
                }.accessibilityIdentifier("cropImportPhoto").accessibilityLabel(cropEditing ? "Cancel crop" : "Crop")
                tool("Rotate", icon: "rotate.right") {
                    workspace.importAdjustment.turns = (workspace.importAdjustment.turns + 1) % 4
                    crop = [CGRect(x: 0, y: 0, width: 1, height: 1)]; workspace.importAdjustment.crop = crop[0]
                    redactions = []; coverUndo = []; preparedPhoto = nil; loadPhoto()
                }.accessibilityIdentifier("rotateImportPhoto")
                tool("Reset", icon: "arrow.counterclockwise") {
                    workspace.importAdjustment = ReceiptPhotoAdjustment(); crop = [workspace.importAdjustment.crop]
                    redactions = []; coverUndo = []; preparedPhoto = nil; loadPhoto()
                }.accessibilityIdentifier("resetImportPhoto")
            }.disabled(preparing)
    }
    private func tool(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium)).frame(height: 22)
                if !typeSize.isAccessibilitySize { Text(title).font(.caption.weight(.medium)).lineLimit(1) }
            }.frame(maxWidth: .infinity, minHeight: 42)
        }.buttonStyle(ReceiptSecondaryStyle()).accessibilityLabel(title)
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
            guidance("About reading methods", text: "On-device uses Apple Vision offline. AI uses your connected provider and API allowance. You’ll hide sensitive details and check the image before uploading.")
                .padding(.top, 10)
        }
    }
    private func guidance(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
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
    private func privacyStep(height: CGFloat) -> some View {
        ReceiptImportPageLayout(availableHeight: height) {
            Group {
                if let preparedPhoto {
                    ReceiptImportCanvas(image: preparedPhoto, drawing: drawing, onEditBegan: rememberCovers, regions: $redactions, selected: $selection)
                } else { ProgressView("Preparing photo") }
            }
            guidance(drawing ? "Draw to hide" : "Privacy tips", text: drawing
                ? "Drag over sensitive details. Use two fingers to move the photo. Keep items and prices visible."
                : "Cover personal or payment details. Tap a cover to move or resize it. Pinch to zoom.")
        }
    }
    private var coverControls: some View {
        HStack(spacing: 10) {
                tool(drawing ? "Done" : "Cover", icon: drawing ? "checkmark" : "rectangle.dashed") {
                    drawing.toggle(); selection = nil
                }.accessibilityLabel(drawing ? "Done drawing" : "Add cover").accessibilityIdentifier("drawCovers")
                tool("Undo", icon: "arrow.uturn.backward") {
                    if let previous = coverUndo.popLast() { redactions = previous }; selection = nil
                }.disabled(coverUndo.isEmpty)
                tool("Delete", icon: "trash") {
                    if let selection, redactions.indices.contains(selection) { rememberCovers(); redactions.remove(at: selection) }
                    selection = nil
                }.disabled(selection == nil).accessibilityLabel("Delete selected cover")
            }
    }
    private var confirmationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let preview {
                Button { expandedPreview = true } label: {
                    HStack(spacing: 14) {
                        Image(uiImage: preview).resizable().scaledToFit().frame(width: 48, height: 60)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Final image").font(.headline)
                            Text("Tap to inspect").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(); Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }.padding(14).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain).accessibilityIdentifier("finalUploadPreview")
            }
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Google · Gemini", systemImage: "sparkles").font(.headline)
                    Text(workspace.aiConnection.preferences.model.title).font(.caption).foregroundStyle(.secondary)
                }
                Text("Uses your API allowance. Free-tier uploads may be reviewed by people and used to improve Google’s products.")
                    .font(.subheadline)
                Text("Only this image and reading instructions are sent. Your original stays here; metadata and other receipts aren’t sent. Covers can’t guarantee anonymity.")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("Google data-use terms", destination: URL(string: "https://ai.google.dev/gemini-api/terms")!)
                    .font(.footnote)
            }
            Toggle(isOn: $acknowledged) { Text("Allow this upload to Google").font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                .tint(.green).accessibilityIdentifier("uploadConsent")
            Button("Edit hidden areas") { go(2) }
                .buttonStyle(ReceiptSecondaryStyle()).frame(maxWidth: .infinity)
        }
    }
    private var actionTitle: String {
        switch step { case 0: cropEditing ? "Apply crop" : "Continue"; case 1: useAI ? "Continue" : "Read receipt"; case 2: "Review upload"; default: "Upload and read" }
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
            if cropEditing { cropEditing = false; prepareImage(next: 0) }
            else { prepareImage(next: 1) }
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


/// The image receives the space left after measuring tools and guidance. At large
/// accessibility sizes, the page can grow naturally and the outer scroll view takes over.
private struct ReceiptImportPageLayout: Layout {
    let availableHeight: CGFloat
    let spacing: CGFloat = 12
    func metrics(width: CGFloat, subviews: Subviews) -> (CGFloat, [CGFloat]) {
        let fixed = subviews.dropFirst().map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        let remainder = fixed.reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1))
        let imageHeight = max(120, availableHeight - remainder)
        return (imageHeight + remainder, [imageHeight] + fixed)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 350
        return CGSize(width: width, height: metrics(width: width, subviews: subviews).0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let heights = metrics(width: bounds.width, subviews: subviews).1
        var y = bounds.minY
        for (index, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                       proposal: ProposedViewSize(width: bounds.width, height: heights[index]))
            y += heights[index] + spacing
        }
    }
}
