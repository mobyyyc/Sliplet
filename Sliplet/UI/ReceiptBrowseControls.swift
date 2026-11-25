import SwiftUI

extension ReceiptHistoryChoice {
    func title(missing: String) -> String {
        switch self { case .all: "All"; case .missing: missing; case .value(let value): value }
    }
    var monthTitle: String {
        switch self { case .all: "All months"; case .missing: "Date unavailable"; case .value(let value): ReceiptHistory.monthTitle(value) }
    }
}

struct ReceiptActiveFiltersBar: View {
    @Bindable var workspace: ReceiptWorkspace
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingFilters = false

    var body: some View {
        let filters = activeFilters
        Group {
            if !filters.isEmpty {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    showingFilters = true
                } label: {
                    HStack(spacing: 10) {
                        Text("Filters (\(filters.count))").fontWeight(.semibold).fixedSize()
                        if !typeSize.isAccessibilitySize {
                            Text(filters.map(\.title).joined(separator: " · "))
                                .foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Active filters")
                .accessibilityValue("\(filters.count): " + filters.map(\.title).joined(separator: ", "))
                .accessibilityHint("Review and remove current filters")
                .accessibilityIdentifier("searchFilterSummary")
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .background(Color(uiColor: .systemGroupedBackground), ignoresSafeAreaEdges: [])
            }
        }
        .sheet(isPresented: $showingFilters) {
            NavigationStack {
                if workspace.active && !workspace.privacyCovered {
                    List(filters) { filter in
                        Button {
                            if filters.count == 1 { showingFilters = false }
                            remove(filter.id)
                        } label: {
                            HStack(spacing: 12) {
                                Text(filter.title).fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Remove filter: " + filter.title)
                    }
                    .listStyle(.insetGrouped)
                    .navigationTitle("Active filters")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingFilters = false }
                        }
                    }
                    .safeAreaBar(edge: .bottom, spacing: 0) {
                        Button("Clear filters") {
                            showingFilters = false
                            workspace.resetBrowseFilters()
                        }
                        .buttonStyle(ReceiptSecondaryStyle())
                        .accessibilityIdentifier("searchClearFilters")
                        .modifier(ReceiptActionBarLayout())
                    }
                } else {
                    ReceiptLockScreen()
                }
            }.dynamicTypeSize(typeSize)
        }
    }

    private struct Filter: Identifiable {
        enum Kind { case collection, merchant, month, date, amount, archive }
        let id: Kind
        let title: String
    }

    private var activeFilters: [Filter] {
        var filters: [Filter] = []
        if workspace.collection != "All receipts" { filters.append(.init(id: .collection, title: workspace.collection)) }
        if workspace.merchantFilter != .all {
            filters.append(.init(id: .merchant, title: workspace.merchantFilter.title(missing: "Merchant missing")))
        }
        if workspace.monthFilter != .all { filters.append(.init(id: .month, title: workspace.monthFilter.monthTitle)) }
        if let date = workspace.browseDateTitle { filters.append(.init(id: .date, title: date)) }
        if let amount = workspace.browseAmountTitle { filters.append(.init(id: .amount, title: amount)) }
        if workspace.includeArchived && workspace.collection != "Archive" {
            filters.append(.init(id: .archive, title: "Including archived"))
        }
        return filters
    }

    private func remove(_ kind: Filter.Kind) {
        switch kind {
        case .collection:
            workspace.applyBrowseFilters(merchant: workspace.merchantFilter, month: workspace.monthFilter,
                archived: workspace.collection != "Archive" && workspace.includeArchived, scope: "All receipts")
        case .merchant:
            workspace.merchantFilter = .all
        case .month:
            var filter = workspace.browsingFilter
            if filter.dateMode == .month { filter.dateMode = .any }
            workspace.applyBrowseFilters(merchant: workspace.merchantFilter, month: .all,
                                        archived: workspace.includeArchived, extra: filter)
        case .date:
            var filter = workspace.browsingFilter
            filter.dateMode = .any
            workspace.browsingFilter = filter
        case .amount:
            var filter = workspace.browsingFilter
            filter.minimum = ""
            filter.maximum = ""
            workspace.browsingFilter = filter
        case .archive:
            workspace.includeArchived = false
        }
    }
}

struct ReceiptBrowseFiltersView: View {
    @Bindable var workspace: ReceiptWorkspace
    @State private var merchant: ReceiptHistoryChoice
    @State private var month: ReceiptHistoryChoice
    @State private var archived: Bool
    @State private var scope: String
    @State private var extra: ReceiptBrowsingFilter
    @Environment(\.dismiss) private var dismiss
    init(workspace: ReceiptWorkspace) {
        self.workspace = workspace
        _merchant = State(initialValue: workspace.merchantFilter)
        _month = State(initialValue: workspace.monthFilter)
        _archived = State(initialValue: workspace.includeArchived)
        _scope = State(initialValue: workspace.collection)
        var filter = workspace.browsingFilter
        if workspace.monthFilter != .all { filter.dateMode = .month }
        _extra = State(initialValue: filter)
    }
    private var currencies: [ReceiptCurrency] {
        workspace.receipts.compactMap { $0.current.fields.total?.currency }.reduce([extra.currency]) { result, currency in
            result.contains(currency) ? result : result + [currency]
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Receipts") {
                    Picker("Collection", selection: $scope) {
                        ForEach(["All receipts", "Needs review", "Starred", "Archive"], id: \.self) { Text($0).tag($0) }
                    }.accessibilityIdentifier("filterCollection")
                    Picker("Store", selection: $merchant) {
                        Text("All stores").tag(ReceiptHistoryChoice.all)
                        ForEach(workspace.browseMerchants, id: \.self) { Text($0).tag(ReceiptHistoryChoice.value($0)) }
                        if case .value(let selected) = merchant, !workspace.browseMerchants.contains(selected) { Text(selected).tag(merchant) }
                        Text("Merchant missing").tag(ReceiptHistoryChoice.missing)
                    }.accessibilityIdentifier("searchMerchantFilter")
                    if scope != "Archive" { Toggle("Include archived", isOn: $archived).tint(.green).accessibilityIdentifier("searchIncludeArchived") }
                }
                Section("Purchase date") {
                    Picker("Date", selection: $extra.dateMode) {
                        ForEach(ReceiptBrowsingFilter.DateMode.allCases) { Text($0.rawValue).tag($0) }
                    }.accessibilityIdentifier("filterDateMode")
                    if extra.dateMode == .month {
                        Picker("Month", selection: $month) {
                            Text("All months").tag(ReceiptHistoryChoice.all)
                            ForEach(workspace.browseMonths, id: \.self) { Text(ReceiptHistory.monthTitle($0)).tag(ReceiptHistoryChoice.value($0)) }
                            if case .value(let selected) = month, !workspace.browseMonths.contains(selected) { Text(ReceiptHistory.monthTitle(selected)).tag(month) }
                            Text("Date unavailable").tag(ReceiptHistoryChoice.missing)
                        }.accessibilityIdentifier("searchMonthFilter")
                    }
                    if extra.dateMode == .day || extra.dateMode == .range {
                        DatePicker(extra.dateMode == .day ? "On" : "From", selection: $extra.start, displayedComponents: .date)
                            .accessibilityIdentifier("filterStartDate")
                    }
                    if extra.dateMode == .range {
                        DatePicker("Through", selection: $extra.end, displayedComponents: .date).accessibilityIdentifier("filterEndDate")
                    }
                }
                Section {
                    Picker("Currency", selection: Binding(get: { extra.currency.code }, set: { code in
                        if let currency = currencies.first(where: { $0.code == code }) { extra.currency = currency }
                    })) {
                        ForEach(currencies, id: \.code) { Text($0.code).tag($0.code) }
                    }.accessibilityIdentifier("filterCurrency")
                    LabeledContent("Minimum") { TextField("No minimum", text: $extra.minimum).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation).accessibilityIdentifier("filterMinimum") }
                    LabeledContent("Maximum") { TextField("No maximum", text: $extra.maximum).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation).accessibilityIdentifier("filterMaximum") }
                } header: { Text("Receipt total") } footer: {
                    if extra.hasAmount { Text("Only \(extra.currency.code) receipts with a recorded total are included.") }
                }
                if let error = extra.validation { Section { Text(error).foregroundStyle(.red) } }
                Section {
                    Button("Reset filters") { merchant = .all; month = .all; archived = false; scope = "All receipts"; extra = ReceiptBrowsingFilter() }
                        .accessibilityIdentifier("resetSearchFilterDraft")
                }
            }
            .navigationTitle("Filters").navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        workspace.applyBrowseFilters(merchant: merchant, month: extra.dateMode == .month ? month : .all,
                            archived: scope == "Archive" ? false : archived, scope: scope, extra: extra)
                        dismiss()
                    }.disabled(extra.validation != nil).accessibilityIdentifier("applySearchFilters")
                }
            }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}
