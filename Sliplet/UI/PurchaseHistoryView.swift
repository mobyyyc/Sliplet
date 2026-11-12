import SwiftUI

struct PurchaseHistoryView: View {
    @Bindable var workspace: ReceiptWorkspace
    let endpoint: PurchaseEndpoint
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if !workspace.active || workspace.privacyCovered {
                ContentUnavailableView("Wallet locked", systemImage: "lock")
            } else if let record = workspace.receipts.first(where: { $0.id == endpoint.receiptID }),
                      let item = record.current.fields.items.first(where: { $0.id == endpoint.lineID }) {
                let entries = PurchaseHistoryEntry.entries(for: endpoint, in: workspace.receipts)
                List {
                    Section {
                        PurchaseItemHeading(name: item.paperName, code: item.sku)
                            .listRowInsets(EdgeInsets(top: 12, leading: 4, bottom: 12, trailing: 4))
                            .listRowBackground(Color.clear)
                    }
                    if entries.isEmpty {
                        ContentUnavailableView("No other purchases found", systemImage: "clock",
                            description: Text("Matching items from your saved receipts appear here automatically."))
                            .listRowBackground(Color.clear)
                    } else {
                        Section {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    PurchaseReceiptView(workspace: workspace, source: endpoint, purchase: entry.id)
                                } label: {
                                    purchaseRow(entry)
                                }
                                .accessibilityIdentifier("purchaseHistoryEntry-" + entry.line.id.uuidString)
                            }
                        } header: {
                            Text("Other purchases")
                        } footer: {
                            Text("Prices are receipt line totals.")
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

    private func purchaseRow(_ entry: PurchaseHistoryEntry) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.record.current.fields.merchant ?? "Unknown merchant").font(.body.weight(.medium))
                Text(PurchasePresentation.date(entry.record.current.fields.purchaseDate))
                    .font(.subheadline).foregroundStyle(.secondary)
                if !ReceiptCompletion.isComplete(entry.record) {
                    Text("Needs review").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.line.amount.map(PurchasePresentation.price) ?? "Price unavailable")
                .font(.body.weight(.semibold).monospacedDigit())
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

    static func price(_ value: ReceiptMoney) -> String {
        let amount = Decimal(value.minorUnits) / pow(Decimal(10), Int(value.currency.minorUnitScale))
        return amount.formatted(.currency(code: value.currency.code).presentation(.isoCode)
            .precision(.fractionLength(Int(value.currency.minorUnitScale))))
    }
}

private struct PurchaseReceiptView: View {
    @Bindable var workspace: ReceiptWorkspace
    let source: PurchaseEndpoint
    let purchase: PurchaseEndpoint
    @State private var positioned = false
    @State private var comparingPrices = false

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
                    if let a = workspace.receipts.first(where: { $0.id == source.receiptID }),
                       let left = a.current.fields.items.first(where: { $0.id == source.lineID }),
                       let right = record.current.fields.items.first(where: { $0.id == purchase.lineID }),
                       PurchasePriceComparison.setupBlocker(a, line: left, record, line: right) == nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu("More", systemImage: "ellipsis") {
                                Button("Compare unit prices") { comparingPrices = true }
                                    .accessibilityIdentifier("compareUnitPrices")
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Receipt unavailable", systemImage: "doc.questionmark")
            }
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $comparingPrices) {
            PurchasePriceView(workspace: workspace, first: source, second: purchase)
        }
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
