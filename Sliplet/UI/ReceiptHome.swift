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
    @State private var selectingReplacement = false
    @State private var confirmReplacement = false
    @State private var duplicateSave: DuplicateSave?
    private struct DuplicateSave {
        let match: ReceiptImportMatch
        let asDraft: Bool
    }

    private func saveReview(asDraft: Bool) {
        editing = nil
        if let match = workspace.duplicateBeforeImportSave {
            duplicateSave = DuplicateSave(match: match, asDraft: asDraft)
        } else {
            workspace.save(asDraft: asDraft)
        }
    }
    @State private var delete = false
    @State private var deleteTarget: ReceiptRecord?
    @State private var sharingReceipt = false
    @State private var settings = false
    @State private var recoveryAISettings = false
    @State private var walletInformation = false
    @State private var showingSavedDrafts = false
    @State private var chosenSavedDraft: UUID?
    @State private var purchaseOverview: ReceiptOverviewNavigation?
    @State private var presentedPurchaseOverview: ReceiptOverviewNavigation?
    @State private var overviewReceiptID: UUID?
    @AppStorage("receiptDisplayList") private var displayList = false
    @FocusState private var editing: String?
    @FocusState private var searchFocused: Bool
    @State private var keyboardVisible = false
    private enum SearchReturn { case idle, animating, waitingForKeyboard }
    @State private var searchReturn = SearchReturn.idle
    @State private var searchOffset: CGFloat = 0
    @State private var searchWidth: CGFloat = 1
    @State private var homeBrowseVersion = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var showsDuplicateSave: Binding<Bool> {
        Binding(get: { duplicateSave != nil }, set: { if !$0 { duplicateSave = nil } })
    }

    private func anchoredImportChoices<Trigger: View>(@ViewBuilder trigger: () -> Trigger) -> some View {
        trigger()
            .confirmationDialog("Import a receipt", isPresented: $importChoices, titleVisibility: .visible) {
                photoSources(replacing: selectingReplacement)
            } message: { Text("Choose your receipt photo. You’ll select how to read it next.") }
    }

    @ViewBuilder private func photoSources(replacing: Bool) -> some View {
        Button("Take a photo") { selectingReplacement = replacing; camera = true }
        Button("Photo library") { selectingReplacement = replacing; photos = true }
        Button("Files") { selectingReplacement = replacing; files = true }
    }

    var body: some View {
        let session = workspace.sessionID
        let canReturnToImportStep = workspace.flow == .preparingUpload && workspace.importStep > 0 && workspace.photoDuplicatePrompt == nil
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if workspace.availability == .ready && !workspace.privacyCovered {
                    if workspace.flow != .wallet && workspace.flow != .reading && workspace.flow != .loading {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(workspace.flow == .preparingUpload ? (canReturnToImportStep ? "Back" : "Cancel") : workspace.flow == .review ? "Cancel" : overviewReceiptID != nil ? "Purchase overview" : "Wallet", systemImage: "chevron.left") {
                                if workspace.flow == .preparingUpload && workspace.importCropping { workspace.importCropping = false }
                                else if canReturnToImportStep {
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
                        ToolbarItem(placement: .topBarLeading) {
                            Text(workspace.library ? "Receipts" : "Wallet")
                                .font(.headline).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("browseTitle")
                        }.sharedBackgroundVisibility(.hidden)
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button("Search", systemImage: "magnifyingglass") {
                                openSearch()
                            }.accessibilityIdentifier("receiptSearch")
                            Button("Filters", systemImage: workspace.hasBrowseFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                workspace.searchFiltersExpanded = true
                            }.accessibilityIdentifier("searchFilters")
                        }
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Settings", systemImage: "gearshape") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                settings = true
                            }
                                .accessibilityIdentifier("walletSettings")
                        }

                    }
                    if workspace.flow == .detail {
                        if workspace.selected != nil {
                            ToolbarItem(placement: .topBarTrailing) {
                                ReceiptShareButton { sharingReceipt = true }.disabled(workspace.saving)
                            }
                        }
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
                    if SyntheticNativePreview.enabled && SyntheticNativePreview.mode == "search-import" && workspace.flow == .wallet && workspace.receipts.isEmpty {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Import fictional image", systemImage: "doc.badge.plus") {
                                let bytes = SyntheticNativePreview.fixture(index: 0).0
                                workspace.startImport { bytes }
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("searchDemoImport")
                        }
                    }
                    if ReceiptUploadFixture.enabled && workspace.flow == .wallet {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Fictional import", systemImage: "doc.badge.plus") {
                                let bytes = SyntheticNativePreview.fixture(index: 0, forImport: true).0
                                workspace.startImport(chooseRecognition: true) { bytes }
                            }.labelStyle(.iconOnly).accessibilityIdentifier("uploadFixture")
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
                if workspace.availability == .ready && !workspace.privacyCovered && [.detail, .review].contains(workspace.flow) {
                    bottomActions.modifier(ReceiptActionBarLayout())
                }
            }
            .fullScreenCover(isPresented: $camera, onDismiss: {
                let result = cameraResult; cameraResult = nil
                guard session == workspace.sessionID, workspace.active else { return }
                switch result {
                case .photo(let bytes):
                    let replacing = selectingReplacement
                    selectingReplacement = false
                    workspace.startImport(chooseRecognition: true, fromCamera: true, replacingPendingImport: replacing) { bytes }
                case .existingImage: importChoices = true
                default: selectingReplacement = false
                }
            }) {
                ReceiptCameraView { result in cameraResult = result; camera = false }
            }
            .sheet(isPresented: $photos) {
                ReceiptPhotoPicker { loader in
                    photos = false
                    let replacing = selectingReplacement
                    selectingReplacement = false
                    guard session == workspace.sessionID, let loader else { return }
                    workspace.startImport(chooseRecognition: true, replacingPendingImport: replacing) { try await loader.load() }
                }.ignoresSafeArea()
            }
            .fileImporter(isPresented: $files, allowedContentTypes: [.png, .jpeg, .heic, .heif], allowsMultipleSelection: false) { result in
                let replacing = selectingReplacement
                selectingReplacement = false
                guard session == workspace.sessionID else { return }
                switch result {
                case .success(let urls):
                    if let url = urls.first { workspace.importFile(url, chooseRecognition: true, replacingPendingImport: replacing) }
                case .failure(let error):
                    if (error as NSError).code != CocoaError.userCancelled.rawValue {
                        workspace.reportImportPickerFailure(replacingPendingImport: replacing)
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
            .alert("Replace unfinished import?", isPresented: $confirmReplacement) {
                Button("Keep current import", role: .cancel, action: workspace.cancelImportReplacement)
                Button("Replace import", role: .destructive, action: workspace.confirmImportReplacement)
            } message: {
                Text("The new photo will replace your current photo and its unsaved progress.")
            }
            .alert(duplicateSave?.match.kind == .samePhoto ? "Photo already saved" : "Possible duplicate",
                   isPresented: showsDuplicateSave, presenting: duplicateSave) { decision in
                if decision.match.kind == .samePhoto {
                    Button("Open saved receipt") { workspace.openSavedDuplicate(decision.match.record) }
                        .accessibilityIdentifier("openSavedDuplicate")
                }
                Button(decision.asDraft ? "Save separate draft" : "Save separately") {
                    if !workspace.privacyCovered { workspace.save(asDraft: decision.asDraft) }
                }.accessibilityIdentifier("saveDuplicateSeparately")
                Button("Keep reviewing", role: .cancel) { }
            } message: { decision in
                if decision.match.kind == .samePhoto {
                    Text("This photo is already in your wallet. Opening the saved receipt discards this import.")
                } else {
                    Text("A saved receipt has the same store, date, total and receipt lines. If these are separate purchases, you can keep both.")
                }
            }
            .alert("Delete this receipt?", isPresented: $delete) {
                Button("Delete receipt and original", role: .destructive) { if let deleteTarget { workspace.deleteReceipt(deleteTarget) }; deleteTarget = nil }
                Button("Cancel", role: .cancel) { deleteTarget = nil }
            } message: { Text("This removes all revisions and the original from this app. Copies in Photos or Files remain there.") }
            .sheet(item: $workspace.detailLine) { line in
                ReceiptFocusedCorrectionView(workspace: workspace, check: line.check, detailLine: line)
            }
            .sheet(isPresented: $sharingReceipt) {
                if let id = workspace.selected?.id { ReceiptShareView(workspace: workspace, receiptID: id) }
            }
            .sheet(isPresented: $workspace.splitVisible) { ReceiptSplitView(workspace: workspace) }
            .sheet(isPresented: $workspace.sourceVisible) { ReceiptSourceView(workspace: workspace) }
            .sheet(isPresented: $workspace.searchFiltersExpanded) { ReceiptBrowseFiltersView(workspace: workspace) }
            .sheet(isPresented: $walletInformation) { WalletInformationView() }
            .sheet(isPresented: $settings) { ReceiptWalletSettingsView(workspace: workspace) }
            .sheet(isPresented: $showingSavedDrafts, onDismiss: {
                let id = chosenSavedDraft
                chosenSavedDraft = nil
                if session == workspace.sessionID, let id { workspace.resumeSavedDraft(id) }
            }) {
                savedDraftPicker
            }
            .sheet(item: $presentedPurchaseOverview, onDismiss: finishOverviewPresentation) { navigation in
                if workspace.privacyCovered {
                    ReceiptLockScreen()
                } else {
                    ReceiptPurchaseOverviewView(navigation: navigation, records: workspace.orderedReceipts,
                                                revision: workspace.purchaseOverviewRevision) { id in
                        overviewReceiptID = id
                        presentedPurchaseOverview = nil
                    }.dynamicTypeSize(typeSize)
                }
            }
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
            get: { workspace.flow != .wallet && !workspace.openedFromSavedDraftShortcut && workspace.importCheckpointError != nil },
            set: { if !$0 { workspace.dismissCheckpointError() } }
        )) {
            Button("OK", role: .cancel) { workspace.dismissCheckpointError() }
        } message: { Text(workspace.importCheckpointError ?? "") }
        .alert("Couldn’t open draft", isPresented: Binding(
            get: { workspace.savedDraftOpenError != nil },
            set: { if !$0 { workspace.savedDraftOpenError = nil } }
        )) {
            Button("OK", role: .cancel) { workspace.savedDraftOpenError = nil }
        } message: { Text(workspace.savedDraftOpenError ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            workspace.refreshCalendarGrouping()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            keyboardVisible = false
            if searchReturn == .waitingForKeyboard { finishSearchReturn() }
        }
        .onChange(of: workspace.flow) { _, flow in
            if flow != .wallet { resetSearchReturn() }
            if flow == .wallet && overviewReceiptID != nil {
                overviewReceiptID = nil
                presentedPurchaseOverview = workspace.active && !workspace.privacyCovered ? purchaseOverview : nil
            }
        }
        .onChange(of: workspace.searching) { _, searching in
            if !searching { resetSearchReturn() }
        }
        .onChange(of: workspace.importReplacementReady) { _, ready in confirmReplacement = ready }
        .onAppear {
            #if DEBUG
            if !SyntheticNativePreview.enabled { workspace.library = displayList }
            #else
            workspace.library = displayList
            #endif
        }
        .onChange(of: workspace.availability) { _, state in
            guard state == .ready else { return }
            #if DEBUG
            if !SyntheticNativePreview.enabled { workspace.library = displayList }
            #else
            workspace.library = displayList
            #endif
        }
        .onChange(of: workspace.library) { _, value in
            guard workspace.active, workspace.availability == .ready else { return }
            #if DEBUG
            if !SyntheticNativePreview.enabled { displayList = value }
            #else
            displayList = value
            #endif
        }
        .onChange(of: workspace.aiConnection.canUseAI) { _, ready in
            if !ready && workspace.aiUploadStarted && workspace.flow == .reading { workspace.stopReading() }
        }
        .tint(.primary)
        .environment(\.receiptPaperAppearance, workspace.walletSettings.paperAppearance)
    }
    private func showPurchaseOverview(_ month: String?) {
        guard workspace.flow == .wallet, !workspace.searching, !workspace.privacyCovered, !workspace.saving else { return }
        let today = ReceiptBrowsingPeriod.today()
        let currentMonth = String(format: "%04d-%02d", today.year, today.month)
        let navigation = ReceiptOverviewNavigation(month: month ?? currentMonth)
        if month == nil { navigation.path = [.undated] }
        purchaseOverview = navigation
        presentedPurchaseOverview = navigation
    }

    private func finishOverviewPresentation() {
        guard let id = overviewReceiptID else {
            purchaseOverview = nil
            return
        }
        if workspace.active, !workspace.privacyCovered, !workspace.saving,
           let record = workspace.orderedReceipts.first(where: { $0.id == id }) {
            workspace.open(record)
        } else {
            overviewReceiptID = nil
            purchaseOverview = nil
        }
    }

    private var reduceSearchMotion: Bool { ReceiptAccessibility.reduceMotion(systemReduceMotion) }

    private func openSearch() {
        guard searchReturn == .idle else { return }
        withoutSearchAnimation {
            if !workspace.searching {
                // Prepare the usual newest-first landing before it becomes visible on return.
                workspace.resetHomeToNewest()
                homeBrowseVersion += 1
                workspace.searching = true
            }
            searchFocused = true
        }
    }

    private func closeSearch() {
        guard searchReturn == .idle, workspace.flow == .wallet, workspace.searching else { return }
        searchReturn = .animating
        withoutSearchAnimation { searchFocused = false }
        withAnimation(.easeOut(duration: reduceSearchMotion ? 0.15 : 0.29), completionCriteria: .removed) {
            searchOffset = searchWidth
        } completion: {
            guard searchReturn == .animating, workspace.flow == .wallet, workspace.searching else { return }
            // Let both animations run together, but keep the search scroll surface mounted until iOS settles its keyboard inset.
            if keyboardVisible { searchReturn = .waitingForKeyboard }
            else { finishSearchReturn() }
        }
    }

    private func finishSearchReturn() {
        guard workspace.flow == .wallet, workspace.searching else { return }
        withoutSearchAnimation {
            workspace.endSearch()
            resetSearchReturn()
        }
    }

    private func resetSearchReturn() {
        searchReturn = .idle
        searchOffset = 0
    }

    private func updateSearchEdgePan(_ pan: UIPanGestureRecognizer) {
        guard searchReturn == .idle else { return }
        let translation = pan.translation(in: pan.view?.window).x
        let velocity = pan.velocity(in: pan.view?.window).x
        switch pan.state {
        case .began, .changed:
            // Leave room for the exit animation even after a very long drag.
            if !reduceSearchMotion { searchOffset = min(max(translation, 0), searchWidth * 0.95) }
        case .ended where translation > searchWidth * 0.34 || (translation > 24 && velocity > 550):
            closeSearch()
        case .ended, .cancelled, .failed:
            withAnimation(.easeOut(duration: 0.22)) { searchOffset = 0 }
        default: break
        }
    }

    private func withoutSearchAnimation(_ updates: () -> Void) {
        // The navigation toolbar is not part of the search presentation.
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            if ReceiptAccessibility.reduceTransparency(reduceTransparency) || ReceiptAccessibility.contrast(colorSchemeContrast) == .increased {
                searchField.background(Color(uiColor: .secondarySystemGroupedBackground), in: .capsule)
                    .overlay { Capsule().stroke(.primary.opacity(0.35), lineWidth: 1).allowsHitTesting(false) }
            } else {
                searchField.glassEffect(.regular, in: .capsule)
            }
            Button("Close search", systemImage: "xmark", action: closeSearch)
                .labelStyle(.iconOnly)
                .buttonStyle(ReceiptSecondaryStyle(circular: true, diameter: 48))
                .accessibilityIdentifier("close")
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").accessibilityHidden(true)
            TextField("Merchant, item or code", text: $workspace.searchQuery)
                .focused($searchFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityAddTraits(.isSearchField)
                .accessibilityIdentifier("receiptSearchField")
                .onSubmit { searchFocused = false }
            if !workspace.searchQuery.isEmpty {
                Button("Clear text", systemImage: "xmark.circle.fill") { workspace.searchQuery = "" }
                    .labelStyle(.iconOnly).buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, workspace.searchQuery.isEmpty ? 14 : 3)
        .frame(minHeight: 48)
    }

    @ViewBuilder private var bottomActions: some View {
        switch workspace.flow {
        case .wallet:
            if workspace.hasPendingImport {
                VStack(spacing: 8) {
                    if let message = workspace.importCheckpointError {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button(action: workspace.resumePendingImport) {
                            if typeSize.isAccessibilitySize {
                                Text("Continue import")
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Label("Continue import", systemImage: "doc.viewfinder")
                            }
                        }
                        .buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("resumePendingImport")
                        pendingImportOptions
                    }
                }.frame(maxWidth: .infinity)
            } else {
                HStack {
                    Spacer()
                    anchoredImportChoices {
                        Button { selectingReplacement = false; importChoices = true } label: {
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
                Button { saveReview(asDraft: true) } label: {
                    Text("Save draft")
                }.buttonStyle(ReceiptSecondaryStyle())
                    .disabled(!workspace.draft.canSaveDraft || workspace.saving).accessibilityIdentifier("saveDraft")
            } primary: {
                Button { saveReview(asDraft: false) } label: {
                    Text("Finish")
                }.buttonStyle(ReceiptProminentStyle())
                    .disabled(!workspace.draft.canFinalize || workspace.saving).accessibilityIdentifier("finishSave")
            }.frame(maxWidth: .infinity) }
        case .loading, .preparingUpload, .reading, .failed: EmptyView()
        }
    }
    private var editAction: some View {
        Button { workspace.edit() } label: {
            Label(workspace.selected.map(ReceiptCompletion.isComplete) == false ? "Continue review" : "Edit receipt",
                  systemImage: "pencil")
        }.buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("edit")
            .disabled(workspace.saving || workspace.image == nil)
    }
    private var title: String {
        switch workspace.flow {
        case .wallet: ""
        case .review: "Review receipt"
        case .detail: "Receipt"
        case .failed: "Import needs attention"
        case .loading, .preparingUpload, .reading: "Import receipt"
        }
    }
    @ViewBuilder private var flow: some View {
        switch workspace.flow {
        case .wallet, .detail, .review:
            let shortcutDetail = workspace.openedFromSavedDraftShortcut && workspace.flow == .detail
            let hideHome = workspace.flow == .review || shortcutDetail
            ZStack {
                // Disable this modifier when visible so decorative child visibility is preserved.
                wallet.opacity(hideHome ? 0 : 1)
                    .allowsHitTesting(!hideHome)
                    .accessibilityHidden(true, isEnabled: hideHome)
                if workspace.flow == .review { ReceiptReviewView(workspace: workspace, editing: $editing) }
                else if shortcutDetail { ReceiptSearchDetailView(workspace: workspace) }
                else if workspace.openedFromSavedDraftShortcut && workspace.saving {
                    ProgressView("Opening draft")
                        .padding(16).background(.regularMaterial, in: .rect(cornerRadius: 16))
                }
            }
        case .preparingUpload:
            if let record = workspace.photoDuplicatePrompt {
                duplicatePhoto(record)
            } else {
                ReceiptUploadPreview(workspace: workspace, retake: { selectingReplacement = false; camera = true })
            }
        case .loading, .reading:
            ReceiptReadingView(openingPhoto: workspace.flow == .loading,
                               usingAI: workspace.flow == .reading && workspace.aiUploadStarted,
                               savingPhoto: workspace.flow == .loading && workspace.saving) {
                if workspace.flow == .reading { workspace.stopReading() }
                else { workspace.cancelImport() }
            }
            #if DEBUG
            .dynamicTypeSize(ReceiptUploadFixture.enabled
                             && ProcessInfo.processInfo.arguments.contains("--p1201-large-reading")
                             ? .accessibility5 : typeSize)
            #endif

        case .failed: importRecovery
        }
    }

    private func duplicatePhoto(_ record: ReceiptRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Photo already saved", systemImage: "doc.on.doc")
                    .font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                ReceiptSummary(record: record)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                if let error = workspace.errorMessage { Text(error).foregroundStyle(.secondary) }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                Button("Open saved receipt") { workspace.openSavedDuplicate(record) }
                    .buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("openSavedDuplicate")
                Button("Import another copy", action: workspace.continueDuplicatePhoto)
                    .buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("continueDuplicatePhoto")
            }
            .disabled(workspace.saving)
            .modifier(ReceiptActionBarLayout())
        }
    }

    private var retryUploadFirst: Bool {
        guard workspace.aiUploadStarted, workspace.aiConnection.canUseAI else { return false }
        switch workspace.lastAIReadFailure {
        case .timedOut, .invalidResponse: return true
        default: return false
        }
    }

    private var importRecoveryTitle: String {
        guard workspace.image != nil else { return "Couldn’t open the photo" }
        guard workspace.aiUploadStarted else { return "Continue with your photo" }
        switch workspace.lastAIReadFailure {
        case .timedOut: return "AI reading timed out"
        case .offline: return "You’re offline"
        case .rateOrQuotaLimit: return "Google usage limit reached"
        case .billingRequired, .accessDenied, .modelUnavailable, .invalidKey, .secureStorage:
            return "Check the AI connection"
        case .serviceUnavailable, .invalidResponse: return "AI couldn’t read this receipt"
        case nil: return "Continue with your photo"
        }
    }

    private var importRecovery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(importRecoveryTitle, systemImage: workspace.image == nil ? "photo" : "doc.viewfinder")
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    if let message = workspace.errorMessage { Text(message).foregroundStyle(.secondary) }
                    if workspace.image != nil && workspace.aiUploadStarted {
                        Text(retryUploadFirst
                             ? "Your photo and covers are still here. Review the image again before retrying."
                             : "Your photo is still here. You can read it on this iPhone.")
                            .font(.subheadline)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if workspace.image != nil {
                    VStack(alignment: .leading, spacing: 16) {
                        if workspace.aiUploadStarted {
                            if workspace.lastAIReadFailure == .rateOrQuotaLimit || workspace.lastAIReadFailure == .billingRequired {
                                Link(destination: URL(string: "https://aistudio.google.com/usage")!) {
                                    Label("Check Google usage", systemImage: "chart.bar")
                                }
                            }
                            if retryUploadFirst {
                                Button("Read on device instead", systemImage: "iphone", action: workspace.readImage)
                                    .accessibilityIdentifier("recoverLocal")
                            } else if workspace.aiConnection.canUseAI {
                                retryImportButton
                            }
                            Button("AI settings", systemImage: "gear") { recoveryAISettings = true }
                                .accessibilityIdentifier("recoverAISettings")
                            Button("Enter manually", systemImage: "pencil", action: workspace.manualReview)
                                .accessibilityIdentifier("manual")
                        } else {
                            Button("Reading options", systemImage: "doc.viewfinder", action: workspace.chooseRecognition)
                                .accessibilityIdentifier("recoverPreview")
                        }
                        chooseAnotherImage
                    }
                    .font(.body)
                    .buttonStyle(.borderless)
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollClipDisabled().scrollEdgeEffectStyle(.soft, for: .vertical)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            Group {
                if workspace.image == nil {
                    chooseAnotherImage
                } else if retryUploadFirst {
                    retryImportButton
                } else if workspace.aiUploadStarted {
                    Button("Read on device", systemImage: "iphone", action: workspace.readImage)
                        .accessibilityIdentifier("recoverLocal")
                } else {
                    Button("Enter manually", systemImage: "pencil", action: workspace.manualReview)
                        .accessibilityIdentifier("manual")
                }
            }
            .buttonStyle(ReceiptProminentStyle())
            .modifier(ReceiptActionBarLayout())
        }
    }

    private var retryImportButton: some View {
        Button("Review and retry upload", systemImage: "eye", action: workspace.chooseRecognition)
            .accessibilityIdentifier("recoverPreview")
    }

    private var chooseAnotherImage: some View {
        anchoredImportChoices {
            Button("Choose another image", systemImage: "photo") { selectingReplacement = false; importChoices = true }
        }
    }

    private var pendingImportOptions: some View {
        anchoredImportChoices {
            Menu {
                Menu("Choose another photo", systemImage: "photo") {
                    photoSources(replacing: true)
                }
                Button("Discard import", systemImage: "trash", role: .destructive) { discardPending = true }
                    .accessibilityIdentifier("discardPendingImport")
            } label: {
                let icon = Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                if ReceiptAccessibility.reduceTransparency(reduceTransparency) || ReceiptAccessibility.contrast(colorSchemeContrast) == .increased {
                    icon.background(Color(uiColor: .secondarySystemGroupedBackground), in: .circle)
                        .overlay { Circle().stroke(.primary.opacity(0.35), lineWidth: 1).allowsHitTesting(false) }
                } else {
                    icon.glassEffect(.regular.interactive(), in: .circle)
                }
            }
            .accessibilityLabel("Unfinished import options")
            .accessibilityIdentifier("pendingImportOptions")
        }
    }

    private var wallet: some View {
        let showingSearch = workspace.flow == .wallet && workspace.searching
        return ZStack {
            walletContent
                .id(homeBrowseVersion)
                .safeAreaBar(edge: .top, spacing: 0) {
                    if workspace.flow == .wallet && workspace.library && workspace.hasBrowseFilters {
                        ReceiptActiveFiltersBar(workspace: workspace)
                    }
                }
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    if workspace.flow == .wallet { bottomActions.modifier(ReceiptActionBarLayout()) }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .allowsHitTesting(!showingSearch)
                .accessibilityHidden(true, isEnabled: showingSearch)
            if showingSearch { searchSurface }
        }
    }

    @ViewBuilder private var walletContent: some View {
        if workspace.library && (workspace.flow == .wallet || workspace.openedFromSavedDraftShortcut) {
            browseList(isSearchResults: false)
        } else if workspace.flow != .wallet && (workspace.library || workspace.searching || overviewReceiptID != nil) {
            ReceiptSearchDetailView(workspace: workspace)
        } else {
            ReceiptWalletScene(workspace: workspace, openOverview: showPurchaseOverview, openSavedDrafts: openSavedDrafts,
                               requestDelete: requestBrowseDeletion)
        }
    }

    private func browseList(isSearchResults: Bool) -> some View {
        ReceiptPurchaseHistoryView(workspace: workspace, openSettings: { settings = true }, isSearchResults: isSearchResults,
                                   openOverview: showPurchaseOverview, openSavedDrafts: openSavedDrafts,
                                   requestDelete: requestBrowseDeletion)
    }

    private func requestBrowseDeletion(_ record: ReceiptRecord) {
        deleteTarget = record
        delete = true
    }

    private var searchSurface: some View {
        browseList(isSearchResults: true)
            .safeAreaBar(edge: .top, spacing: 0) {
                if workspace.hasBrowseFilters { ReceiptActiveFiltersBar(workspace: workspace) }
            }
            .safeAreaBar(edge: .bottom, spacing: 0) { searchBar.modifier(ReceiptActionBarLayout()) }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea(.container))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { searchWidth = max(1, $0) }
            .background {
                ReceiptSearchBackGesture(isEnabled: searchReturn == .idle && !workspace.searchFiltersExpanded && !settings && !delete,
                                         action: updateSearchEdgePan)
            }
            .accessibilityAction(.escape, closeSearch)
            .offset(x: reduceSearchMotion ? 0 : searchOffset)
            .opacity(reduceSearchMotion ? 1 - min(searchOffset / searchWidth, 1) : 1)
            .allowsHitTesting(searchReturn == .idle)
    }

    private func openSavedDrafts() {
        guard workspace.savedDraftShortcutCount > 0, !workspace.saving else { return }
        if workspace.savedDraftShortcutCount == 1, let record = workspace.activeSavedDrafts.first {
            workspace.resumeSavedDraft(record.id)
        } else {
            showingSavedDrafts = true
        }
    }

    private var savedDraftPicker: some View {
        NavigationStack {
            Group {
                if workspace.privacyCovered { ReceiptLockScreen() }
                else if workspace.activeSavedDrafts.isEmpty {
                    ContentUnavailableView("No drafts to review", systemImage: "checkmark.circle")
                } else {
                    List(workspace.activeSavedDrafts) { record in
                        Button {
                            chosenSavedDraft = record.id
                            showingSavedDrafts = false
                        } label: {
                            ReceiptSummary(record: record, showsReviewStatus: false)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("savedDraft-" + record.id.uuidString)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Needs review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingSavedDrafts = false } }
            }
        }
        .dynamicTypeSize(typeSize)
    }
    @ViewBuilder private var debugControls: some View {
        #if DEBUG
        WorkflowTestControls(workspace: workspace)
        #endif
    }
}

private struct ReceiptSearchBackGesture: UIViewRepresentable {
    let isEnabled: Bool
    let action: (UIPanGestureRecognizer) -> Void

    func makeUIView(context: Context) -> Surface { Surface() }

    func updateUIView(_ view: Surface, context: Context) {
        view.action = action
        view.edgePan.isEnabled = isEnabled
    }

    static func dismantleUIView(_ view: Surface, coordinator: ()) { view.detachGesture() }

    final class Surface: UIView, UIGestureRecognizerDelegate {
        var action: ((UIPanGestureRecognizer) -> Void)?
        lazy var edgePan: UIPanGestureRecognizer = {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handleEdgePan))
            recognizer.maximumNumberOfTouches = 1
            recognizer.delegate = self
            return recognizer
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            // Attach above the List's own recognizers so touches at the screen edge reach Back.
            if edgePan.view !== window {
                detachGesture()
                window?.addGestureRecognizer(edgePan)
            }
        }

        func detachGesture() { edgePan.view?.removeGestureRecognizer(edgePan) }

        @objc private func handleEdgePan() { action?(edgePan) }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let window else { return false }
            let position = touch.location(in: window)
            let localY = touch.location(in: self).y
            return (0...20).contains(position.x) && (bounds.minY...bounds.maxY).contains(localY)
        }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let velocity = edgePan.velocity(in: window)
            return velocity.x > abs(velocity.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other is UIPanGestureRecognizer && !(other is UIScreenEdgePanGestureRecognizer)
        }
    }
}

/// Illustration only: no fake receipt data or competing action.
struct WalletInformationView: View {
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
                Section("Unfinished work") {
                    Text("Use Continue import for a photo you haven’t saved yet. Find saved drafts under Needs review. Save edits to existing receipts before leaving the app.")
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
    var showsReviewStatus = true
    @Environment(\.dynamicTypeSize) private var typeSize
    private var total: String {
        record.current.fields.total.map { "\($0.currency.code) \(ExactInput.format($0.minorUnits, scale: $0.currency.minorUnitScale))" } ?? "Total missing"
    }
    private var merchant: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.current.fields.merchant ?? "Merchant missing").font(.headline).fixedSize(horizontal: false, vertical: true)
            Text(ExactInput.dateText(record.current.fields.purchaseDate).nilIfEmpty ?? "Date missing").font(.footnote).foregroundStyle(.secondary)
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
            if showsReviewStatus && !ReceiptCompletion.isComplete(record) {
                Label("Needs review", systemImage: "exclamationmark.circle").font(.caption.weight(.medium))
            }
        }.foregroundStyle(.primary).accessibilityElement(children: .combine)
    }
}
