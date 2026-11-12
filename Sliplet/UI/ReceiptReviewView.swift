import SwiftUI

struct ReceiptReviewView: View {
    @Bindable var workspace: ReceiptWorkspace
    var editing: FocusState<String?>.Binding
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectingDate = false
    @State private var pendingDate = Date()
    @State private var focusedCheck: ReceiptReviewGuidance?
    @State private var allChecks = false
    @State private var showChecked = false
    private var checks: [ReceiptReviewGuidance] { ReceiptReviewGuidance.checks(draft: workspace.draft, extraction: workspace.extraction) }

    private func field(_ key: WritableKeyPath<ReceiptReviewDraft, String>) -> Binding<String> {
        Binding(get: { workspace.draft[keyPath: key] }, set: { value in workspace.updateDraft { $0[keyPath: key] = value } })
    }
    @State private var openedEditor = false
    @State private var hasShownPaper = false

    var body: some View {
        if !openedEditor, workspace.selected == nil, hasShownPaper || workspace.draft.reconciliation.issues.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Tap a line to edit, or compare with Original.").font(.subheadline)
                        Spacer()
                        Button("Edit") { openedEditor = true }
                            .buttonStyle(ReceiptSecondaryStyle()).accessibilityLabel("Edit receipt fields")
                            .accessibilityIdentifier("editReviewFields")
                    }
                    ReceiptPaper(fields: workspace.draft.fields, input: workspace.draft, taxedMarkers: workspace.extraction?.paperTaxedMarkers ?? [], editLine: { id in
                        guard let line = workspace.draft.lines.first(where: { $0.id == id }) else { return }
                        focusedCheck = .forLine(line)
                    })
                    ForEach(checks.filter { !$0.isChecked(in: workspace.draft) }) { check in checkButton(check) }
                    if let error = workspace.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle").accessibilityIdentifier("saveError")
                    }
                }.padding(.horizontal, 20).padding(.vertical, 12)
            }
            .scrollClipDisabled().scrollEdgeEffectStyle(.soft, for: .vertical)
            .onAppear { hasShownPaper = true }
            .sheet(item: $focusedCheck) { ReceiptFocusedCorrectionView(workspace: workspace, check: $0) }
            .accessibilityIdentifier("paperReview")
            .safeAreaBar(edge: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    if let issue = workspace.draft.reconciliation.issues.first {
                        Label(issue, systemImage: "exclamationmark.circle")
                            .font(.footnote).accessibilityIdentifier("paperReviewIssue")
                    }
                    Toggle("I checked the original", isOn: $workspace.draft.sourceChecked)
                    .tint(.green).disabled(!workspace.draft.sourceOpened || workspace.saving)
                    .accessibilityIdentifier("sourceCheck")
                }
                    .padding(.horizontal, 20).padding(.vertical, 8)
            }
        } else {
            editor.onAppear { openedEditor = true }
        }
    }

    private var editor: some View {
        Form {
            Section {
                let pending = checks.filter { !$0.isChecked(in: workspace.draft) }
                ForEach(Array(pending.prefix(allChecks ? pending.count : 3))) { check in
                    checkButton(check)
                }
                if pending.count > 3 {
                    Button(allChecks ? "Show fewer checks" : "Show all \(pending.count) checks") { allChecks.toggle() }
                        .frame(minHeight: 44).accessibilityIdentifier("showAllChecks")
                }
                let checked = checks.filter { $0.isChecked(in: workspace.draft) }
                if !checked.isEmpty {
                    DisclosureGroup("\(checked.count) checked", isExpanded: $showChecked) {
                        ForEach(checked) { check in checkButton(check) }
                    }.accessibilityIdentifier("checkedGuidance")
                }
                if pending.isEmpty { Text("Review every field and purchase against the original.").font(.subheadline) }
            } header: { Text("Check first").foregroundStyle(Color(uiColor: .label)) }
            footer: { Text("These checks can miss errors. Matching totals alone do not establish accuracy.").foregroundStyle(Color(uiColor: .label)) }
            Section {
                LabeledContent("Merchant") { TextField("Required", text: field(\.merchant), axis: typeSize > .large ? .vertical : .horizontal).multilineTextAlignment(.trailing).focused(editing, equals: "merchant").accessibilityIdentifier("merchantField") }
                Button {
                    editing.wrappedValue = nil
                    pendingDate = ReceiptDateSelection.date(workspace.draft.date) ?? Date()
                    selectingDate = true
                } label: {
                    LabeledContent("Date") {
                        if let date = ReceiptDateSelection.date(workspace.draft.date) {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                        } else { Label("Choose date", systemImage: "calendar") }
                    }
                }.foregroundStyle(.primary).accessibilityIdentifier("dateField")
                Picker("Currency", selection: field(\.currency)) {
                    Text("Choose currency").tag("")
                    ForEach(ExactInput.currencies.keys.sorted(), id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("currencyField")
                if let context = workspace.draft.currencyContextMessage {
                    Text(context).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("currencyContext")
                }
            } header: { Text("Receipt").foregroundStyle(Color(uiColor: .label)) }
            footer: { Text("Use printed line amounts. Leave unknown quantities blank.").foregroundStyle(Color(uiColor: .label)) }
            Section {
                ForEach(workspace.draft.lines.filter { $0.kind == "purchase" }) { line in
                    ReceiptLineEditor(workspace: workspace, id: line.id, editing: editing)
                }
                Button("Add purchase", systemImage: "plus") { workspace.updateDraft { $0.lines.append(.blank()) } }
                    .frame(minHeight: 44).accessibilityIdentifier("addPurchase")
            } header: { Text("Items").foregroundStyle(Color(uiColor: .label)) }
            Section {
                LabeledContent("Printed subtotal") {
                    TextField("Missing", text: field(\.subtotal)).keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing).focused(editing, equals: "subtotal").accessibilityIdentifier("subtotalField")
                }
                if workspace.draft.subtotal.isEmpty {
                    Toggle("Subtotal is not printed", isOn: Binding(get: { workspace.draft.subtotalNotPrinted }, set: { value in workspace.updateDraft { $0.subtotalNotPrinted = value } }))
                        .tint(.green).accessibilityIdentifier("subtotalNotPrinted")
                }
            } header: { Text("Subtotal").foregroundStyle(Color(uiColor: .label)) }
            Section {
                ForEach(workspace.draft.lines.filter { $0.kind != "purchase" }) { line in
                    ReceiptLineEditor(workspace: workspace, id: line.id, editing: editing)
                }
                Menu {
                    ForEach(["discount", "tax", "deposit", "tip", "other"], id: \.self) { kind in
                        Button(kind.capitalized) { workspace.updateDraft { $0.lines.append(.blank(kind: kind)) } }
                    }
                } label: { Label("Add adjustment", systemImage: "plus").frame(minHeight: 44) }.accessibilityIdentifier("addAdjustment")
            } header: { Text("Adjustments").foregroundStyle(Color(uiColor: .label)) }
            footer: { Text("Discounts are negative. Enter printed taxes and fees only.").foregroundStyle(Color(uiColor: .label)) }
            Section {
                LabeledContent("Printed total") {
                    TextField("Required to finish", text: field(\.total)).keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing).focused(editing, equals: "total").accessibilityIdentifier("totalField")
                }
                reconciliation
            } header: { Text("Total").foregroundStyle(Color(uiColor: .label)) }
            Section {
                Toggle("I checked the original", isOn: $workspace.draft.sourceChecked)
                    .tint(.green).disabled(!workspace.draft.sourceOpened).accessibilityIdentifier("sourceCheck")
                Text(workspace.draft.sourceOpened ? "Confirm every field and line. Changing receipt values requires confirmation again; the original remains available. Matching totals alone do not prove completeness." : "Open Original above and check every field and line, including anything recognition missed.")
                    .font(.footnote).foregroundStyle(.primary)
            } header: { Text("Source review").foregroundStyle(Color(uiColor: .label)) }
            Section {
                if let error = workspace.errorMessage { Label(error, systemImage: "exclamationmark.triangle").accessibilityIdentifier("saveError") }
                if workspace.saving { ProgressView("Saving locally") }
                if !workspace.draft.canSaveDraft {
                    Text("Choose a valid purchase date and check typed quantities or amounts before saving a draft. Missing fields can remain blank.").font(.footnote)
                }
                Text("Saved on this device. Export an encrypted backup in Settings to keep a restorable copy.")
                    .font(.footnote).foregroundStyle(.primary).accessibilityIdentifier("reviewStorageFooter")
            }

        }.listSectionSpacing(20).scrollDismissesKeyboard(.interactively)
        .scrollClipDisabled().scrollEdgeEffectStyle(.soft, for: .vertical)
        .contentMargins(.bottom, 28, for: .scrollContent)
        .accessibilityIdentifier("reviewScreen")
        .sheet(item: $focusedCheck) { check in
            ReceiptFocusedCorrectionView(workspace: workspace, check: check)
        }
        .sheet(isPresented: $selectingDate) {
            NavigationStack {
                ScrollView {
                    DatePicker("Purchase date", selection: $pendingDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.calendar, ReceiptDateSelection.calendar())
                        .accessibilityIdentifier("receiptDatePicker")
                    if !workspace.draft.date.isEmpty {
                        Button("Clear date", role: .destructive) {
                            workspace.updateDraft { $0.date = "" }; selectingDate = false
                        }.accessibilityIdentifier("clearReceiptDate")
                    }
                }.padding().navigationTitle("Purchase date").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { selectingDate = false }.accessibilityIdentifier("cancelReceiptDate")
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                let date = ReceiptDateSelection.text(pendingDate)
                                workspace.updateDraft { $0.date = date }; selectingDate = false
                            }.accessibilityIdentifier("confirmReceiptDate")
                        }
                    }
            }.presentationDetents([.medium, .large])
        }
    }
    private func checkButton(_ check: ReceiptReviewGuidance) -> some View {
        Button {
            editing.wrappedValue = nil
            focusedCheck = check
        } label: {
            HStack(spacing: 12) {
                Image(systemName: check.isChecked(in: workspace.draft) ? "checkmark.circle" : "doc.text.magnifyingglass")
                VStack(alignment: .leading, spacing: 4) {
                    Text(check.title).font(.body.weight(.medium))
                    Text(check.message).font(.footnote)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption)
            }.foregroundStyle(.primary).frame(minHeight: 44)
        }.buttonStyle(.borderless).accessibilityIdentifier("reviewCheck-" + check.id)
            .accessibilityHint("Opens focused editing and original photo comparison")
    }
    private var reconciliation: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let difference = workspace.draft.reconciliation.difference {
                Label(difference == 0 ? "Line amounts match the total" : "Difference: \(ExactInput.format(difference, scale: ExactInput.currency(workspace.draft.currency)?.minorUnitScale ?? 2)) \(workspace.draft.currency)", systemImage: difference == 0 ? "equal.circle" : "exclamationmark.circle")
                    .font(.headline).accessibilityIdentifier("reconciliation")
            } else { Label("Cannot reconcile yet", systemImage: "questionmark.circle").font(.headline).accessibilityIdentifier("reconciliation") }
            if let note = workspace.draft.reconciliation.subtotalNote { Text(note).font(.footnote).foregroundStyle(.primary) }
            ForEach(workspace.draft.reconciliation.issues, id: \.self) { Text($0).font(.subheadline) }
        }.padding(.vertical, 8).accessibilityElement(children: .combine)
    }
}

/// The picker handles local calendar days; persisted receipt dates remain civil Gregorian dates.
enum ReceiptDateSelection {
    static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        return calendar
    }
    static func date(_ text: String, timeZone: TimeZone = .current) -> Date? {
        guard let value = ExactInput.date(text) else { return nil }
        return calendar(timeZone: timeZone).date(from: DateComponents(year: value.year, month: value.month, day: value.day, hour: 12))
    }
    static func text(_ date: Date, timeZone: TimeZone = .current) -> String {
        let components = calendar(timeZone: timeZone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }
}

private struct ReceiptLineEditor: View {
    var workspace: ReceiptWorkspace
    let id: UUID
    var editing: FocusState<String?>.Binding
    @Environment(\.dynamicTypeSize) private var typeSize
    private var line: EditableReceiptLine? { workspace.draft.lines.first { $0.id == id } }
    private func field(_ key: WritableKeyPath<EditableReceiptLine, String>) -> Binding<String> {
        Binding(get: { line?[keyPath: key] ?? "" }, set: { value in
            workspace.updateDraft { draft in
                if let i = draft.lines.firstIndex(where: { $0.id == id }) { draft.lines[i][keyPath: key] = value }
            }
        })
    }
    var body: some View {
        if let line {
            VStack(alignment: .leading, spacing: 12) {
                TextField(line.kind == "purchase" ? "Printed item description" : "Printed adjustment label", text: field(\.name), axis: .vertical)
                    .font(.body.weight(.medium)).focused(editing, equals: "name-\(id)").accessibilityLabel("Line description")
                    .accessibilityIdentifier("lineName-\(id)")
                Picker("Type", selection: field(\.kind)) {
                    ForEach(["purchase", "discount", "tax", "deposit", "tip", "other"], id: \.self) { Text($0.capitalized).tag($0) }
                }
                if line.kind == "discount" {
                    ReceiptDiscountScopePicker(lines: workspace.draft.lines, selection: Binding(
                        get: { self.line?.discountScope },
                        set: { scope in
                            workspace.updateDraft { draft in
                                if let index = draft.lines.firstIndex(where: { $0.id == id }) {
                                    draft.lines[index].discountScope = scope
                                }
                            }
                        }
                    ))
                }
                if line.kind == "purchase" {
                    LabeledContent("Quantity") {
                        TextField("1 (default)", text: field(\.quantity)).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused(editing, equals: "quantity-\(id)")
                            .accessibilityLabel("Printed quantity").accessibilityIdentifier("lineQuantity-\(id)")
                    }
                }
                if line.kind == "purchase", line.unit != nil {
                    LabeledContent("Unit") {
                        TextField("Unknown", text: Binding(get: { self.line?.unit ?? "" }, set: { value in
                            workspace.updateDraft { draft in
                                if let index = draft.lines.firstIndex(where: { $0.id == id }) {
                                    draft.lines[index].unit = value
                                }
                            }
                        })).multilineTextAlignment(.trailing).focused(editing, equals: "unit-\(id)")
                            .accessibilityIdentifier("lineUnit-\(id)")
                    }
                }
                if line.kind == "purchase", line.unitPrice != nil || line.unitPriceText != nil {
                    LabeledContent("Unit price") {
                        TextField("Unknown", text: Binding(get: { self.line?.editableUnitPrice ?? "" }, set: { value in
                            workspace.updateDraft { draft in
                                if let index = draft.lines.firstIndex(where: { $0.id == id }) { draft.lines[index].unitPriceText = value }
                            }
                        })).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)
                            .focused(editing, equals: "unitPrice-\(id)").accessibilityIdentifier("lineUnitPrice-\(id)")
                    }
                }
                LabeledContent("Line amount") {
                    TextField("Missing", text: field(\.amount)).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).focused(editing, equals: "amount-\(id)")
                        .accessibilityLabel("Printed line amount").accessibilityIdentifier("lineAmount-\(id)")
                }
                HStack {
                    Button("Source", systemImage: "doc.viewfinder") { editing.wrappedValue = nil; workspace.showSource(ids: line.sourceLineIDs) }
                        .frame(minHeight: 44).disabled(line.sourceLineIDs.isEmpty).accessibilityHint("Highlights the OCR observations linked to this line")
                    Spacer()
                    Button("Remove", systemImage: "minus.circle", role: .destructive) { workspace.updateDraft { $0.lines.removeAll { $0.id == id } } }
                        .frame(minHeight: 44).foregroundStyle(.primary).accessibilityLabel("Remove this line")
                }.buttonStyle(.borderless)
                if line.sourceLineIDs.isEmpty { Text("Manually entered · compare with original").font(.caption).foregroundStyle(.primary) }
            }.padding(.vertical, 10).accessibilityElement(children: .contain)
        }
    }
}

struct ReceiptDiscountScopePicker: View {
    let lines: [EditableReceiptLine]
    @Binding var selection: ReceiptDiscountScope?

    var body: some View {
        let purchases = lines.filter { $0.kind == "purchase" }
        Picker("Applies to", selection: $selection) {
            Text("Unconfirmed").tag(nil as ReceiptDiscountScope?)
            Text("Subtotal").tag(Optional(ReceiptDiscountScope.subtotal))
            ForEach(Array(purchases.enumerated()), id: \.element.id) { index, item in
                Text("\(index + 1). \(item.name.nilIfEmpty ?? "Unnamed item")")
                    .tag(Optional(ReceiptDiscountScope.item(item.id)))
            }
        }
        .accessibilityIdentifier("discountScope")
    }
}

struct ReceiptPaper: View {
    let fields: ReceiptFields
    var input: ReceiptReviewDraft? = nil
    var showsSurface = true
    var reviewed = false
    var taxedMarkers: Set<String> = []
    var highlightedLineID: UUID? = nil
    var editLine: ((UUID) -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize
    private let rowSpacing: CGFloat = 14
    private let detailSpacing: CGFloat = 5
    private let detailIndent: CGFloat = 12
    private var minimumRowHeight: CGFloat? { typeSize.isAccessibilitySize ? 44 : nil }

    private func money(_ value: ReceiptMoney?, raw: String? = nil) -> String {
        value.map { ExactInput.format($0.minorUnits, scale: $0.currency.minorUnitScale) } ?? raw?.nilIfEmpty ?? "Missing"
    }
    var body: some View {
        content.background { if showsSurface { ReceiptPaperBackground() } }.receiptPaperStyle()
    }
    private var content: some View {
        let discounts = fields.adjustments.filter { $0.kind == .discount }
        let references = discounts.contains { $0.discountScope == nil }
            ? ReceiptDiscountReferences(merchant: fields.merchant, items: fields.items) : nil
        let itemIDs = Set(fields.items.map(\.id))
        var linked: [UUID: [ReceiptAdjustment]] = [:]
        var basket: [ReceiptAdjustment] = []
        var unassigned: [ReceiptAdjustment] = []
        for discount in discounts {
            switch discount.discountScope {
            case .subtotal:
                basket.append(discount)
            case .item(let id) where itemIDs.contains(id):
                linked[id, default: []].append(discount)
            case nil:
                if let id = references?.itemID(for: discount.label) {
                    linked[id, default: []].append(discount)
                } else {
                    unassigned.append(discount)
                }
            case .item:
                unassigned.append(discount)
            }
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(fields.merchant ?? "Merchant missing").font(.title2.weight(.semibold)).accessibilityIdentifier("receiptPaperMerchant")
                Spacer(minLength: 0)
                if reviewed { ReceiptReviewedMark() }
            }
            Text("\(ExactInput.dateText(fields.purchaseDate).nilIfEmpty ?? "Date missing") · \(fields.currency?.code ?? "Currency missing")").font(.subheadline).receiptPaperSecondaryInk()
            Divider()
            Text("Items").font(.headline)
            VStack(alignment: .leading, spacing: rowSpacing) {
                ForEach(fields.items) { item in
                    itemGroup(item, discounts: linked[item.id, default: []])
                        .id(item.id)
                }
            }
            if fields.items.isEmpty { Text("Purchases missing").foregroundStyle(.primary) }
            Divider()
            VStack(alignment: .leading, spacing: rowSpacing) {
                amountRow("Subtotal", fields.subtotal, raw: input?.subtotalNotPrinted == true ? "Not printed" : input?.subtotal)
                    .fontWeight(.semibold)
                    .frame(minHeight: minimumRowHeight)
                adjustmentRows(basket)
                adjustmentRows(unassigned, title: "Unassigned discount")
                adjustmentRows(fields.adjustments.filter { $0.kind == .tax })
                adjustmentRows(fields.adjustments.filter { $0.kind != .discount && $0.kind != .tax })
            }
            .font(.subheadline)
            Divider()
            amountRow("Total", fields.total, raw: input?.total).font(.title3.weight(.semibold)).accessibilityIdentifier("receiptPaperTotal")
        }.fontDesign(.monospaced).padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func itemGroup(_ item: ReceiptLine, discounts: [ReceiptAdjustment]) -> some View {
        let details = itemDetail(item)
        let isTaxed = item.taxMarker.map {
            taxedMarkers.contains($0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
        } ?? false
        return VStack(alignment: .leading, spacing: detailSpacing) {
            editableRow(item.id) {
                VStack(alignment: .leading, spacing: detailSpacing) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(item.paperName)
                            .fontWeight(.medium)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
                        if isTaxed { taxBadge }
                        itemPrice(item.amount, lineID: item.id)
                    }
                    if !details.isEmpty {
                        Text(details.replacingOccurrences(of: "Quantity ", with: "Qty ", options: .anchored))
                            .accessibilityLabel(details)
                            .padding(.leading, detailIndent)
                            .receiptPaperSecondaryInk()
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ForEach(discounts) { discount in
                editableRow(discount.id) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(adjustmentTitle(discount))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, detailIndent)
                        itemPrice(discount.amount, lineID: discount.id)
                    }
                    .receiptPaperSecondaryInk()
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .font(.system(.subheadline, design: .monospaced))
    }

    private func itemDetail(_ item: ReceiptLine) -> String {
        var values: [String] = []
        if let quantity = item.quantity {
            let unit = item.unitPrice != nil && item.paperPriceUnit == "each" ? "" : item.unit.map { " " + $0 } ?? ""
            values.append("Quantity " + ExactInput.quantity(quantity) + unit)
        }
        if let price = item.unitPrice { values.append(money(price) + "/" + item.paperPriceUnit) }
        return values.joined(separator: " · ")
    }

    private var taxBadge: some View {
        Text("T")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            .receiptPaperSecondaryInk()
            .accessibilityLabel("Taxed")
    }

    private func itemPrice(_ amount: ReceiptMoney?, lineID: UUID) -> some View {
        Text(money(amount, raw: input?.lines.first { $0.id == lineID }?.amount))
            .lineLimit(1).minimumScaleFactor(0.45).layoutPriority(1)
    }

    private func adjustmentRows(_ adjustments: [ReceiptAdjustment], title: String? = nil) -> some View {
        ForEach(adjustments) { adjustment in
            editableRow(adjustment.id) {
                amountRow(title ?? adjustmentTitle(adjustment), adjustment.amount,
                          raw: input?.lines.first { $0.id == adjustment.id }?.amount, secondary: true)
            }
        }
    }
    private func adjustmentTitle(_ adjustment: ReceiptAdjustment) -> String {
        switch adjustment.kind {
        case .tax: return "Tax"
        case .tip: return "Tip"
        case .deposit: return "Deposit"
        case .discount:
            let label = adjustment.label ?? ""
            let loyalty = label.range(of: #"\b(?:loyalty|members?|membership|rewards?|points)\b"#,
                                      options: [.regularExpression, .caseInsensitive]) != nil
            return loyalty ? "Loyalty discount" : "Discount"
        case .other: return adjustment.label ?? "Other charge"
        }
    }

    @ViewBuilder private func editableRow<Content: View>(_ id: UUID, @ViewBuilder content: () -> Content) -> some View {
        let row = content().frame(maxWidth: .infinity, minHeight: minimumRowHeight, alignment: .leading)
        if let editLine {
            Button { editLine(id) } label: {
                row.contentShape(Rectangle())
            }
            .buttonStyle(ReceiptRowPressStyle())
            .accessibilityHint("Edit this line")
            .accessibilityIdentifier("paperLine-" + id.uuidString)
        } else if highlightedLineID == id {
            row
                .background {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(.primary.opacity(0.08))
                        .padding(.horizontal, -8)
                }
                .accessibilityHint("Purchase opened from history")
                .accessibilityIdentifier("historyHighlightedPurchase")
        } else {
            row
        }
    }
    private func amountRow(_ name: String, _ value: ReceiptMoney?, raw: String? = nil, secondary: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(name)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(money(value, raw: raw))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.45).layoutPriority(1)
        }
        .receiptPaperSecondaryInk(secondary)
        .accessibilityElement(children: .combine)
    }
}

private struct ReceiptRowPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.primary.opacity(ReceiptAccessibility.contrast(contrast) == .increased ? 0.16 : 0.09))
                    .padding(.horizontal, -8)
                    .opacity(configuration.isPressed ? 1 : 0)
                    .animation(
                        configuration.isPressed || ReceiptAccessibility.reduceMotion(reduceMotion) ? nil : .easeOut(duration: 0.16),
                        value: configuration.isPressed
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

struct ReceiptReviewedMark: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .medium))
            .foregroundStyle(.primary.opacity(0.65))
            .accessibilityLabel("Reviewed and saved").accessibilityIdentifier("receiptReviewedMark")
    }
}
