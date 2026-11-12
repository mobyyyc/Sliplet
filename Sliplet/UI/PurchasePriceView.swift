import SwiftUI

struct PurchasePriceView: View {
    @Bindable var workspace: ReceiptWorkspace
    let first: PurchaseEndpoint
    let second: PurchaseEndpoint
    @State private var evidence = PurchasePriceEvidence()
    @State private var checked = false
    @State private var loaded = false
    @State private var editingVerification = false
    @State private var message: String?

    var body: some View {
        Group {
            if !workspace.active || workspace.privacyCovered {
                ContentUnavailableView("Wallet locked", systemImage: "lock")
            } else if let a = workspace.receipts.first(where: { $0.id == first.receiptID }),
                      let b = workspace.receipts.first(where: { $0.id == second.receiptID }),
                      let left = a.current.fields.items.first(where: { $0.id == first.lineID }),
                      let right = b.current.fields.items.first(where: { $0.id == second.lineID }) {
                let decision = PurchaseLinkEngine.decision(a, line: left.id, b, line: right.id)
                let saved = decision?.first.endpoint == first ? decision?.priceEvidence : decision?.priceEvidence?.reversed
                let comparison = Result { try PurchasePriceComparison.compare(a, line: left.id, b, line: right.id, evidence: evidence) }
                Form {
                    if let saved, let result = try? PurchasePriceComparison.compare(a, line: left.id, b, line: right.id, evidence: saved) {
                        Section("Saved comparison") {
                            resultDetails(result, identifier: "savedUnitPriceResult")
                        }
                    }
                    if saved != nil && !editingVerification {
                        Section {
                            Button("Edit verification") { editingVerification = true }
                                .accessibilityIdentifier("editPriceEvidence")
                        }
                    } else {
                        if let saved {
                            Section {
                                Button("Cancel editing") {
                                    evidence = saved
                                    checked = false
                                    editingVerification = false
                                }.accessibilityIdentifier("cancelPriceEvidenceEdit")
                            }
                        }
                        Section("This purchase") {
                            Text(left.paperName)
                            if a.current.fields.adjustments.contains(where: { $0.kind == .discount }) {
                                Text("This receipt has separate discounts. They are excluded from this comparison.").font(.footnote)
                            }
                            choices(basis: $evidence.firstBasis, unit: $evidence.firstUnit, line: left, prefix: "firstPrice")
                            NavigationLink("Check original") { PurchaseOriginalView(workspace: workspace, receiptID: a.id) }
                        }
                        Section("Other purchase") {
                            Text(right.paperName)
                            if b.current.fields.adjustments.contains(where: { $0.kind == .discount }) {
                                Text("This receipt has separate discounts. They are excluded from this comparison.").font(.footnote)
                            }
                            choices(basis: $evidence.secondBasis, unit: $evidence.secondUnit, line: right, prefix: "secondPrice")
                            NavigationLink("Check original") { PurchaseOriginalView(workspace: workspace, receiptID: b.id) }
                        }
                        Section {
                            Picker("Both row prices", selection: $evidence.tax) {
                                ForEach(PurchasePriceEvidence.Tax.allCases, id: \.self) { Text($0.title).tag($0) }
                            }.accessibilityIdentifier("priceTaxBasis")
                            Toggle("I checked both prices, units and tax basis against the originals", isOn: $checked)
                                .tint(.green).accessibilityIdentifier("priceEvidenceChecked")
                        } footer: {
                            Text("Choose Each only when the quantities count identical packs. Choose a weight or volume unit only when the receipt supports it.")
                        }
                        Section("Comparison") {
                            switch comparison {
                            case .success(let result):
                                if saved == evidence {
                                    Text("These choices match the saved comparison.").font(.subheadline)
                                } else {
                                    if checked {
                                        resultDetails(result, identifier: "unitPriceResult")
                                    } else {
                                        Text("Check the originals to show the comparison.")
                                    }
                                    Button("Save price verification") { save(a, b, value: evidence) }
                                        .buttonStyle(ReceiptProminentStyle()).disabled(!checked)
                                        .accessibilityIdentifier("savePriceEvidence")
                                }
                            case .failure(let error):
                                Text(error.localizedDescription).accessibilityIdentifier("priceUnavailable")
                            }
                        }
                    }
                    if saved != nil || workspace.saving || message != nil {
                        Section {
                            if saved != nil {
                                Button("Clear price verification", role: .destructive) { save(a, b, value: nil) }
                                    .accessibilityIdentifier("clearPriceEvidence")
                            }
                            if workspace.saving { ProgressView("Saving verification") }
                            if let message { Text(message).font(.footnote) }
                        }
                    }
                    Section {
                        DisclosureGroup("How prices are compared") {
                            Text("Calculated unit prices divide the line total by the quantity. Separately listed discounts, fees and taxes are excluded. Discounts already included in the line total are reflected in the calculated price.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(workspace.saving)
                .onAppear {
                    guard !loaded else { return }
                    evidence = saved ?? PurchasePriceEvidence(firstBasis: (left.unitPrice?.minorUnits ?? 0) > 0 ? .printed : .calculated,
                        secondBasis: (right.unitPrice?.minorUnits ?? 0) > 0 ? .printed : .calculated,
                        firstUnit: .printed(left.unit), secondUnit: .printed(right.unit))
                    loaded = true
                }
                .onChange(of: evidence) { _, _ in checked = false; message = nil }
            } else { ContentUnavailableView("Purchase unavailable", systemImage: "doc.questionmark") }
        }.navigationTitle("Compare unit prices").navigationBarTitleDisplayMode(.inline)
    }

    private func resultDetails(_ result: PurchasePriceComparison.Result, identifier: String) -> some View {
        Group {
            Text(result.summary).font(.headline).accessibilityIdentifier(identifier)
            LabeledContent("This purchase", value: result.first.formatted)
            LabeledContent("Other purchase", value: result.second.formatted)
            Text(result.tax.title).font(.caption)
            if result.first.formatted.hasPrefix("≈") || result.second.formatted.hasPrefix("≈") {
                Text("≈ marks a rounded display price. The comparison uses exact values.").font(.footnote)
            }
        }
    }

    private func choices(basis: Binding<PurchasePriceEvidence.Basis>, unit: Binding<PurchasePriceEvidence.Unit>,
                         line: ReceiptLine, prefix: String) -> some View {
        Group {
            LabeledContent("Line total", value: line.amount.map(moneyText) ?? "Missing")
            LabeledContent("Printed unit price", value: line.unitPrice.map(moneyText) ?? "Missing")
            LabeledContent("Quantity", value: line.quantity.map { ExactInput.quantity($0) } ?? "Unknown")
            Picker("Price source", selection: basis) {
                ForEach(PurchasePriceEvidence.Basis.allCases, id: \.self) { Text($0.title).tag($0) }
            }.accessibilityIdentifier(prefix + "Basis")
            Picker("Price per", selection: unit) {
                ForEach(PurchasePriceEvidence.Unit.allCases, id: \.self) { Text($0.title).tag($0) }
            }.accessibilityIdentifier(prefix + "Unit")
        }
    }

    private func moneyText(_ amount: ReceiptMoney) -> String {
        "\(amount.currency.code) \(ExactInput.format(amount.minorUnits, scale: amount.currency.minorUnitScale))"
    }

    private func save(_ a: ReceiptRecord, _ b: ReceiptRecord, value: PurchasePriceEvidence?) {
        Task {
            do {
                try await workspace.savePurchaseDecision(first: a, line: first.lineID, second: b, line: second.lineID,
                    verdict: .sameProduct, pack: .same, priceEvidence: value)
                checked = false
                editingVerification = false
                message = value == nil ? "Price verification cleared." : "Price verification saved."
            } catch is CancellationError { }
            catch { message = error.localizedDescription }
        }
    }
}
