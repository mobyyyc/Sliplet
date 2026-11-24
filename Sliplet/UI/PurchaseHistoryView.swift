import SwiftUI

struct PurchaseHistoryView: View {
    @Bindable var workspace: ReceiptWorkspace
    let endpoint: PurchaseEndpoint

    var body: some View {
        Group {
            if !workspace.active || workspace.privacyCovered {
                ContentUnavailableView("Wallet locked", systemImage: "lock")
            } else if let record = workspace.receipts.first(where: { $0.id == endpoint.receiptID }),
                      let item = record.current.fields.items.first(where: { $0.id == endpoint.lineID }) {
                let current = PurchaseHistoryEntry(record: record, line: item)
                let entries = PurchaseHistoryEntry.entries(for: endpoint, in: workspace.receipts)
                List {
                    Section {
                        PurchaseHistoryRow(purchase: current)
                            .accessibilityIdentifier("currentHistoryPurchase")
                        if !entries.isEmpty {
                            NavigationLink {
                                PurchaseComparisonPicker(workspace: workspace, endpoint: endpoint)
                            } label: {
                                Label("Compare prices", systemImage: "arrow.left.arrow.right")
                                    .frame(minHeight: 44)
                            }
                            .accessibilityIdentifier("compareUnitPrices")
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 16) {
                            PurchaseItemHeading(name: item.paperName, code: item.sku)
                                .foregroundStyle(Color(uiColor: .label))
                            Text("This purchase")
                        }
                        .textCase(nil)
                    }
                    if entries.isEmpty {
                        ContentUnavailableView("No other purchases found", systemImage: "clock",
                            description: Text("Matching items from your saved receipts appear here automatically."))
                            .listRowBackground(Color.clear)
                    } else {
                        Section {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    PurchaseReceiptView(workspace: workspace, purchase: entry.id)
                                } label: {
                                    PurchaseHistoryRow(purchase: entry, comparisonSaved: entry.hasSavedComparison(with: current))
                                }
                                .accessibilityIdentifier("purchaseHistoryEntry-" + entry.line.id.uuidString)
                            }
                        } header: {
                            Text("Other purchases")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
                .accessibilityIdentifier("purchaseHistory")
            } else {
                ContentUnavailableView("Item unavailable", systemImage: "doc.questionmark")
            }
        }
        .navigationTitle("Purchase history")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PurchaseComparisonPicker: View {
    @Bindable var workspace: ReceiptWorkspace
    let endpoint: PurchaseEndpoint

    var body: some View {
        Group {
            if !workspace.active || workspace.privacyCovered {
                ContentUnavailableView("Wallet locked", systemImage: "lock")
            } else if let record = workspace.receipts.first(where: { $0.id == endpoint.receiptID }),
                      let line = record.current.fields.items.first(where: { $0.id == endpoint.lineID }) {
                let current = PurchaseHistoryEntry(record: record, line: line)
                let entries = PurchaseHistoryEntry.entries(for: endpoint, in: workspace.receipts)
                if entries.isEmpty {
                    ContentUnavailableView("No other purchases found", systemImage: "clock")
                } else {
                    List {
                        Section("Choose a purchase") {
                            ForEach(entries) { entry in
                                if let reason = entry.comparisonBlocker(with: current) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        PurchaseHistoryRow(purchase: entry)
                                        Text(reason).font(.footnote).foregroundStyle(.secondary)
                                    }
                                    .padding(.bottom, 5)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("historyUnavailableComparison-" + entry.line.id.uuidString)
                                } else {
                                    NavigationLink {
                                        PurchasePriceView(workspace: workspace, first: endpoint, second: entry.id)
                                    } label: {
                                        PurchaseHistoryRow(purchase: entry, comparisonSaved: entry.hasSavedComparison(with: current))
                                    }
                                    .accessibilityIdentifier("historyComparePurchase-" + entry.line.id.uuidString)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollEdgeEffectStyle(.soft, for: .vertical)
                }
            } else {
                ContentUnavailableView("Item unavailable", systemImage: "doc.questionmark")
            }
        }
        .navigationTitle("Compare prices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension PurchaseHistoryEntry {
    func comparisonBlocker(with current: Self) -> String? {
        if let decision = PurchaseLinkEngine.decision(current.record, line: current.line.id, record, line: line.id),
           decision.pack == .different || decision.verdict == .differentProduct {
            return "These purchases are marked as different."
        }
        return PurchasePriceComparison.priceBlocker(current.record, line: current.line, record, line: line)
    }

    func hasSavedComparison(with current: Self) -> Bool {
        guard let evidence = PurchasePriceComparison.savedEvidence(current.record, line: current.line.id, record, line: line.id) else {
            return false
        }
        return (try? PurchasePriceComparison.compare(current.record, line: current.line.id, record, line: line.id, evidence: evidence)) != nil
    }
}

private struct PurchaseHistoryRow: View {
    let purchase: PurchaseHistoryEntry
    var comparisonSaved = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let record = purchase.record
        let line = purchase.line
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.current.fields.merchant ?? "Unknown merchant").font(.body.weight(.medium))
                Text(PurchasePresentation.date(record.current.fields.purchaseDate))
                    .font(.subheadline).foregroundStyle(.secondary)
                if !ReceiptCompletion.isComplete(record) {
                    Text("Needs review").font(.caption).foregroundStyle(.secondary)
                }
                if comparisonSaved {
                    Label("Comparison saved", systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
                Text(line.amount.map(PurchasePresentation.price) ?? "Line total unavailable")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .accessibilityLabel(line.amount.map { "Line total, " + PurchasePresentation.price($0) } ?? "Line total unavailable")
                if let rate = PurchasePresentation.recordedUnitPrice(line) {
                    Text(rate).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        .accessibilityLabel(rate.hasPrefix("Unit price") ? rate : "Unit price, " + rate)
                        .accessibilityIdentifier("historyRecordedUnitPrice")
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 5)
        .frame(minHeight: 44)
    }

}

struct PurchaseItemHeading: View {
    let name: String
    let code: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
            if let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                Text(code).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    .accessibilityLabel("Item code \(code)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum PurchasePresentation {
    static func date(_ value: ReceiptDate?) -> String {
        guard let value,
              let date = ReceiptDateSelection.calendar().date(from: DateComponents(
                year: value.year, month: value.month, day: value.day, hour: 12))
        else { return "Date unavailable" }
        return date.formatted(.dateTime.year().month(.abbreviated).day())
    }

    static func recordedUnitPrice(_ line: ReceiptLine) -> String? {
        guard let value = line.unitPrice else { return nil }
        let unit = line.unit?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        return unit == nil ? "Unit price " + price(value) : price(value) + " / " + line.paperPriceUnit
    }

    static func price(_ value: ReceiptMoney) -> String {
        let amount = Decimal(value.minorUnits) / pow(Decimal(10), Int(value.currency.minorUnitScale))
        return amount.formatted(.currency(code: value.currency.code).presentation(.isoCode)
            .precision(.fractionLength(Int(value.currency.minorUnitScale))))
    }
}

private struct PurchaseReceiptView: View {
    @Bindable var workspace: ReceiptWorkspace
    let purchase: PurchaseEndpoint
    @State private var positioned = false
    @State private var sharingReceipt = false

    var body: some View {
        Group {
            if !workspace.active || workspace.privacyCovered {
                ContentUnavailableView("Wallet locked", systemImage: "lock")
            } else if let record = workspace.receipts.first(where: { $0.id == purchase.receiptID }) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if record.isArchived { Label("Archived", systemImage: "archivebox") }
                            if !ReceiptCompletion.isComplete(record) { Label("Needs review", systemImage: "exclamationmark.circle") }
                            ReceiptPaper(fields: record.current.fields, reviewed: ReceiptCompletion.isComplete(record),
                                         taxedMarkers: record.original.paperTaxedMarkers, highlightedLineID: purchase.lineID)
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 24)
                    }
                    .scrollClipDisabled()
                    .scrollEdgeEffectStyle(.soft, for: .vertical)
                    .accessibilityIdentifier("purchaseReceipt")
                    .onAppear {
                        guard !positioned else { return }
                        positioned = true
                        proxy.scrollTo(purchase.lineID, anchor: .center)
                    }
                }
                .background { AtmosphericBackground().ignoresSafeArea() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink("Original") { PurchaseOriginalView(workspace: workspace, receiptID: record.id) }
                            .accessibilityIdentifier("historyReceiptOriginal")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ReceiptShareButton(identifier: "historyOpenReceiptShare") { sharingReceipt = true }
                    }
                }
                .sheet(isPresented: $sharingReceipt) {
                    ReceiptShareView(workspace: workspace, receiptID: purchase.receiptID)
                }
            } else {
                ContentUnavailableView("Receipt unavailable", systemImage: "doc.questionmark")
            }
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PurchaseOriginalView: View {
    @Bindable var workspace: ReceiptWorkspace
    let receiptID: UUID
    @State private var image: ReceiptImage?
    @State private var failed = false
    @State private var zoomTarget = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if !workspace.active || workspace.privacyCovered {
                ContentUnavailableView("Original locked", systemImage: "lock")
            } else if let image {
                VStack {
                    ZoomReceiptImage(bytes: image.bytes, boxes: [], reduceMotion: reduceMotion,
                                     zoomTarget: zoomTarget, rasterID: "purchaseOriginalRaster")
                    ReceiptSourceZoomControls(target: zoomTarget, prefix: "purchaseOriginal").padding()
                }
            } else if failed {
                ContentUnavailableView("Original unavailable", systemImage: "doc.questionmark")
            } else { ProgressView("Loading original") }
        }
        .navigationTitle("Original").navigationBarTitleDisplayMode(.inline)
        .task(id: workspace.active && !workspace.privacyCovered ? workspace.sessionID : nil) {
            image = nil
            failed = false
            guard workspace.active, !workspace.privacyCovered else { return }
            do {
                let original = try await workspace.purchaseOriginal(id: receiptID)
                try Task.checkCancellation()
                image = original
            } catch is CancellationError { }
            catch { if !Task.isCancelled { failed = true } }
        }
        .onDisappear { image = nil }
    }
}
