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
                    if let match = workspace.searchMatch {
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
                                     taxedMarkers: record.original.paperTaxedMarkers, editLine: { workspace.openDetailLine($0) })
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
    var requestDelete: (ReceiptRecord) -> Void
    private var hasFilters: Bool {
        workspace.collection != "All receipts" || workspace.includeArchived || workspace.merchantFilter != .all || workspace.monthFilter != .all
    }
    private var filterSummary: String {
        var parts = [workspace.collection]
        if workspace.collection != "Archive" { parts.append(workspace.includeArchived ? "Including archived" : "Active only") }
        switch workspace.merchantFilter {
        case .all: break
        case .missing: parts.append("Merchant missing")
        case .value(let value): parts.append(value)
        }
        switch workspace.monthFilter {
        case .all: break
        case .missing: parts.append("Date missing")
        case .value(let value): parts.append(ReceiptHistory.monthTitle(value))
        }
        return parts.joined(separator: " · ")
    }
    private var results: [ReceiptSearchIndex.Result] {
        workspace.searchIndex.results(query: workspace.searchQuery, collection: workspace.collection,
            includeArchived: workspace.includeArchived, merchant: workspace.merchantFilter, month: workspace.monthFilter)
    }
    private var merchants: [String] { Array(Set(workspace.receipts.compactMap { $0.current.fields.merchant })).sorted() }
    private var months: [String] { Array(Set(workspace.receipts.compactMap(ReceiptHistory.monthKey))).sorted(by: >) }
    var body: some View {
        let found = results
        let groups = Dictionary(grouping: found) { ReceiptHistory.monthKey($0.record) ?? "" }
        ScrollViewReader { proxy in
            List {
                Section {
                    Button {
                        workspace.searchFiltersExpanded.toggle()
                    } label: {
                        HStack {
                            Label("Filters", systemImage: "line.3.horizontal.decrease")
                            Spacer()
                            Image(systemName: workspace.searchFiltersExpanded ? "chevron.up" : "chevron.down")
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("searchFilters")
                        .accessibilityValue(workspace.searchFiltersExpanded ? "Expanded" : "Collapsed")
                    if workspace.searchFiltersExpanded {
                        Picker("Collection", selection: $workspace.collection) {
                            Text("All receipts").tag("All receipts"); Text("Starred").tag("Starred"); Text("Archive").tag("Archive")
                        }.accessibilityIdentifier("collectionPicker")
                        Picker("Store", selection: $workspace.merchantFilter) {
                            Text("All stores").tag(ReceiptHistoryChoice.all)
                            ForEach(merchants, id: \.self) { Text($0).tag(ReceiptHistoryChoice.value($0)) }
                            if workspace.receipts.contains(where: { $0.current.fields.merchant == nil }) { Text("Merchant missing").tag(ReceiptHistoryChoice.missing) }
                        }.accessibilityIdentifier("searchMerchantFilter")
                        Picker("Month", selection: $workspace.monthFilter) {
                            Text("All months").tag(ReceiptHistoryChoice.all)
                            ForEach(months, id: \.self) { Text(ReceiptHistory.monthTitle($0)).tag(ReceiptHistoryChoice.value($0)) }
                            if workspace.receipts.contains(where: { $0.current.fields.purchaseDate == nil }) { Text("Date missing").tag(ReceiptHistoryChoice.missing) }
                        }.accessibilityIdentifier("searchMonthFilter")
                        if workspace.collection != "Archive" {
                            Toggle("Include archived", isOn: $workspace.includeArchived).tint(.green).accessibilityIdentifier("searchIncludeArchived")
                        }
                    }
                    Text(filterSummary).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("searchFilterSummary")
                    if hasFilters {
                        Button("Reset filters") {
                            workspace.collection = "All receipts"; workspace.includeArchived = false
                            workspace.merchantFilter = .all; workspace.monthFilter = .all
                        }.accessibilityIdentifier("searchClearFilters")
                    }
                }
                Section {
                    Text("\(found.count) \(found.count == 1 ? "receipt" : "receipts")")
                        .font(.subheadline).accessibilityIdentifier("searchResultCount")
                    if found.isEmpty {
                        ContentUnavailableView(workspace.searchQuery.isEmpty ? "No receipts here" : "No matching purchases",
                            systemImage: workspace.searchQuery.isEmpty ? "doc.text" : "magnifyingglass",
                            description: Text(workspace.searchQuery.count > 512 ? "Use a shorter search." : "Try another word, SKU or filter. Archive is searchable separately."))
                    }
                }
                ForEach(groups.keys.sorted(by: >), id: \.self) { key in
                    Section {
                        ForEach(groups[key] ?? []) { result in
                            if result.matches.isEmpty || result.matches.first?.basis == .merchant {
                                let merchantMatch = result.matches.first
                                resultRow(record: result.record, match: merchantMatch) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ReceiptSummary(record: result.record)
                                        if let merchantMatch, merchantMatch.matchedText != result.record.current.fields.merchant {
                                            Text("Original merchant: \(merchantMatch.matchedText)").font(.caption).foregroundStyle(.secondary)
                                        }
                                        if result.record.isArchived { Label("Archived", systemImage: "archivebox").font(.caption) }
                                    }
                                }
                            } else {
                                ForEach(result.matches) { match in
                                    resultRow(record: result.record, match: match) {
                                        ItemSearchResultLabel(match: match, record: result.record)
                                    }
                                }
                            }
                        }
                    } header: { Text(ReceiptHistory.monthTitle(key.isEmpty ? nil : key)).foregroundStyle(Color(uiColor: .label)) }
                }
            }
            .searchable(text: $workspace.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Merchant, item or SKU")
            .autocorrectionDisabled()
            .scrollDismissesKeyboard(.interactively)
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .accessibilityIdentifier("receiptLibrary")
            .onAppear {
                if let id = workspace.searchReturnID { proxy.scrollTo(id, anchor: .center) }
            }
            .onChange(of: workspace.searchQuery) { _, _ in workspace.searchReturnID = nil }
            .onChange(of: workspace.collection) { _, _ in workspace.searchReturnID = nil }
            .onChange(of: workspace.includeArchived) { _, _ in workspace.searchReturnID = nil }
            .onChange(of: workspace.merchantFilter) { _, _ in workspace.searchReturnID = nil }
            .onChange(of: workspace.monthFilter) { _, _ in workspace.searchReturnID = nil }
            // Reset only stale filters after a committed edit/deletion. Never replace a missing civil date.
            .onChange(of: merchants) { _, values in
                if case .value(let selected) = workspace.merchantFilter, !values.contains(selected) { workspace.merchantFilter = .all }
                if workspace.merchantFilter == .missing && !workspace.receipts.contains(where: { $0.current.fields.merchant == nil }) { workspace.merchantFilter = .all }
            }
            .onChange(of: months) { _, values in
                if case .value(let selected) = workspace.monthFilter, !values.contains(selected) { workspace.monthFilter = .all }
                if workspace.monthFilter == .missing && !workspace.receipts.contains(where: { $0.current.fields.purchaseDate == nil }) { workspace.monthFilter = .all }
            }
        }
    }
    private func resultRow<Content: View>(record: ReceiptRecord, match: ReceiptSearchIndex.Match?,
                                          @ViewBuilder content: () -> Content) -> some View {
        let itemMatch = match.flatMap { $0.basis == .merchant ? nil : $0 }
        let id = itemMatch.map { "match-" + $0.id } ?? "receipt-" + record.id.uuidString
        let identifier = itemMatch.map { "searchMatch-" + $0.id } ?? "searchReceipt-" + record.id.uuidString
        return Button {
            workspace.searchReturnID = id
            workspace.open(record, match: match)
        } label: {
            content()
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .id(id)
        .receiptSwipeActions(record, identifier: identifier) { action in
            if action == .delete { requestDelete(record) }
            else { workspace.organize(record, action: action) }
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
                Text(match.unparsed ? "Original text · not linked to a current purchase" : "Original extraction · removed from current receipt")
                    .font(.caption).foregroundStyle(.secondary)
            } else if match.basis == .original {
                Text("Original description match").font(.caption).foregroundStyle(.secondary)
            } else if match.basis == .originalSKU {
                Text("Original SKU match").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ReceiptSearchMatchLabel: View {
    let match: ReceiptSearchIndex.Match
    let record: ReceiptRecord
    private var item: ReceiptLine? { record.current.fields.items.first { $0.id == match.itemID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(match.title).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            if match.originalOnly {
                Text(match.unparsed ? "Original text · not linked to a current purchase" : "Original extraction · removed from current receipt").font(.caption)
            } else if let item {
                Text(item.amount.map { "\($0.currency.code) \(ExactInput.format($0.minorUnits, scale: $0.currency.minorUnitScale))" }
                     ?? "Amount missing").font(.subheadline.monospacedDigit())
                if let sku = item.sku { Text("SKU \(sku)").font(.caption) }
            }
            switch match.basis {
            case .original: Text("Original description: \(match.matchedText)").font(.caption)
            case .rawText: Text("Original text: \(match.matchedText)").font(.caption)
            case .originalSKU: Text("Original SKU: \(match.matchedText)").font(.caption)
            case .sku: Text("Matched SKU: \(match.matchedText)").font(.caption)
            case .merchant:
                if match.matchedText != record.current.fields.merchant { Text("Original merchant: \(match.matchedText)").font(.caption) }
            case .corrected: Text("Current purchase description").font(.caption)
            }
        }.foregroundStyle(.primary).accessibilityElement(children: .combine)
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
    private func originalButton(iconOnly: Bool) -> some View {
        Button { workspace.showSource(ids: match.sourceLineIDs) } label: {
            Group {
                if iconOnly { Image(systemName: "doc.viewfinder").frame(minWidth: 44, minHeight: 44) }
                else { Label("View matched original", systemImage: "doc.viewfinder").frame(minHeight: 44) }
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("View matched original").disabled(workspace.image == nil).accessibilityIdentifier("searchOriginal")
    }

    var body: some View {
        if let record = workspace.selected {
            Group {
                if typeSize.isAccessibilitySize {
                    HStack(spacing: 12) {
                        Button { details = true } label: { Text("Match").font(.headline).frame(minHeight: 44).contentShape(Rectangle()) }
                            .buttonStyle(.plain).accessibilityLabel("View search match details").accessibilityValue(match.title).accessibilityIdentifier("searchMatchDetails")
                        Spacer(minLength: 0)
                        originalButton(iconOnly: true)
                        dismissButton
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(match.originalOnly ? "Matched original evidence" : "Search match").font(.caption.weight(.semibold)); Spacer(); dismissButton }
                        Text(match.title).font(.headline).lineLimit(2)
                        Text(match.originalOnly ? "Original evidence only" : "Current receipt match").font(.caption)
                        Button { details = true } label: { Text("Match details").frame(minHeight: 44).contentShape(Rectangle()) }
                            .buttonStyle(.plain).accessibilityIdentifier("searchMatchDetails")
                        originalButton(iconOnly: false)
                    }
                }
                if !match.originalOnly, let itemID = match.itemID,
                   record.current.fields.items.contains(where: { $0.id == itemID }) {
                    Button("Purchase history", systemImage: "clock.arrow.circlepath") { history = true }
                        .buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("searchPurchaseHistory")
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
