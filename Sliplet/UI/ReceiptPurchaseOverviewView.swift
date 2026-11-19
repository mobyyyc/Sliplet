import SwiftUI

@MainActor @Observable final class ReceiptOverviewNavigation: Identifiable {
    enum Destination: Hashable {
        case month(String)
        case merchant(String, String)
        case needsReview
        case undated

        var title: String {
            switch self {
            case .month: "Receipts"
            case .merchant(_, let name): name
            case .needsReview: "Needs review"
            case .undated: "Date unavailable"
            }
        }
    }

    let id = UUID()
    var month: String
    var path: [Destination] = []
    var receiptPosition: UUID?
    var overview: ReceiptPurchaseOverview?
    var loadedRevision: Int?

    init(month: String) {
        self.month = month
    }
}

struct ReceiptPurchaseOverviewView: View {
    @Bindable var navigation: ReceiptOverviewNavigation
    let records: [ReceiptRecord]
    let revision: Int
    let openReceipt: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $navigation.path) {
            Group {
                if navigation.loadedRevision == revision, let overview = navigation.overview {
                    summary(overview)
                } else {
                    ProgressView("Preparing purchase overview")
                }
            }
            .navigationTitle("Purchase overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("closePurchaseOverview")
                }
            }
            .navigationDestination(for: ReceiptOverviewNavigation.Destination.self) { destination in
                if navigation.loadedRevision == revision, let overview = navigation.overview {
                    receiptList(entries(in: overview, for: destination), title: destination.title)
                } else {
                    ProgressView("Loading receipts")
                        .navigationTitle(destination.title)
                }
            }
        }
        .task(id: revision) {
            guard navigation.loadedRevision != revision else { return }
            let computation = Task.detached(priority: .userInitiated) { [records] in
                ReceiptPurchaseOverview(records: records)
            }
            let result = await withTaskCancellationHandler {
                await computation.value
            } onCancel: {
                computation.cancel()
            }
            if !Task.isCancelled {
                navigation.overview = result
                navigation.loadedRevision = revision
            }
        }
        .onChange(of: navigation.path) { _, path in
            if path.isEmpty { navigation.receiptPosition = nil }
        }
        .tint(.primary)
    }

    private func summary(_ overview: ReceiptPurchaseOverview) -> some View {
        let month = overview.months[navigation.month] ?? .init()
        return List {
            Section {
                Picker("Month", selection: $navigation.month) {
                    ForEach(Set(overview.monthKeys + [navigation.month]).sorted(by: >), id: \.self) { key in
                        Text(ReceiptHistory.monthTitle(key)).tag(key)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("purchaseOverviewMonth")
            }

            if month.currencies.isEmpty {
                ContentUnavailableView("No reviewed receipts", systemImage: "doc.text",
                                       description: Text("Finished receipts for this month appear here."))
                    .listRowBackground(Color.clear)
            }

            ForEach(month.currencies.keys.sorted(), id: \.self) { code in
                if let currency = month.currencies[code] {
                    Section {
                        NavigationLink(value: ReceiptOverviewNavigation.Destination.month(code)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Net spending").font(.subheadline).foregroundStyle(.secondary)
                                Text(currency.all.amount(currency: code))
                                    .font(.largeTitle.weight(.semibold).monospacedDigit())
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(receiptCount(currency.all.count)).font(.footnote).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                        }
                        .accessibilityIdentifier("purchaseOverviewTotal-" + code)
                    }
                    Section("By merchant · \(code)") {
                        ForEach(currency.merchantsBySpending, id: \.self) { name in
                            if let merchant = currency.merchants[name] {
                                NavigationLink(value: ReceiptOverviewNavigation.Destination.merchant(code, name)) {
                                    ViewThatFits(in: .horizontal) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(name).lineLimit(1).fixedSize()
                                            Spacer(minLength: 12)
                                            Text(merchant.amount(currency: code)).monospacedDigit().fixedSize()
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(name)
                                            Text(merchant.amount(currency: code)).monospacedDigit()
                                        }
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                                .accessibilityIdentifier("purchaseOverviewMerchant-" + code + "-" + name)
                            }
                        }
                    }
                }
            }

            if !month.needsReview.isEmpty || !overview.undated.isEmpty {
                Section("Excluded from totals") {
                    if !month.needsReview.isEmpty {
                        NavigationLink(value: ReceiptOverviewNavigation.Destination.needsReview) {
                            LabeledContent("Needs review", value: String(month.needsReview.count))
                        }.accessibilityIdentifier("purchaseOverviewNeedsReview")
                    }
                    if !overview.undated.isEmpty {
                        NavigationLink(value: ReceiptOverviewNavigation.Destination.undated) {
                            LabeledContent("Date unavailable", value: String(overview.undated.count))
                        }.accessibilityIdentifier("purchaseOverviewUndated")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func entries(in overview: ReceiptPurchaseOverview, for destination: ReceiptOverviewNavigation.Destination)
        -> [ReceiptPurchaseOverview.Entry] {
        let month = overview.months[navigation.month]
        switch destination {
        case .month(let code): return month?.currencies[code]?.all.entries ?? []
        case .merchant(let code, let name): return month?.currencies[code]?.merchants[name]?.entries ?? []
        case .needsReview: return month?.needsReview ?? []
        case .undated: return overview.undated
        }
    }

    private func receiptList(_ entries: [ReceiptPurchaseOverview.Entry], title: String) -> some View {
        ScrollView {
            if entries.isEmpty {
                ContentUnavailableView("No receipts here", systemImage: "doc.text")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(entries) { entry in
                        Button { openReceipt(entry.id) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ReceiptSummary(record: entry.record)
                                if entry.isDuplicate {
                                    Text("Duplicate copy · excluded").font(.caption).foregroundStyle(.secondary)
                                } else if ReceiptCompletion.isComplete(entry.record),
                                          let total = entry.record.current.fields.total, total.minorUnits < 0 {
                                    Text("Refund").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                            .contentShape(.rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .id(entry.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("purchaseOverviewReceipt-" + entry.id.uuidString)
                    }
                }
                .scrollTargetLayout()
                .padding(20)
            }
        }
        .scrollPosition(id: $navigation.receiptPosition, anchor: .top)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func receiptCount(_ count: Int) -> String {
        count == 1 ? "1 receipt" : "\(count) receipts"
    }
}
