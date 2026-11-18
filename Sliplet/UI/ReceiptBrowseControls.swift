import SwiftUI

extension ReceiptHistoryChoice {
    func title(missing: String) -> String {
        switch self { case .all: "All"; case .missing: missing; case .value(let value): value }
    }
    var monthTitle: String {
        switch self { case .all: "All months"; case .missing: "Date unavailable"; case .value(let value): ReceiptHistory.monthTitle(value) }
    }
}

struct ReceiptCollectionMenu: View {
    @Bindable var workspace: ReceiptWorkspace
    var body: some View {
        Menu {
            ForEach(["All receipts", "Needs review", "Starred", "Archive"], id: \.self) { collection in
                Button {
                    workspace.showCollection(collection)
                } label: {
                    if workspace.collection == collection { Label(collection, systemImage: "checkmark") }
                    else { Text(collection) }
                }.accessibilityIdentifier("collection-" + collection)
            }
        } label: {
            HStack(spacing: 5) { Text(workspace.collection).lineLimit(1); Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)) }
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44).contentShape(Rectangle())
        }.accessibilityLabel("Receipt collection").accessibilityValue(workspace.collection)
            .accessibilityIdentifier("receiptCollections")
    }
}

struct ReceiptBrowseFiltersView: View {
    @Bindable var workspace: ReceiptWorkspace
    @State private var merchant: ReceiptHistoryChoice
    @State private var month: ReceiptHistoryChoice
    @State private var archived: Bool
    @Environment(\.dismiss) private var dismiss
    init(workspace: ReceiptWorkspace) {
        self.workspace = workspace
        _merchant = State(initialValue: workspace.merchantFilter)
        _month = State(initialValue: workspace.monthFilter)
        _archived = State(initialValue: workspace.includeArchived)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Store", selection: $merchant) {
                        Text("All stores").tag(ReceiptHistoryChoice.all)
                        ForEach(workspace.browseMerchants, id: \.self) { Text($0).tag(ReceiptHistoryChoice.value($0)) }
                        if case .value(let selected) = merchant, !workspace.browseMerchants.contains(selected) { Text(selected).tag(merchant) }
                        if merchant == .missing || workspace.receipts.contains(where: { $0.current.fields.merchant == nil }) {
                            Text("Merchant missing").tag(ReceiptHistoryChoice.missing)
                        }
                    }.accessibilityIdentifier("searchMerchantFilter")
                    Picker("Month", selection: $month) {
                        Text("All months").tag(ReceiptHistoryChoice.all)
                        ForEach(workspace.browseMonths, id: \.self) { Text(ReceiptHistory.monthTitle($0)).tag(ReceiptHistoryChoice.value($0)) }
                        if case .value(let selected) = month, !workspace.browseMonths.contains(selected) { Text(ReceiptHistory.monthTitle(selected)).tag(month) }
                        if month == .missing || workspace.receipts.contains(where: { $0.current.fields.purchaseDate == nil }) {
                            Text("Date unavailable").tag(ReceiptHistoryChoice.missing)
                        }
                    }.accessibilityIdentifier("searchMonthFilter")
                    if workspace.collection != "Archive" {
                        Toggle("Include archived", isOn: $archived).tint(.green).accessibilityIdentifier("searchIncludeArchived")
                    }
                }
                Section {
                    Button("Reset filters") { merchant = .all; month = .all; archived = false }
                        .accessibilityIdentifier("resetSearchFilterDraft")
                }
            }
            .navigationTitle("Filters").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        workspace.applyBrowseFilters(merchant: merchant, month: month, archived: archived)
                        dismiss()
                    }.accessibilityIdentifier("applySearchFilters")
                }
            }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

/// Native search hides navigation toolbar items while the query is active.
/// Keep browsing controls in its descendant safe-area bar during that state.
struct ReceiptSearchScopeBar: View {
    @Bindable var workspace: ReceiptWorkspace
    @Environment(\.isSearching) private var isSearching
    var body: some View {
        if isSearching {
            HStack(spacing: 12) {
                ReceiptCollectionMenu(workspace: workspace)
                    .buttonStyle(ReceiptSecondaryStyle())
                Spacer(minLength: 8)
                Button { workspace.searchFiltersExpanded = true } label: {
                    Image(systemName: workspace.merchantFilter != .all || workspace.monthFilter != .all || (workspace.includeArchived && workspace.collection != "Archive")
                          ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                        .font(.system(size: 20, weight: .medium))
                }
                .buttonStyle(ReceiptSecondaryStyle(circular: true))
                .accessibilityLabel("Filters").accessibilityIdentifier("searchFilters")
            }.padding(.horizontal, 20).padding(.vertical, 4)
        }
    }
}
