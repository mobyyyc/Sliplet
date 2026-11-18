import SwiftUI

extension ReceiptHistoryChoice {
    func title(missing: String) -> String {
        switch self { case .all: "All"; case .missing: missing; case .value(let value): value }
    }
    var monthTitle: String {
        switch self { case .all: "All months"; case .missing: "Date unavailable"; case .value(let value): ReceiptHistory.monthTitle(value) }
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
