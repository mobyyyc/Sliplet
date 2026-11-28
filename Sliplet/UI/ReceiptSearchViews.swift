import SwiftUI

/// Wait for native navigation to finish before allowing the keyboard to resize the search page.
struct SearchScreenAppearance: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> Observer { Observer() }

    func updateUIViewController(_ controller: Observer, context: Context) {
        controller.action = action
    }

    final class Observer: UIViewController {
        var action: (() -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            action?()
        }
    }
}

/// History opens a reading surface directly; only the home wallet lifts a paper from its stack.
struct ReceiptSearchDetailView: View {
    @Bindable var workspace: ReceiptWorkspace
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var revealed = false
    private var reduceMotion: Bool { ReceiptAccessibility.reduceMotion(systemReduceMotion) }

    var body: some View {
        ScrollView {
            if let record = workspace.selected {
                VStack(alignment: .leading, spacing: 20) {
                    if let match = workspace.searchMatch,
                       match.basis != .merchant || match.matchedText != record.current.fields.merchant {
                        ReceiptSearchContext(workspace: workspace, match: match)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top) {
                            if !ReceiptCompletion.isComplete(record) { Label("Needs review", systemImage: "exclamationmark.circle") }
                            Spacer()
                            if record.isStarred { Image(systemName: "star.fill").accessibilityLabel("Starred") }
                        }.font(.footnote.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                        ReceiptPaper(fields: record.current.fields,
                                     input: workspace.readerInput, reviewed: ReceiptCompletion.isComplete(record),
                                     taxedMarkers: record.original.paperTaxedMarkers, highlightedLineID: workspace.searchMatch?.originalOnly == false ? workspace.searchMatch?.itemID : nil, editLine: { workspace.openDetailLine($0) })
                        VStack(alignment: .leading, spacing: 18) {
                            if workspace.image == nil && workspace.errorMessage == nil { ProgressView("Loading original").font(.footnote) }
                            if let error = workspace.errorMessage { Text(error).font(.subheadline) }
                            if record.current.fields.currency == nil { Text("Currency needs confirmation. Edit to check the saved amounts.").font(.footnote) }
                        }
                    }
                    .padding(.horizontal, 30)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: reduceMotion || revealed ? 0 : 12)
                }.padding(.top, 12).padding(.bottom, 24)
            }
        }
        // Context and paper share normal scroll layout; there is no fixed search-header occlusion.
        .scrollClipDisabled().scrollEdgeEffectStyle(.soft, for: .vertical)
        .accessibilityIdentifier("detailScreen")
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.22)) { revealed = true }
        }
    }
}

struct ReceiptSearchResultsView: View {
    @Bindable var workspace: ReceiptWorkspace
    var requestDelete: (ReceiptRecord) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var pendingRestore: ReceiptBrowsingAnchor?
    @State private var userScrolled = false
    @State private var scrollAccess = ReceiptListScrollAccess()
    init(workspace: ReceiptWorkspace, requestDelete: @escaping (ReceiptRecord) -> Void) {
        self.workspace = workspace
        self.requestDelete = requestDelete
        _pendingRestore = State(initialValue: workspace.browseAnchor)
    }
    private var isActiveSurface: Bool { workspace.flow == .wallet && workspace.searching }

    var body: some View {
        GeometryReader { geometry in
            let viewportBottom = geometry.frame(in: .global).maxY
            ScrollViewReader { proxy in
                List {
                    if workspace.browsing.sections.isEmpty {
                        Section {
                            emptyState
                        } header: { resultCount.id("browse-top") }
                    }
                    ForEach(workspace.browsing.sections) { section in
                        Section {
                            ForEach(section.rows) { row in
                                resultRow(row, viewportBottom: viewportBottom)
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 10) {
                                if section.id == workspace.browsing.sections.first?.id {
                                    resultCount.id("browse-top")
                                }
                                Text(section.title).font(.subheadline.weight(.medium)).foregroundStyle(Color(uiColor: .label))
                            }.textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped).listSectionSpacing(16)
                .autocorrectionDisabled()
                .scrollDismissesKeyboard(.immediately)
                .scrollBounceBehavior(.always, axes: .vertical)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
                .opacity(pendingRestore == nil ? 1 : 0)
                .task(id: pendingRestore?.rowID) {
                    guard let pending = pendingRestore else { return }
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled, pendingRestore?.rowID == pending.rowID else { return }
                    // A future native List implementation can still show the stable row if
                    // its backing scroll view is unavailable; never leave a blank surface.
                    pendingRestore = nil
                }
                .onAppear { if isActiveSurface { restore(using: proxy) } }
                .onChange(of: workspace.browseVersion) { _, _ in
                    if isActiveSurface {
                        if workspace.browseAnchor == nil {
                            pendingRestore = nil; scrollAccess.scrollToStart()
                            proxy.scrollTo("browse-top", anchor: .top)
                        } else { restore(using: proxy) }
                    }
                }
                .onScrollPhaseChange { _, phase in
                    guard isActiveSurface else { return }
                    if phase == .tracking || phase == .interacting { userScrolled = true; pendingRestore = nil }
                    guard phase == .idle, userScrolled, pendingRestore == nil else { return }
                    userScrolled = false
                    let first = scrollAccess.rowFrames.filter { $0.value.minY >= scrollAccess.visibleTop && $0.value.minY < viewportBottom }
                        .min { $0.value.minY < $1.value.minY }
                    if let first, let index = workspace.browsing.indexByID[first.key] {
                        remember(workspace.browsing.rows[index])
                    }
                }
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if workspace.hasArchivedSearchMatch {
            searchRecovery(title: "Matches in archive", symbol: "archivebox",
                           button: "Include archived", identifier: "includeArchivedSearchMatches") {
                workspace.includeArchived = true
            }
        } else if workspace.hasMatchOutsidePurchaseFilters {
            searchRecovery(title: typeSize.isAccessibilitySize ? nil : "Matches outside filters",
                           symbol: "line.3.horizontal.decrease.circle",
                           button: "Clear purchase filters", identifier: "clearSearchPurchaseFilters",
                           hint: "Matches exist outside your store, date and total filters. Clears those filters.",
                           action: workspace.clearPurchaseFiltersForSearch)
        } else {
            let hasQuery = !workspace.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ContentUnavailableView(hasQuery ? "No matches" : "No receipts here",
                systemImage: hasQuery ? "magnifyingglass" : "doc.text",
                description: Text(workspace.searchQuery.count > 512 ? "Use a shorter search." :
                    hasQuery ? "Try a different merchant, item or item code." :
                    workspace.hasBrowseFilters ? "Try clearing a filter." : "Try a merchant, item or item code."))
        }
    }

    private func searchRecovery(title: String?, symbol: String, button: String, identifier: String,
                                hint: String = "", action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            if let title {
                Label(title, systemImage: symbol)
                    .labelStyle(.titleAndIcon)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            Button(button, action: action)
                .buttonStyle(ReceiptSecondaryStyle())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHint(hint)
                .accessibilityIdentifier(identifier)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, title == nil ? 8 : 24)
    }

    private var resultCount: some View {
        Text("\(workspace.browsing.receiptCount) \(workspace.browsing.receiptCount == 1 ? "receipt" : "receipts")")
            .font(.caption).foregroundStyle(Color(uiColor: .secondaryLabel)).accessibilityIdentifier("searchResultCount")
    }
    private func restore(using proxy: ScrollViewProxy) {
        guard let anchor = workspace.browseAnchor, workspace.browsing.indexByID[anchor.rowID] != nil else { return }
        pendingRestore = anchor
        proxy.scrollTo(anchor.rowID, anchor: .center)
        completeRestore()
    }
    private func completeRestore() {
        guard let anchor = pendingRestore, let frame = scrollAccess.rowFrames[anchor.rowID], frame.maxY > 0 else { return }
        if scrollAccess.align(row: frame, to: anchor.y) { pendingRestore = nil }
    }
    private func remember(_ row: ReceiptBrowsingSnapshot.Row) {
        let frame = scrollAccess.rowFrames[row.id] ?? .zero
        workspace.browseAnchor = ReceiptBrowsingAnchor(rowID: row.id, receiptID: row.record.id, y: frame.minY)
        workspace.searchReturnID = row.id
    }
    private func resultRow(_ row: ReceiptBrowsingSnapshot.Row, viewportBottom: CGFloat) -> some View {
        Button {
            remember(row)
            workspace.open(row.record, match: row.match)
        } label: {
            Group {
                if let match = row.match, match.basis != .merchant { ItemSearchResultLabel(match: match, record: row.record) }
                else {
                    VStack(alignment: .leading, spacing: 4) {
                        ReceiptSummary(record: row.record)
                        if let match = row.match, match.matchedText != row.record.current.fields.merchant {
                            Text("Original name: " + match.matchedText).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 6).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle()).accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain).accessibilityIdentifier(row.identifier).id(row.id)
        .background {
            ReceiptListScrollProbe { scroll in
                scrollAccess.view = scroll
                DispatchQueue.main.async { completeRestore() }
            }.frame(width: 0, height: 0).accessibilityHidden(true).allowsHitTesting(false)
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            if frame.maxY >= -80 && frame.minY <= viewportBottom + 80 { scrollAccess.rowFrames[row.id] = frame }
            else { scrollAccess.rowFrames.removeValue(forKey: row.id) }
            if pendingRestore?.rowID == row.id { completeRestore() }
        }
        .onDisappear { scrollAccess.rowFrames.removeValue(forKey: row.id) }
        .receiptSwipeActions(row.record, identifier: row.identifier) { action in
            remember(row)
            if action == .delete { requestDelete(row.record) }
            else { workspace.organize(row.record, action: action) }
        }
    }
}

private struct ItemSearchResultLabel: View {
    let match: ReceiptSearchIndex.Match
    let record: ReceiptRecord
    @Environment(\.dynamicTypeSize) private var typeSize

    private var item: ReceiptLine? {
        record.current.fields.items.first { $0.id == match.itemID }
    }

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        VStack(alignment: .leading, spacing: 6) {
            layout {
                Text(record.current.fields.merchant ?? "Merchant missing")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let item {
                    if let amount = item.amount {
                        Text(PurchasePresentation.price(amount))
                            .font(.headline.monospacedDigit())
                            .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: false)
                    } else {
                        Text("Price unavailable").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            Text(item?.paperName ?? match.title)
                .font(.subheadline)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            Text(PurchasePresentation.date(record.current.fields.purchaseDate))
                .font(.caption).foregroundStyle(.secondary)
            if record.isArchived {
                Label("Archived", systemImage: "archivebox").font(.caption).foregroundStyle(.secondary)
            }
            if match.originalOnly {
                Label("Original text only", systemImage: "doc.text.magnifyingglass")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ReceiptSearchMatchLabel: View {
    let match: ReceiptSearchIndex.Match
    let record: ReceiptRecord
    private var item: ReceiptLine? { record.current.fields.items.first { $0.id == match.itemID } }
    private var evidenceTitle: String {
        switch match.basis {
        case .sku: "Matched code"
        case .originalSKU: "Original code"
        case .original, .rawText: "Original text"
        case .merchant: "Merchant name"
        case .corrected: "Matched text"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                PurchaseItemHeading(name: item?.paperName ?? match.title, code: item?.sku)
                if let amount = item?.amount {
                    Text(PurchasePresentation.price(amount)).font(.title2.weight(.semibold).monospacedDigit())
                }
                if match.originalOnly {
                    Label("Original text only", systemImage: "doc.text.magnifyingglass").font(.subheadline).foregroundStyle(.secondary)
                    Text(match.unparsed ? "This text is not linked to a current item." : "This item is no longer in the edited receipt.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if match.matchedText != (item?.paperName ?? match.title) || [.sku, .originalSKU, .original, .rawText].contains(match.basis) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(evidenceTitle).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Text(match.matchedText).font(.body).fixedSize(horizontal: false, vertical: true)
                }
            }
        }.foregroundStyle(.primary)
    }
}

struct ReceiptSearchContext: View {
    @Bindable var workspace: ReceiptWorkspace
    let match: ReceiptSearchIndex.Match
    @State private var details = false
    @State private var history = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var dismissButton: some View {
        Button { workspace.searchMatch = nil } label: { Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
            .buttonStyle(.plain).accessibilityLabel("Dismiss match")
    }
    private var originalButton: some View {
        Button { workspace.showSource(ids: match.sourceLineIDs) } label: {
            Label("Original", systemImage: "doc.viewfinder")
        }.buttonStyle(ReceiptSecondaryStyle()).accessibilityLabel("View matched original")
            .disabled(workspace.image == nil).accessibilityIdentifier("searchOriginal")
    }

    @ViewBuilder private func historyButton(_ record: ReceiptRecord) -> some View {
        if !match.originalOnly, let itemID = match.itemID, record.current.fields.items.contains(where: { $0.id == itemID }) {
            Button("Purchase history", systemImage: "clock.arrow.circlepath") { history = true }
                .buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("searchPurchaseHistory")
        }
    }
    var body: some View {
        if let record = workspace.selected {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.current.fields.items.first(where: { $0.id == match.itemID })?.paperName ?? match.title).font(.subheadline.weight(.semibold)).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        if match.originalOnly { Text("Original text only").font(.caption).foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Button { details = true } label: { Image(systemName: "info.circle").frame(width: 44, height: 44) }
                        .buttonStyle(.plain).accessibilityLabel("Match details").accessibilityIdentifier("searchMatchDetails")
                    dismissButton
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { originalButton; historyButton(record) }.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 8) { originalButton; historyButton(record) }
                }
            }.padding(.horizontal, 20).padding(.bottom, 10)
                .sheet(isPresented: $history) {
                    if let itemID = match.itemID {
                        NavigationStack {
                            PurchaseHistoryView(workspace: workspace,
                                endpoint: PurchaseEndpoint(receiptID: record.id, lineID: itemID))
                            .toolbar { ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { history = false }.accessibilityIdentifier("closePurchaseHistory")
                            } }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .sheet(isPresented: $details) {
                    NavigationStack {
                        ScrollView { ReceiptSearchMatchLabel(match: match, record: record).padding(24).frame(maxWidth: .infinity, alignment: .leading) }
                            .navigationTitle("Match details").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { details = false } } }
                    }
                }
        }
    }
}
