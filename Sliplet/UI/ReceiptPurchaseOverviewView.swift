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
    var showingCopies = false
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
                    drillDown(destination, overview: overview)
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
            if path.isEmpty {
                navigation.receiptPosition = nil
                navigation.showingCopies = false
            }
        }
        .tint(.primary)
    }

    private func summary(_ overview: ReceiptPurchaseOverview) -> some View {
        let month = overview.months[navigation.month] ?? .init()
        return List {
            Section {
                monthPicker(overview.monthKeys)
            }

            if month.currencies.isEmpty {
                Text("No reviewed receipts this month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                        .accessibilityHint("Shows the receipts included in this total")
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
                                .accessibilityHint("Shows the receipts for this merchant")
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

    private func monthPicker(_ months: [String]) -> some View {
        let title = ReceiptHistory.monthTitle(navigation.month)
        return Menu {
            Picker("Month", selection: $navigation.month) {
                ForEach(Set(months + [navigation.month]).sorted(by: >), id: \.self) { key in
                    Text(ReceiptHistory.monthTitle(key)).tag(key)
                }
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Text("Month").fixedSize()
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Text(title)
                        Image(systemName: "chevron.up.chevron.down").accessibilityHidden(true)
                    }
                    .fixedSize()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Month").font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(title)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Month")
        .accessibilityValue(title)
        .accessibilityIdentifier("purchaseOverviewMonth")
    }

    @ViewBuilder private func drillDown(_ destination: ReceiptOverviewNavigation.Destination, overview: ReceiptPurchaseOverview) -> some View {
        let month = overview.months[navigation.month]
        switch destination {
        case .month(let code):
            let summary = month?.currencies[code]?.all ?? .init()
            receiptList(summary.entries, copies: summary.copies, title: destination.title, period: true, amount: summary.amount(currency: code))
        case .merchant(let code, let name):
            let summary = month?.currencies[code]?.merchants[name] ?? .init()
            receiptList(summary.entries, copies: summary.copies, title: destination.title, period: true, amount: summary.amount(currency: code))
        case .needsReview:
            receiptList(month?.needsReview ?? [], title: destination.title, period: true)
        case .undated:
            receiptList(overview.undated, title: destination.title, period: false)
        }
    }

    private func receiptList(_ entries: [ReceiptPurchaseOverview.Entry], copies: [ReceiptPurchaseOverview.Entry] = [],
                             title: String, period: Bool, amount: String? = nil) -> some View {
        ScrollView {
            if entries.isEmpty {
                ContentUnavailableView("No receipts here", systemImage: "doc.text")
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    if period {
                        Text(ReceiptHistory.monthTitle(navigation.month)).font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("purchaseOverviewDrillMonth")
                    }
                    if let amount {
                        Text(amount).font(.title2.weight(.semibold).monospacedDigit())
                            .accessibilityLabel("Net spending, \(amount)")
                    }
                    Text(receiptCount(entries.count)).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
                .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)

                LazyVStack(spacing: 10) {
                    ForEach(entries, content: receiptRow)
                    if !copies.isEmpty {
                        Button {
                            navigation.showingCopies.toggle()
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(copies.count == 1 ? "1 duplicate copy" : "\(copies.count) duplicate copies")
                                        .font(.subheadline.weight(.medium))
                                    Text("Excluded from totals").font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: navigation.showingCopies ? "chevron.up" : "chevron.down")
                                    .font(.subheadline.weight(.semibold)).accessibilityHidden(true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(navigation.showingCopies ? "Expanded" : "Collapsed")
                        .accessibilityIdentifier("purchaseOverviewCopies")
                        if navigation.showingCopies {
                            ForEach(copies, content: receiptRow)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
        }
        .scrollPosition(id: $navigation.receiptPosition, anchor: .top)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("purchaseOverviewReceiptList")
    }

    private func receiptRow(_ entry: ReceiptPurchaseOverview.Entry) -> some View {
        Button { openReceipt(entry.id) } label: {
            VStack(alignment: .leading, spacing: 6) {
                ReceiptSummary(record: entry.record)
                if entry.isDuplicate {
                    Text("Duplicate copy").font(.caption).foregroundStyle(.secondary)
                } else if let total = entry.record.current.fields.total, total.minorUnits < 0, ReceiptCompletion.isComplete(entry.record) {
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

    private func receiptCount(_ count: Int) -> String {
        count == 1 ? "1 receipt" : "\(count) receipts"
    }
}
