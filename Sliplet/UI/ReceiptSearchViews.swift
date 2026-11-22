import SwiftUI

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

struct ReceiptPurchaseHistoryView: View {
    @Bindable var workspace: ReceiptWorkspace
    var openSettings: () -> Void
    var openOverview: (String?) -> Void
    var requestDelete: (ReceiptRecord) -> Void
    @State private var rowFrames: [String: CGRect] = [:]
    @State private var pendingRestore: ReceiptBrowsingAnchor?
    @State private var userScrolled = false
    @State private var scrollAccess = ReceiptListScrollAccess()
    @State private var viewportHeight: CGFloat = 1
    init(workspace: ReceiptWorkspace, openSettings: @escaping () -> Void = {},
         openOverview: @escaping (String?) -> Void, requestDelete: @escaping (ReceiptRecord) -> Void) {
        self.workspace = workspace; self.openSettings = openSettings; self.openOverview = openOverview
        self.requestDelete = requestDelete
        _pendingRestore = State(initialValue: workspace.browseAnchor)
    }
    private var hasFilters: Bool { workspace.hasBrowseFilters }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                List {
                    if hasFilters {
                        Section {
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    if workspace.merchantFilter != .all {
                                        filterChip(workspace.merchantFilter.title(missing: "Merchant missing")) {
                                            workspace.merchantFilter = .all
                                        }
                                    }
                                    if workspace.monthFilter != .all {
                                        filterChip(workspace.monthFilter.monthTitle) { workspace.monthFilter = .all }
                                    }
                                    if workspace.includeArchived && workspace.collection != "Archive" {
                                        filterChip("Including archived") { workspace.includeArchived = false }
                                    }
                                    if let title = workspace.browseDateTitle {
                                        filterChip(title) { var filter = workspace.browsingFilter; filter.dateMode = .any; workspace.browsingFilter = filter }
                                    }
                                    if let title = workspace.browseAmountTitle {
                                        filterChip(title) { var filter = workspace.browsingFilter; filter.minimum = ""; filter.maximum = ""; workspace.browsingFilter = filter }
                                    }
                                    if workspace.collection != "All receipts" { Text(workspace.collection).font(.caption) }
                                    Button("Clear filters", action: workspace.resetBrowseFilters)
                                        .font(.caption).accessibilityIdentifier("searchClearFilters")
                                }.padding(.vertical, 2)
                            }.scrollIndicators(.hidden)
                                .accessibilityIdentifier("searchFilterSummary")
                        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    if workspace.browsing.sections.isEmpty {
                        Section {
                            emptyState
                        } header: { resultCount.id("browse-top") }
                    }
                    ForEach(workspace.browsing.sections) { section in
                        Section {
                            ForEach(section.rows) { row in
                                resultRow(row, viewport: geometry.size.height)
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 10) {
                                if section.id == workspace.browsing.sections.first?.id { resultCount.id("browse-top") }
                                sectionHeading(section)
                            }.textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped).listSectionSpacing(16)
                .autocorrectionDisabled().scrollDismissesKeyboard(.interactively)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
                .coordinateSpace(name: "receiptBrowse")
                .opacity(pendingRestore == nil ? 1 : 0)
                .task(id: pendingRestore?.rowID) {
                    guard let pending = pendingRestore else { return }
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled, pendingRestore?.rowID == pending.rowID else { return }
                    // A future native List implementation can still show the stable row if
                    // its backing scroll view is unavailable; never leave a blank surface.
                    pendingRestore = nil
                }
                .onAppear {
                    viewportHeight = geometry.size.height
                    restore(using: proxy)
                }
                .onChange(of: workspace.browseVersion) { _, _ in
                    if workspace.flow == .wallet {
                        if workspace.browseAnchor == nil {
                            pendingRestore = nil; scrollAccess.scrollToStart()
                            proxy.scrollTo("browse-top", anchor: .top)
                        } else { restore(using: proxy) }
                    }
                }
                .onScrollPhaseChange { _, phase in
                    if phase == .tracking || phase == .interacting { userScrolled = true; pendingRestore = nil }
                    guard phase == .idle, userScrolled, pendingRestore == nil, workspace.flow == .wallet else { return }
                    userScrolled = false
                    let first = rowFrames.filter { $0.value.minY >= scrollAccess.visibleTop && $0.value.minY < viewportHeight }
                        .min { $0.value.minY < $1.value.minY }
                    if let first, let index = workspace.browsing.indexByID[first.key] {
                        remember(workspace.browsing.rows[index], viewport: viewportHeight)
                    }
                }
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if workspace.hasArchivedSearchMatch {
            VStack(spacing: 16) {
                Label("Matches in archive", systemImage: "archivebox")
                    .labelStyle(.titleAndIcon)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Button("Include archived") { workspace.includeArchived = true }
                    .buttonStyle(ReceiptSecondaryStyle())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("includeArchivedSearchMatches")
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ContentUnavailableView(workspace.searchQuery.isEmpty ? "No receipts here" : "No matches",
                systemImage: workspace.searchQuery.isEmpty ? "doc.text" : "magnifyingglass",
                description: Text(workspace.searchQuery.count > 512 ? "Use a shorter search." : hasFilters ? "Try clearing a filter or changing your search." : "Try a merchant, item or item code."))
        }
    }

    @ViewBuilder private func sectionHeading(_ section: ReceiptBrowsingSnapshot.Section) -> some View {
        if !workspace.searching, let record = section.rows.first?.record {
            let month = ReceiptHistory.monthKey(record)
            Button { openOverview(month) } label: {
                HStack(spacing: 7) {
                    Text(section.title)
                    Image(systemName: "chart.bar").font(.caption).accessibilityHidden(true)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(month == nil ? "Shows receipts awaiting a purchase date" : "Opens the purchase overview for this month")
            .accessibilityIdentifier("listOverview-" + section.id)
        } else {
            Text(section.title).font(.subheadline.weight(.medium)).foregroundStyle(Color(uiColor: .label))
        }
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
        guard let anchor = pendingRestore, let frame = rowFrames[anchor.rowID], frame.maxY > 0 else { return }
        if scrollAccess.align(row: frame, to: anchor.y) { pendingRestore = nil }
    }
    private func remember(_ row: ReceiptBrowsingSnapshot.Row, viewport: CGFloat) {
        let frame = rowFrames[row.id] ?? .zero
        workspace.browseAnchor = ReceiptBrowsingAnchor(rowID: row.id, receiptID: row.record.id, y: frame.minY)
        workspace.searchReturnID = row.id
    }
    private func filterChip(_ title: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 5) { Text(title); Image(systemName: "xmark").font(.caption2) }
                .font(.caption).padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: .capsule)
        }.buttonStyle(.plain).accessibilityLabel("Remove filter: " + title)
    }
    private func resultRow(_ row: ReceiptBrowsingSnapshot.Row, viewport: CGFloat) -> some View {
        Button {
            remember(row, viewport: viewport)
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
            if frame.maxY >= -80 && frame.minY <= viewport + 80 { rowFrames[row.id] = frame }
            else { rowFrames.removeValue(forKey: row.id) }
            if pendingRestore?.rowID == row.id { completeRestore() }
        }
        .onDisappear { rowFrames.removeValue(forKey: row.id) }
        .receiptSwipeActions(row.record, identifier: row.identifier) { action in
            remember(row, viewport: viewport)
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
