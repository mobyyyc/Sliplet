import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ReceiptHome: View {
    @Bindable var workspace: ReceiptWorkspace
    @State private var importChoices = false
    @State private var photos = false
    @State private var camera = false
    @State private var cameraResult: ReceiptCameraResult?
    @State private var files = false
    @State private var discard = false
    @State private var discardPending = false
    @State private var delete = false
    @State private var deleteTarget: ReceiptRecord?
    @State private var settings = false
    @State private var recoveryAISettings = false
    @State private var walletInformation = false
    @FocusState private var editing: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    private func anchoredImportChoices<Trigger: View>(@ViewBuilder trigger: () -> Trigger) -> some View {
        trigger()
            .confirmationDialog("Import a receipt", isPresented: $importChoices, titleVisibility: .visible) {
                Button("Take a photo") { camera = true }
                Button("Photo library") { photos = true }
                Button("Files") { files = true }
            } message: { Text("Choose your receipt photo. You’ll select how to read it next.") }
    }

    var body: some View {
        let session = workspace.sessionID
        NavigationStack {
            Group {
                if workspace.privacyCovered { ReceiptLockScreen() }
                else {
                    switch workspace.availability {
                    case .closed, .opening: ProgressView("Opening local wallet")
                    case .failed(let message):
                        ContentUnavailableView {
                            Label("Wallet unavailable", systemImage: "lock.trianglebadge.exclamationmark")
                        } description: { Text(message) } actions: { Button("Try again", action: workspace.retryOpen).buttonStyle(ReceiptSecondaryStyle()) }
                    case .ready: flow
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if workspace.availability == .ready && !workspace.privacyCovered &&
                    (workspace.flow == .detail || (workspace.flow == .wallet && !workspace.library)) {
                    AtmosphericBackground().ignoresSafeArea()
                } else {
                    Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(workspace.flow == .wallet && workspace.library ? .large : .inline)
            .toolbar {
                if workspace.availability == .ready && !workspace.privacyCovered {
                    if workspace.flow != .wallet && workspace.flow != .reading && workspace.flow != .loading {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(workspace.flow == .preparingUpload ? (workspace.importStep > 0 ? "Back" : "Cancel") : workspace.flow == .review ? "Cancel" : "Wallet", systemImage: "chevron.left") {
                                if workspace.flow == .preparingUpload && workspace.importCropping { workspace.importCropping = false }
                                else if workspace.flow == .preparingUpload && workspace.importStep > 0 {
                                    workspace.importForward = false; workspace.importStep -= 1
                                    workspace.checkpointImport()
                                }
                                else if workspace.flow == .review && !workspace.hasUnsavedReviewChanges { editing = nil; workspace.finishEditing() }
                                else if workspace.flow == .review || workspace.flow == .reading || workspace.flow == .loading || workspace.flow == .preparingUpload || (workspace.flow == .failed && workspace.image != nil) { editing = nil; discard = true }
                                else { workspace.backToWallet() }
                            }.disabled(workspace.saving).accessibilityIdentifier("back")
                        }
                    }
                    if workspace.image != nil && workspace.flow != .reading && workspace.flow != .loading {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { editing = nil; workspace.showSource() } label: { Text("Original") }
                                .accessibilityIdentifier("original").disabled(workspace.saving)
                        }
                    }
                    if workspace.flow == .wallet {
                        if workspace.library {
                            ToolbarItem(placement: .topBarTrailing) {
                                if !workspace.hasPendingImport {
                                    anchoredImportChoices {
                                        Button("Import receipt", systemImage: "plus") { importChoices = true }
                                            .accessibilityIdentifier("import")
                                    }
                                }
                            }
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Wallet", systemImage: "chevron.left") { workspace.library = false }
                                    .accessibilityIdentifier("walletTab")
                            }
                        } else if !workspace.receipts.isEmpty {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("All receipts", systemImage: "magnifyingglass") { workspace.collection = "All receipts"; workspace.library = true }.accessibilityIdentifier("allReceipts")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Settings", systemImage: "gearshape") { settings = true }.accessibilityIdentifier("walletSettings")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Wallet information", systemImage: "info.circle") { walletInformation = true }
                                .accessibilityIdentifier("walletInformation")
                        }
                    }
                    if workspace.flow == .detail {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                if let record = workspace.selected {
                                    Button(record.isStarred ? "Unstar receipt" : "Star receipt", systemImage: record.isStarred ? "star.fill" : "star") { workspace.organize(record, action: .star) }
                                    Button(record.isArchived ? "Unarchive receipt" : "Archive receipt", systemImage: "archivebox") { workspace.organize(record, action: .archive) }
                                }
                                Button("Storage details", systemImage: "info.circle") { walletInformation = true }
                                Button("Delete receipt", systemImage: "trash", role: .destructive) { deleteTarget = workspace.selected; delete = true }
                                    .accessibilityIdentifier("delete")
                            } label: { Image(systemName: "ellipsis") }
                            .accessibilityLabel("Receipt options").accessibilityIdentifier("receiptOptions")
                        }
                    }
                    #if DEBUG
                    if SyntheticNativePreview.enabled && SyntheticNativePreview.mode == "search-import" && workspace.flow == .wallet {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Import fictional image") {
                                let bytes = SyntheticNativePreview.fixture(index: 0).0
                                workspace.startImport { bytes }
                            }.accessibilityIdentifier("searchDemoImport")
                        }
                    }
                    if ReceiptUploadFixture.enabled && workspace.flow == .wallet {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Fictional import") {
                                let bytes = SyntheticNativePreview.fixture(index: 0).0
                                workspace.startImport(chooseRecognition: true) { bytes }
                            }.accessibilityIdentifier("uploadFixture")
                        }
                    }
                    if WorkflowTestInput.enabled {
                        if workspace.flow == .wallet {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Local test image") {
                                    if let url = try? WorkflowTestInput.imageURL() { workspace.importFile(url) }
                                }.accessibilityIdentifier("debugImport")
                            }
                        }
                        if workspace.flow == .review {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Test reference") { WorkflowTestInput.applyReference(workspace) }.accessibilityIdentifier("debugReference")
                            }
                        }
                        if workspace.flow == .detail {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Test verify") { WorkflowTestInput.verify(workspace) }.accessibilityIdentifier("debugVerify")
                            }
                        }
                    }
                    #endif
                }
            }
            .safeAreaBar(edge: .bottom, spacing: 0) {
                if workspace.availability == .ready && !workspace.privacyCovered && [.wallet, .detail, .review].contains(workspace.flow) && !(workspace.flow == .wallet && workspace.library && !workspace.hasPendingImport) {
                    bottomActions.modifier(ReceiptActionBarLayout())
                }
            }
            .fullScreenCover(isPresented: $camera, onDismiss: {
                let result = cameraResult; cameraResult = nil
                guard session == workspace.sessionID, workspace.active else { return }
                switch result {
                case .photo(let bytes): workspace.startImport(chooseRecognition: true, fromCamera: true) { bytes }
                case .existingImage: importChoices = true
                default: break
                }
            }) {
                ReceiptCameraView { result in cameraResult = result; camera = false }
            }
            .sheet(isPresented: $photos) {
                ReceiptPhotoPicker { loader in
                    photos = false
                    guard session == workspace.sessionID, let loader else { return }
                    workspace.startImport(chooseRecognition: true) { try await loader.load() }
                }.ignoresSafeArea()
            }
            .fileImporter(isPresented: $files, allowedContentTypes: [.png, .jpeg, .heic, .heif], allowsMultipleSelection: false) { result in
                guard session == workspace.sessionID else { return }
                switch result {
                case .success(let urls): if let url = urls.first { workspace.importFile(url, chooseRecognition: true) }
                case .failure(let error):
                    if (error as NSError).code != CocoaError.userCancelled.rawValue {
                        workspace.errorMessage = ImportFailure.unavailableFile.message
                        workspace.flow = .failed
                    }
                }
            }
            .confirmationDialog("Discard unsaved changes?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { workspace.finishEditing() }
            } message: { Text("Only receipts you explicitly saved are kept.") }
            .confirmationDialog("Discard unfinished import?", isPresented: $discardPending, titleVisibility: .visible) {
                Button("Discard import", role: .destructive, action: workspace.discardPendingImport)
                    .accessibilityIdentifier("discardPendingImportConfirm")
            } message: { Text("This removes the photo and progress for this import from Sliplet.") }
            .alert("Delete this receipt?", isPresented: $delete) {
                Button("Delete receipt and original", role: .destructive) { if let deleteTarget { workspace.deleteReceipt(deleteTarget) }; deleteTarget = nil }
                Button("Cancel", role: .cancel) { deleteTarget = nil }
            } message: { Text("This removes all revisions and the original from this app. Copies in Photos or Files remain there.") }
            .sheet(item: $workspace.detailLine) { line in
                ReceiptFocusedCorrectionView(workspace: workspace, check: line.check, detailLine: line)
            }
            .sheet(isPresented: $workspace.splitVisible) { ReceiptSplitView(workspace: workspace) }
            .sheet(isPresented: $workspace.sourceVisible) { ReceiptSourceView(workspace: workspace) }
            .sheet(isPresented: $walletInformation) { WalletInformationView() }
            .sheet(isPresented: $settings) { ReceiptWalletSettingsView(workspace: workspace) }
            .sheet(isPresented: $recoveryAISettings) {
                NavigationStack {
                    ReceiptAISettingsView(connection: workspace.aiConnection, privacyCovered: workspace.privacyCovered)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { recoveryAISettings = false }
                            }
                        }
                }
            }
            .disabled(workspace.saving)
        }
        .alert("Import progress unavailable", isPresented: Binding(
            get: { workspace.flow != .wallet && workspace.importCheckpointError != nil },
            set: { if !$0 { workspace.dismissCheckpointError() } }
        )) {
            Button("OK", role: .cancel) { workspace.dismissCheckpointError() }
        } message: { Text(workspace.importCheckpointError ?? "") }
        .onChange(of: workspace.aiConnection.canUseAI) { _, ready in
            if !ready && workspace.aiUploadStarted && workspace.flow == .reading { workspace.stopReading() }
        }
        .tint(.primary)
        .environment(\.receiptPaperAppearance, workspace.walletSettings.paperAppearance)
    }
    @ViewBuilder private var bottomActions: some View {
        switch workspace.flow {
        case .wallet:
            if workspace.hasPendingImport {
                VStack(spacing: 8) {
                    if let message = workspace.importCheckpointError {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                    ReceiptPairedActions {
                        Button("Discard") { discardPending = true }
                            .buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("discardPendingImport")
                    } primary: {
                        Button("Continue import", systemImage: "doc.viewfinder", action: workspace.resumePendingImport)
                            .buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("resumePendingImport")
                    }
                }.frame(maxWidth: .infinity)
            } else {
                HStack {
                    Spacer()
                    anchoredImportChoices {
                        Button { importChoices = true } label: {
                            Image(systemName: "plus").font(.title.weight(.bold))
                        }.buttonStyle(ReceiptSecondaryStyle(circular: true, diameter: 64))
                            .accessibilityLabel("Import receipt").accessibilityIdentifier("import")
                    }
                    Spacer()
                }
            }
        case .detail:
            if typeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    editAction
                    Button("Split", systemImage: "person.2") { workspace.splitVisible = true }
                        .buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("splitOpen")
                        .disabled(workspace.saving || workspace.selected == nil || workspace.image == nil)
                }.frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 12) {
                    Button { workspace.splitVisible = true } label: {
                        Image(systemName: "person.2")
                    }.buttonStyle(ReceiptSecondaryStyle(circular: true))
                        .accessibilityLabel("Split").accessibilityIdentifier("splitOpen")
                        .disabled(workspace.saving || workspace.selected == nil || workspace.image == nil)
                    Spacer(minLength: 0)
                    editAction.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    Color.clear.frame(width: 44, height: 1).accessibilityHidden(true)
                }
            }
        case .review:
            if editing != nil {
                HStack {
                    Spacer()
                    Button("Done") { editing = nil }.buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("keyboardDone")
                }
            } else { ReceiptPairedActions {
                Button { editing = nil; workspace.save(asDraft: true) } label: {
                    Text("Save draft")
                }.buttonStyle(ReceiptSecondaryStyle())
                    .disabled(!workspace.draft.canSaveDraft || workspace.saving).accessibilityIdentifier("saveDraft")
            } primary: {
                Button { editing = nil; workspace.save(asDraft: false) } label: {
                    Text("Finish")
                }.buttonStyle(ReceiptProminentStyle())
                    .disabled(!workspace.draft.canFinalize || workspace.saving).accessibilityIdentifier("finishSave")
            }.frame(maxWidth: .infinity) }
        case .loading, .preparingUpload, .reading, .failed: EmptyView()
        }
    }
    private var editAction: some View {
        Button { workspace.edit() } label: {
            Label("Edit receipt", systemImage: "pencil")
        }.buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("edit")
            .disabled(workspace.saving || workspace.image == nil)
    }
    private var title: String {
        switch workspace.flow {
        case .wallet: workspace.library ? (workspace.searchQuery.isEmpty ? workspace.collection : "Search") : ""
        case .review: "Review receipt"
        case .detail: "Receipt"
        case .failed: "Import needs attention"
        case .loading, .preparingUpload, .reading: "Import receipt"
        }
    }
    @ViewBuilder private var flow: some View {
        switch workspace.flow {
        case .wallet, .detail, .review:
            ZStack {
                // Disable this modifier when visible so decorative child visibility is preserved.
                wallet.opacity(workspace.flow == .review ? 0 : 1)
                    .allowsHitTesting(workspace.flow != .review)
                    .accessibilityHidden(true, isEnabled: workspace.flow == .review)
                if workspace.flow == .review { ReceiptReviewView(workspace: workspace, editing: $editing) }
            }
        case .preparingUpload: ReceiptUploadPreview(workspace: workspace, retake: { camera = true })
        case .loading, .reading:
            ReceiptReadingView(openingPhoto: workspace.flow == .loading,
                               usingAI: workspace.flow == .reading && workspace.aiUploadStarted) {
                if workspace.flow == .reading { workspace.stopReading() }
                else { workspace.cancelImport() }
            }
            #if DEBUG
            .dynamicTypeSize(ReceiptUploadFixture.enabled
                             && ProcessInfo.processInfo.arguments.contains("--p1201-large-reading")
                             ? .accessibility5 : typeSize)
            #endif

        case .failed:
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label(workspace.image == nil ? "Couldn’t open the photo" : "Continue with your photo",
                          systemImage: workspace.image == nil ? "photo" : "doc.viewfinder")
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    if let message = workspace.errorMessage { Text(message).foregroundStyle(.secondary) }
                    if workspace.image != nil {
                        VStack(alignment: .leading, spacing: 14) {
                            Button(workspace.aiUploadStarted ? "Review upload again" : "Reading options",
                                   systemImage: workspace.aiUploadStarted ? "eye" : "doc.viewfinder",
                                   action: workspace.chooseRecognition)
                                .accessibilityIdentifier("recoverPreview")
                            if workspace.aiUploadStarted {
                                Button("AI settings", systemImage: "gear") { recoveryAISettings = true }
                                    .accessibilityIdentifier("recoverAISettings")
                                Button("Enter manually", systemImage: "pencil", action: workspace.manualReview)
                                    .accessibilityIdentifier("manual")
                            }
                            anchoredImportChoices {
                                Button("Choose another image", systemImage: "photo") { importChoices = true }
                            }
                        }
                        .buttonStyle(ReceiptSecondaryStyle())
                    }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollClipDisabled().scrollEdgeEffectStyle(.soft, for: .vertical)
            .safeAreaBar(edge: .bottom, spacing: 0) {
                Group {
                    if workspace.image == nil {
                        anchoredImportChoices {
                            Button("Choose another image", systemImage: "photo") { importChoices = true }
                                .buttonStyle(ReceiptProminentStyle())
                        }
                    } else if workspace.aiUploadStarted {
                        Button("Read on device", systemImage: "iphone", action: workspace.readImage)
                            .buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("recoverLocal")
                    } else {
                        Button("Enter manually", systemImage: "pencil", action: workspace.manualReview)
                            .buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("manual")
                    }
                }.modifier(ReceiptActionBarLayout())
            }
        }
    }
    private var wallet: some View {
        Group {
            if workspace.library && workspace.flow == .wallet {
                ReceiptPurchaseHistoryView(workspace: workspace) { record in
                    deleteTarget = record; delete = true
                }
            } else if workspace.library {
                ReceiptSearchDetailView(workspace: workspace)
            } else {
                ReceiptWalletScene(workspace: workspace) { record in
                    deleteTarget = record; delete = true
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if workspace.receipts.filter({ !$0.isArchived }).isEmpty && workspace.flow == .wallet {
                        Text("Wallet").font(.largeTitle.weight(.bold)).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 16).accessibilityAddTraits(.isHeader)
                    }
                }
            }
        }
    }
    @ViewBuilder private var debugControls: some View {
        #if DEBUG
        WorkflowTestControls(workspace: workspace)
        #endif
    }
}

/// Illustration only: no fake receipt data or competing action.
private struct WalletInformationView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Private by default", systemImage: "lock")
                    Text("On-device recognition is always available. Optional AI sends only the image you preview and approve. Receipt storage stays on this device.")
                }
                Section("Storage") {
                    Text("Receipts stay on this device. Export a password-encrypted backup in Settings so you can restore them later. Automatic backup is excluded.")
                }
                Section("Before you leave") {
                    Text("Save your draft before leaving the app. Backgrounding clears unsaved work.")
                }
                #if DEBUG
                if !SyntheticNativePreview.enabled {
                    Section("Development") { NavigationLink("Synthetic diagnostics") { DiagnosticsView() } }
                }
                #endif
            }.navigationTitle("Your local wallet").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct ReceiptSummary: View {
    let record: ReceiptRecord
    @Environment(\.dynamicTypeSize) private var typeSize
    private var total: String {
        record.current.fields.total.map { "\($0.currency.code) \(ExactInput.format($0.minorUnits, scale: $0.currency.minorUnitScale))" } ?? "Total missing"
    }
    private var merchant: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.current.fields.merchant ?? "Merchant missing").font(.headline).fixedSize(horizontal: false, vertical: true)
            Text(ExactInput.dateText(record.current.fields.purchaseDate).nilIfEmpty ?? "Date missing").font(.footnote)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if typeSize.isAccessibilitySize {
                merchant
                Text(total).font(.headline.monospacedDigit())
            } else {
                HStack(alignment: .top, spacing: 16) {
                    merchant
                    Spacer(minLength: 4)
                    Text(total).font(.headline.monospacedDigit()).fixedSize(horizontal: true, vertical: false)
                }
            }
            if record.isStarred { Label("Starred", systemImage: "star.fill").font(.caption) }
            if !ReceiptCompletion.isComplete(record) {
                Label("Needs review", systemImage: "exclamationmark.circle").font(.caption.weight(.medium))
            }
        }.foregroundStyle(.primary).accessibilityElement(children: .combine)
    }
}
