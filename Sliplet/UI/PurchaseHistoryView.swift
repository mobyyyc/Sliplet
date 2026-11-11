import SwiftUI

struct PurchaseHistoryView: View {
    @Bindable var workspace: ReceiptWorkspace
    let endpoint: PurchaseEndpoint

    var body: some View {
        Group {
            if !workspace.active || workspace.privacyCovered {
                ContentUnavailableView("Wallet locked", systemImage: "lock")
            } else {
                let entries = PurchaseHistoryEntry.entries(for: endpoint, in: workspace.receipts)
                List {
                    Section {
                        Text("\(entries.count) other \(entries.count == 1 ? "purchase" : "purchases")")
                            .font(.headline).accessibilityIdentifier("purchaseHistoryCount")
                        Text("Newest first within each match group.").font(.caption).foregroundStyle(.secondary)
                        DisclosureGroup("About matches and amounts") {
                            Text("Possible matches are suggestions, not confirmed products. Compare the originals before linking purchases.")
                            Text("Amounts are printed line totals, not unit prices. Quantity, discounts and tax can change what you paid.")
                        }.font(.subheadline)
                    }
                    if entries.isEmpty {
                        ContentUnavailableView("No other purchases found", systemImage: "clock",
                            description: Text("Saved receipts with matching store codes or descriptions will appear here."))
                    }
                    ForEach(PurchaseHistoryEntry.Status.allCases, id: \.self) { status in
                        let group = entries.filter { $0.status == status }
                        if !group.isEmpty {
                            Section(status.rawValue) {
                                ForEach(group) { entry in
                                    NavigationLink {
                                        PurchaseComparisonView(workspace: workspace, first: endpoint, second: entry.id)
                                    } label: {
                                        PurchaseHistoryRow(record: entry.record, line: entry.line)
                                    }.accessibilityIdentifier("purchaseHistoryEntry-" + entry.line.id.uuidString)
                                }
                            }
                        }
                    }
                }.accessibilityIdentifier("purchaseHistory")
            }
        }
        .navigationTitle("Purchase history").navigationBarTitleDisplayMode(.inline)
    }
}

private struct PurchaseHistoryRow: View {
    let record: ReceiptRecord
    let line: ReceiptLine
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(line.description ?? "Description missing").font(.headline)
            Text(record.current.fields.merchant ?? "Merchant missing")
            Text(ExactInput.dateText(record.current.fields.purchaseDate).nilIfEmpty ?? "Date missing")
                .font(.subheadline)
            Text(line.amount.map { "Line total · \($0.currency.code) \(ExactInput.format($0.minorUnits, scale: $0.currency.minorUnitScale))" }
                 ?? "Amount missing").monospacedDigit()
            if record.isArchived { Label("Archived", systemImage: "archivebox").font(.caption) }
            if !ReceiptCompletion.isComplete(record) { Label("Needs review", systemImage: "exclamationmark.circle").font(.caption) }
        }.padding(.vertical, 4)
    }
}

private struct PurchaseComparisonView: View {
    @Bindable var workspace: ReceiptWorkspace
    let first: PurchaseEndpoint
    let second: PurchaseEndpoint
    @State private var pack = PurchaseLinkDecision.Pack.unknown
    @State private var loadedPack = false
    @State private var error: String?
    private var a: ReceiptRecord? { workspace.receipts.first { $0.id == first.receiptID } }
    private var b: ReceiptRecord? { workspace.receipts.first { $0.id == second.receiptID } }

    var body: some View {
        Group {
            if !workspace.active || workspace.privacyCovered {
                ContentUnavailableView("Wallet locked", systemImage: "lock")
            } else if let a, let b,
                      let left = a.current.fields.items.first(where: { $0.id == first.lineID }),
                      let right = b.current.fields.items.first(where: { $0.id == second.lineID }) {
                let decision = PurchaseLinkEngine.decision(a, line: left.id, b, line: right.id)
                let previous = (a.purchaseLinks?.decisions ?? []) + (b.purchaseLinks?.decisions ?? [])
                Form {
                    purchase(a, line: left, title: "This purchase", identifier: "historyFirst")
                    purchase(b, line: right, title: "Other purchase", identifier: "historySecond")
                    Section {
                        if let decision {
                            Label(decision.verdict == .sameProduct ? "Same product confirmed" : "Marked as different products",
                                  systemImage: decision.verdict == .sameProduct ? "checkmark.circle" : "minus.circle")
                                .accessibilityIdentifier("purchaseDecisionStatus")
                            Text(packLabel(decision.pack)).font(.subheadline)
                        } else {
                            Text(previous.contains { $0.connects(first, second) }
                                 ? "A receipt or link changed. Compare both originals before confirming again."
                                 : "This is a possible match. Compare the descriptions, codes and pack sizes.")
                        }
                        Picker("Pack size or variant", selection: $pack) {
                            Text("Unknown").tag(PurchaseLinkDecision.Pack.unknown)
                            Text("Same").tag(PurchaseLinkDecision.Pack.same)
                            Text("Different").tag(PurchaseLinkDecision.Pack.different)
                        }.accessibilityIdentifier("purchasePack")
                        Button("Confirm same product") { save(a, b, verdict: .sameProduct) }
                            .buttonStyle(ReceiptProminentStyle())
                            .accessibilityIdentifier("confirmPurchaseLink")
                        Button("Different products") { save(a, b, verdict: .differentProduct) }
                            .buttonStyle(ReceiptSecondaryStyle())
                            .accessibilityIdentifier("rejectPurchaseLink")
                        if workspace.saving { ProgressView("Saving decision") }
                        if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("purchaseLinkError") }
                    } header: { Text("Product match") }
                    footer: { Text("Confirming links these two purchases. It does not establish a price change.") }
                    if previous.contains(where: { $0.connects(first, second) }) {
                        Section("Saved decision") {
                            Button("Undo match decision", role: .destructive) { save(a, b, verdict: nil) }
                                .accessibilityIdentifier("undoPurchaseLink")
                        }
                    }
                    Section {
                        NavigationLink("Compare unit prices") {
                            PurchasePriceView(workspace: workspace, first: first, second: second)
                        }.accessibilityIdentifier("compareUnitPrices")
                    }
                }
                .disabled(workspace.saving)
                .onAppear { if !loadedPack { pack = decision?.pack ?? .unknown; loadedPack = true } }
            } else {
                ContentUnavailableView("Purchase unavailable", systemImage: "doc.questionmark",
                    description: Text("This receipt or item was removed. Return to purchase history."))
            }
        }.navigationTitle("Compare purchases").navigationBarTitleDisplayMode(.inline)
    }

    private func packLabel(_ value: PurchaseLinkDecision.Pack) -> String {
        switch value {
        case .same: "Same pack size or variant"
        case .different: "Different pack size or variant"
        case .unknown: "Pack size or variant unknown"
        }
    }

    private func purchase(_ record: ReceiptRecord, line: ReceiptLine, title: String, identifier: String) -> some View {
        Section(title) {
            PurchaseHistoryRow(record: record, line: line)
            if let code = line.sku { LabeledContent("Printed code", value: code) }
            if let quantity = line.quantity { LabeledContent("Quantity", value: ExactInput.quantity(quantity)) }
            if let unit = line.unit { LabeledContent("Unit", value: unit) }
            if let price = line.unitPrice {
                LabeledContent("Unit price", value: "\(price.currency.code) \(ExactInput.format(price.minorUnits, scale: price.currency.minorUnitScale))")
            }
            NavigationLink("View receipt") { PurchaseReceiptView(workspace: workspace, receiptID: record.id) }
                .accessibilityIdentifier(identifier + "Receipt")
            NavigationLink("View original") { PurchaseOriginalView(workspace: workspace, receiptID: record.id) }
                .accessibilityIdentifier(identifier + "Original")
        }
    }

    private func save(_ a: ReceiptRecord, _ b: ReceiptRecord, verdict: PurchaseLinkDecision.Verdict?) {
        error = nil
        Task {
            do {
                try await workspace.savePurchaseDecision(first: a, line: first.lineID, second: b, line: second.lineID,
                                                          verdict: verdict, pack: pack)
            } catch is CancellationError { }
            catch {
                if workspace.active && !workspace.privacyCovered {
                    self.error = "Could not save this decision. Return to history and try again."
                }
            }
        }
    }
}

private struct PurchaseReceiptView: View {
    @Bindable var workspace: ReceiptWorkspace
    let receiptID: UUID
    var body: some View {
        Group {
            if !workspace.active || workspace.privacyCovered {
                ContentUnavailableView("Wallet locked", systemImage: "lock")
            } else if let record = workspace.receipts.first(where: { $0.id == receiptID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if record.isArchived { Label("Archived", systemImage: "archivebox") }
                        if !ReceiptCompletion.isComplete(record) { Label("Needs review", systemImage: "exclamationmark.circle") }
                        ReceiptPaper(fields: record.current.fields, reviewed: ReceiptCompletion.isComplete(record))
                    }.padding(24)
                }.background { AtmosphericBackground().ignoresSafeArea() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink("Original") { PurchaseOriginalView(workspace: workspace, receiptID: receiptID) }
                    }
                }
            } else { ContentUnavailableView("Receipt unavailable", systemImage: "doc.questionmark") }
        }.navigationTitle("Receipt").navigationBarTitleDisplayMode(.inline)
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
        .task(id: workspace.sessionID) {
            image = nil; failed = false
            do { image = try await workspace.purchaseOriginal(id: receiptID) }
            catch is CancellationError { }
            catch { failed = true }
        }
        .onChange(of: workspace.privacyCovered) { _, covered in if covered { image = nil } }
        .onDisappear { image = nil }
    }
}
