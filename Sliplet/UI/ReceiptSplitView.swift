import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Local editing surface. Explicit Save/Finalize persist; Copy/Share exist only for the committed current split.
struct ReceiptSplitView: View {
    @Bindable var workspace: ReceiptWorkspace
    private enum Destination: Hashable { case item(UUID), policy(UUID), tax(UUID), summary }
    private enum SectionAnchor: Hashable { case purchases, adjustments, amounts }
    @State private var path: [Destination] = []
    @State private var plan: ReceiptSplitPlan
    @State private var activePerson: UUID?
    @State private var selectedItems: Set<UUID> = []
    @State private var undoPlan: ReceiptSplitPlan?
    @State private var editingPerson: SplitParticipant?
    @State private var unassignedOnly = false
    @State private var source = false
    @State private var discard = false
    @State private var returnToReview = false
    @State private var copied = false
    @State private var adjustmentsExpanded = false
    @State private var editingFinalized = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    private var effectiveTypeSize: DynamicTypeSize {
        SyntheticNativePreview.enabled && ProcessInfo.processInfo.arguments.contains("--t05-large-text") ? .accessibility5 : systemTypeSize
    }
    init(workspace: ReceiptWorkspace) {
        self.workspace = workspace
        _plan = State(initialValue: workspace.selected?.splitPlan ?? ReceiptSplitPlan())
    }
    private var record: ReceiptRecord? { workspace.selected }
    private var pristine: Bool { record?.splitPlan == plan || (record?.splitPlan == nil && plan.participants.isEmpty && plan.assignments.isEmpty && plan.policies.isEmpty) }
    private var showsSplitDetails: Bool {
        !plan.participants.isEmpty || undoPlan?.participants.isEmpty == false
    }
    private func calculation(using prepared: ReceiptSplitPlan) -> Result<ReceiptSplitResult, Error> {
        Result {
            guard let record else { throw SplitError.invalidPlan }
            return try ReceiptSplitEngine.compute(record, plan: prepared)
        }
    }
    private var summary: String? {
        guard pristine, let record else { return nil }
        return try? ReceiptSplitEngine.summary(record, plan: plan)
    }
    private func change(_ edit: (inout ReceiptSplitPlan) -> Void) {
        edit(&plan); plan.finalizedRevision = nil; copied = false; undoPlan = nil
    }
    private func money(_ value: Int64) -> String {
        let currency = record?.current.fields.currency ?? .cad
        return "\(currency.code) \(ExactInput.format(value, scale: currency.minorUnitScale))"
    }
    var body: some View {
        let showingOverview = activePerson == nil && showsSplitDetails
        let prepared = showingOverview ? plan.withStandardAdjustments(record?.current.fields.adjustments ?? []) : plan
        let evaluation = showingOverview ? calculation(using: prepared) : nil
        let result = evaluation.flatMap { try? $0.get() }
        let error: SplitError? = if case .failure(let error) = evaluation { error as? SplitError } else { nil }
        let finalizedSummary = summary
        return NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                Group {
                    if let result, let finalizedSummary, !editingFinalized, activePerson == nil {
                        completedSplit(result, summary: finalizedSummary)
                    } else {
                        splitForm(prepared: prepared, result: result, error: error, finalizedSummary: finalizedSummary, proxy: proxy)
                    }
                }
            }
            .id(activePerson)
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .item(let id):
                    if let item = record?.current.fields.items.first(where: { $0.id == id }) { itemEditor(item) }
                case .policy(let id):
                    if let adjustment = record?.current.fields.adjustments.first(where: { $0.id == id }) { policyEditor(adjustment) }
                case .tax(let id):
                    if let adjustment = record?.current.fields.adjustments.first(where: { $0.id == id }) {
                        ReceiptTaxAllocationView(adjustment: adjustment, people: plan.participants, plan: plan,
                            explanation: taxExplanation, current: policy(adjustment), money: money,
                            advanced: { path.append(.policy(adjustment.id)) }) { chosen in
                            applyTax(chosen)
                        }.id(adjustment.id)
                    }
                case .summary:
                    ScrollView { Text(summary ?? "Finalize this split first.").textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20) }
                        .navigationTitle("Split summary").modifier(SplitEditorBack())
                }
            }
            .navigationTitle(activePerson == nil ? "Split receipt" : "Assign items").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if path.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        if effectiveTypeSize.isAccessibilitySize && activePerson != nil {
                            Button("Cancel", action: cancelBatch).accessibilityIdentifier("splitBatchCancel")
                        } else {
                            Button(action: closeSplit) { Text("Done") }.disabled(workspace.saving).accessibilityIdentifier("splitDone")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if finalizedSummary != nil && !editingFinalized {
                            Button("Edit split") { editingFinalized = true }
                                .accessibilityIdentifier("splitEditCompleted")
                        } else {
                            Button { source = true } label: { Text("Original") }
                                .disabled(workspace.image == nil || workspace.saving).accessibilityIdentifier("splitOriginal")
                        }
                    }
                }
            }
            .safeAreaBar(edge: .bottom, spacing: 0) {
                if !effectiveTypeSize.isAccessibilitySize {
                    splitActions(prepared: prepared, canFinalize: result != nil && finalizedSummary == nil)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if effectiveTypeSize.isAccessibilitySize {
                    splitActions(prepared: prepared, canFinalize: result != nil && finalizedSummary == nil)
                        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea(edges: .bottom))
                }
            }
            .sheet(item: $editingPerson) { person in
                SplitPersonEditor(person: person, number: plan.number(for: person), color: plan.color(for: person)) { name, color in
                    change { p in
                        p.materializeAppearance()
                        if let index = p.participants.firstIndex(where: { $0.id == person.id }) {
                            p.participants[index].name = name; p.participants[index].color = color
                        }
                    }
                } remove: { removePerson(person.id); cancelBatch() }
            }
            .sheet(isPresented: $source) { ReceiptSourceView(workspace: workspace) }
            .confirmationDialog("Discard unsaved split choices?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard choices", role: .destructive) {
                    if returnToReview { workspace.edit() }
                    dismiss()
                }
                Button("Cancel", role: .cancel) { returnToReview = false }
            }
            .onChange(of: record?.splitPlan) { _, _ in
                if let saved = record?.splitPlan { plan = saved; copied = false; undoPlan = nil; editingFinalized = false; cancelBatch() }
            }
            .onChange(of: workspace.active) { _, active in
                if !active { cancelBatch(); editingPerson = nil; undoPlan = nil }
            }
            .onChange(of: workspace.privacyCovered) { _, covered in
                if covered { cancelBatch(); editingPerson = nil; undoPlan = nil }
            }
            .onChange(of: record?.current.id) { _, _ in dismiss() }
            .disabled(workspace.saving)
            .interactiveDismissDisabled(!pristine || batchDirty || workspace.saving)
        }.tint(.primary)
        #if DEBUG
        .dynamicTypeSize(effectiveTypeSize)
        #endif
    }
    private var pendingTax: ReceiptAdjustment? {
        guard let record, ReceiptCompletion.isComplete(record) else { return nil }
        return record.current.fields.adjustments.first { adjustment in
            adjustment.kind == .tax && plan.policies.first(where: { $0.id == adjustment.id })?.accepted != true
        }
    }

    private var taxExplanation: String {
        guard let record else { return "Choose who will cover this tax." }
        let knownMarkers = record.original.paperTaxedMarkers
        let identified = record.current.fields.items.contains {
            $0.taxMarker.map { knownMarkers.contains($0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) } ?? false
        }
        return identified
            ? "Some tax markers were found, but this tax couldn’t be matched to specific items. Choose how to share it."
            : "No clear tax markers were found. Who should cover this tax?"
    }

    private func reviewTaxButton(_ tax: ReceiptAdjustment) -> some View {
        Button("Review tax") { path.append(.tax(tax.id)) }
            .buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("splitReviewTax")
    }

    private func applyTax(_ chosen: SplitAdjustmentPolicy) {
        change {
            $0.policies.removeAll { $0.id == chosen.id }
            $0.policies.append(chosen)
        }
        if let tax = pendingTax { path = [.tax(tax.id)] }
        else { path = [] }
    }

    private func completedSplit(_ result: ReceiptSplitResult, summary: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Split finalized", systemImage: "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("splitStatus")
                    Text(record?.current.fields.merchant ?? "Receipt").font(.title2.weight(.semibold))
                    Text("Total " + money(result.total)).font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary).accessibilityIdentifier("splitExactTotal")
                }
                ForEach(plan.participants) { person in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            personBadge(person)
                            Text(person.name).font(.headline)
                        }
                        Text(money(result.totals[person.id] ?? 0))
                            .font(.largeTitle.weight(.semibold).monospacedDigit())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("splitTotal-" + person.name)
                }
                NavigationLink("View breakdown", value: Destination.summary)
                    .frame(minHeight: 44).accessibilityIdentifier("splitBreakdown")
                if copied {
                    Label("Copied on this device", systemImage: "checkmark")
                        .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("splitCopied")
                }
            }.padding(20)
        }
        .accessibilityIdentifier("splitCompleted")
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ReceiptPairedActions {
                Button("Copy", systemImage: "doc.on.doc") {
                    guard workspace.active, !workspace.privacyCovered else { return }
                    UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: summary]], options: [.localOnly: true])
                    copied = true
                }.buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("splitCopy")
            } primary: {
                ShareLink(item: summary) { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("splitShare")
            }
            .modifier(ReceiptActionBarLayout())
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    private func splitForm(prepared: ReceiptSplitPlan, result: ReceiptSplitResult?, error: SplitError?,
                           finalizedSummary: String?, proxy: ScrollViewProxy) -> some View {
        let policies = Dictionary(prepared.policies.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let components = Dictionary((result?.components ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let visibleAdjustments = (record?.current.fields.adjustments ?? []).filter {
            unassignedItems.isEmpty || $0.kind != .tax
        }
        return Form {
            if let person = plan.participants.first(where: { $0.id == activePerson }) {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        personBadge(person)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name).font(.headline).accessibilityIdentifier("splitActivePerson")
                            Text("\(selectedItems.count) selected · \(sharedCount) shared").font(.subheadline)
                        }.fixedSize(horizontal: false, vertical: true)
                    }
                    Button {
                        selectedItems.formUnion(unassignedItems.map(\.id))
                    } label: {
                        Label("Select all unassigned", systemImage: "checklist")
                    }
                    .disabled(unassignedItems.allSatisfy { selectedItems.contains($0.id) })
                    .accessibilityIdentifier("splitSelectUnassigned")
                    Button("Edit name or color") { editingPerson = person }.accessibilityIdentifier("splitEditPerson")
                }
            } else {
                peopleSection
            }
            if activePerson == nil {
                Section {
                    Text(record?.current.fields.merchant ?? "Receipt").font(.headline)
                    if let total = record?.current.fields.total { LabeledContent("Receipt total") { Text(money(total.minorUnits)).foregroundStyle(Color(uiColor: .label)) } }
                    splitProgress(error: error, policies: policies, proxy: proxy)
                }
            }
            if activePerson == nil, showsSplitDetails, let result {
                Section {
                    ForEach(plan.participants) { person in
                        LabeledContent(person.name) { Text(money(result.totals[person.id] ?? 0)).foregroundStyle(Color(uiColor: .label)) }.accessibilityIdentifier("splitTotal-\(person.name)")
                    }
                    LabeledContent("Exact total") { Text(money(result.total)).foregroundStyle(Color(uiColor: .label)) }.font(.headline).accessibilityElement(children: .combine).accessibilityIdentifier("splitExactTotal")
                    if effectiveTypeSize.isAccessibilitySize && finalizedSummary == nil {
                        saveChoicesButton
                    }
                    if let summary = finalizedSummary {
                        Label("Split finalized", systemImage: "checkmark.circle")
                            .accessibilityIdentifier("splitStatus")
                        NavigationLink("View summary", value: Destination.summary)
                        Button("Copy summary", systemImage: "doc.on.doc") {
                            guard workspace.active, !workspace.privacyCovered else { return }
                            UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: summary]], options: [.localOnly: true])
                            copied = true
                        }.accessibilityIdentifier("splitCopy")
                        ShareLink(item: summary) { Label("Share summary", systemImage: "square.and.arrow.up") }.accessibilityIdentifier("splitShare")
                        if copied { Text("Copied on this device.").accessibilityIdentifier("splitCopied") }
                    }
                } header: {
                    Text("Amounts").id(SectionAnchor.amounts)
                }
            }
            if activePerson == nil, let error = workspace.errorMessage {
                Section { Label(error, systemImage: "exclamationmark.circle") }
            }
            if activePerson == nil, showsSplitDetails, !visibleAdjustments.isEmpty {
                adjustmentSection(visibleAdjustments, policies: policies, components: components)
            }
            if showsSplitDetails {
                Section {
                    Group {
                        if effectiveTypeSize.isAccessibilitySize { itemFilter.pickerStyle(.menu) }
                        else { itemFilter.pickerStyle(.segmented) }
                    }.id(SectionAnchor.purchases)
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if !unassignedOnly || plan.assignments[item.id, default: []].isEmpty {
                            if activePerson != nil {
                                Button {
                                    if selectedItems.contains(item.id) { selectedItems.remove(item.id) }
                                    else { selectedItems.insert(item.id) }
                                } label: { purchaseRow(item) }.buttonStyle(.plain)
                                    .accessibilityIdentifier("splitItem-\(index)")
                                    .accessibilityValue(selectedItems.contains(item.id) ? "Selected" : "Not selected")
                                    .accessibilityAddTraits(selectedItems.contains(item.id) ? .isSelected : [])
                            } else {
                                NavigationLink(value: Destination.item(item.id)) { purchaseRow(item) }
                                    .accessibilityIdentifier("splitItem-\(index)")
                            }
                        }
                    }
                    if activePerson != nil, !selectedItems.isEmpty {
                        Button("Clear selection") { selectedItems = [] }
                            .accessibilityLabel("Clear this person’s selection")
                            .accessibilityIdentifier("splitClearSelection")
                    }
                } header: { Text("Purchases") } footer: {
                    Text(activePerson == nil ? "Tap a purchase to see who shares it." : "Tap the items this person will pay for. Selecting an assigned item shares it equally.")
                }
            }
        }
    }

    private func adjustmentSection(_ adjustments: [ReceiptAdjustment], policies: [UUID: SplitAdjustmentPolicy],
                                   components: [UUID: SplitComponent]) -> some View {
        Section {
            Button {
                adjustmentsExpanded.toggle()
            } label: {
                HStack {
                    Label("Adjustments", systemImage: "slider.horizontal.3")
                    Spacer(minLength: 8)
                    Image(systemName: adjustmentsExpanded ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(adjustmentsExpanded ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("splitAdjustmentOptions")
            .id(SectionAnchor.adjustments)
            if adjustmentsExpanded {
                ForEach(Array(adjustments.enumerated()), id: \.element.id) { index, adjustment in
                    NavigationLink(value: adjustment.kind == .tax ? Destination.tax(adjustment.id) : .policy(adjustment.id)) {
                        VStack(alignment: .leading, spacing: 5) {
                            LabeledContent(adjustment.label ?? adjustment.kind.rawValue.capitalized) {
                                if let amount = adjustment.amount { Text(money(amount.minorUnits)).monospacedDigit() }
                            }.labeledContentStyle(ReceiptAdaptiveLabeledContentStyle())
                            if let policy = policies[adjustment.id] {
                                let standard = SplitAdjustmentPolicy.standard(for: adjustment)
                                if !policy.accepted {
                                    Text("Confirm allocation").font(.footnote).foregroundStyle(.secondary)
                                } else if policy.matchesRule(standard) {
                                    Text(standard.target == .allPurchases ? "By purchase share" : "Follows item")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                            if let component = components[adjustment.id] {
                                ForEach(plan.participants.filter { component.shares[$0.id] != nil }) { person in
                                    if let share = component.shares[person.id] {
                                        Text(person.name + " · " + money(share)).font(.footnote).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }.accessibilityIdentifier("splitAdjustment-\(index)")
                }
            }
        }
    }

    private var itemFilter: some View {
        Picker("Show items", selection: $unassignedOnly) {
            Text("All items").tag(false)
            Text("Unassigned").tag(true)
        }.accessibilityIdentifier("splitItemFilter")
    }

    @ViewBuilder private func splitProgress(error: SplitError?, policies: [UUID: SplitAdjustmentPolicy],
                                            proxy: ScrollViewProxy) -> some View {
        let remaining = unassignedItems.count
        Text("\(items.count - remaining) of \(items.count) items assigned")
            .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("splitAssignmentProgress")
        if let record, !ReceiptCompletion.isComplete(record) {
            Label(workspace.receiptReviewBlocker ?? "Finish this receipt before finalizing a split.",
                  systemImage: "exclamationmark.triangle")
            Button("Continue review", action: continueReview)
                .accessibilityIdentifier("splitContinueReview")
        } else if !plan.participants.isEmpty {
            if remaining > 0 {
                Button {
                    unassignedOnly = true
                    proxy.scrollTo(SectionAnchor.purchases, anchor: .top)
                } label: {
                    Label(remaining == 1 ? "1 unassigned item" : "\(remaining) unassigned items", systemImage: "person.crop.circle.badge.questionmark")
                }.accessibilityIdentifier("splitUnassignedProgress")
            }
            let pending = record?.current.fields.adjustments.filter { policies[$0.id]?.accepted == false } ?? []
            if remaining == 0, let adjustment = pending.first {
                Button {
                    path.append(adjustment.kind == .tax ? .tax(adjustment.id) : .policy(adjustment.id))
                } label: {
                    Label(adjustment.kind == .tax ? "Choose who pays tax" : "Confirm adjustment",
                          systemImage: "person.2")
                }.accessibilityIdentifier("splitAdjustmentProgress")
            } else if error == .invalidTargets || error == .unknownTaxScope || error == .zeroBase {
                Button {
                    adjustmentsExpanded = true
                    proxy.scrollTo(SectionAnchor.adjustments, anchor: .top)
                } label: {
                    Label("Check adjustment allocations", systemImage: "exclamationmark.circle")
                }.accessibilityIdentifier("splitAdjustmentProgress")
            } else if let error, error != .incompleteAssignments {
                Label(error.localizedDescription, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
            }
        }
    }

    @ViewBuilder private func splitActions(prepared: ReceiptSplitPlan, canFinalize: Bool) -> some View {
        if path.isEmpty && (summary == nil || editingFinalized) {
            if activePerson != nil {
                if effectiveTypeSize.isAccessibilitySize {
                    applyItemsButton.modifier(ReceiptActionBarLayout())
                } else {
                    ReceiptPairedActions {
                        Button("Cancel", action: cancelBatch)
                            .buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("splitBatchCancel")
                    } primary: {
                        applyItemsButton
                    }.modifier(ReceiptActionBarLayout())
                }
            } else if !plan.participants.isEmpty || !pristine || undoPlan != nil {
                Group {
                    if effectiveTypeSize.isAccessibilitySize {
                        if let tax = pendingTax, unassignedItems.isEmpty {
                            reviewTaxButton(tax)
                        } else if canFinalize { finalizeButton(prepared: prepared, enabled: true) }
                        else { saveChoicesButton.buttonStyle(ReceiptSecondaryStyle()) }
                    } else {
                        ReceiptPairedActions {
                            saveChoicesButton.buttonStyle(ReceiptSecondaryStyle())
                        } primary: {
                            if let tax = pendingTax, unassignedItems.isEmpty {
                                reviewTaxButton(tax)
                            } else {
                                finalizeButton(prepared: prepared, enabled: canFinalize)
                            }
                        }
                    }
                }.modifier(ReceiptActionBarLayout())
            }
        }
    }

    private var applyItemsButton: some View {
        Button("Apply items", action: applyBatch)
            .buttonStyle(ReceiptProminentStyle()).accessibilityIdentifier("splitBatchApply")
    }

    private var saveChoicesButton: some View {
        Button("Save choices") { workspace.saveSplit(plan, finalize: false) }
            .disabled(workspace.saving || (try? plan.validateStructure()) == nil)
            .accessibilityIdentifier("splitSave")
    }

    private func finalizeButton(prepared: ReceiptSplitPlan, enabled: Bool) -> some View {
        Button("Finalize") { workspace.saveSplit(prepared, finalize: true) }
            .buttonStyle(ReceiptProminentStyle())
            .disabled(workspace.saving || !enabled).accessibilityIdentifier("splitFinalize")
    }

    private var items: [ReceiptLine] { record?.current.fields.items ?? [] }
    private var unassignedItems: [ReceiptLine] { items.filter { plan.assignments[$0.id, default: []].isEmpty } }
    private var baselineSelection: Set<UUID> {
        guard let activePerson else { return [] }
        return Set(items.filter { plan.assignments[$0.id, default: []].contains(activePerson) }.map(\.id))
    }
    private var batchDirty: Bool { activePerson != nil && selectedItems != baselineSelection }
    private func cancelBatch() {
        activePerson = nil
        selectedItems = []
        unassignedOnly = false
    }
    private func continueReview() {
        if pristine && !batchDirty { workspace.edit(); dismiss() }
        else { returnToReview = true; discard = true }
    }
    private func closeSplit() {
        returnToReview = false
        if pristine && !batchDirty { dismiss() }
        else { discard = true }
    }
    private func selectPerson(_ id: UUID) {
        activePerson = id
        selectedItems = baselineSelection
        unassignedOnly = false
    }
    private func addPerson() {
        var id: UUID?
        change { id = $0.addPerson() }
        if let id { selectPerson(id) }
    }
    private func applyBatch() {
        guard let person = activePerson else { return }
        if batchDirty {
            let previous = plan
            change { $0.assign(person, selected: selectedItems, items: Set(items.map(\.id))) }
            undoPlan = previous
        }
        cancelBatch()
        if unassignedItems.isEmpty, let tax = pendingTax { path.append(.tax(tax.id)) }
    }
    private func removePerson(_ id: UUID) {
        guard plan.participants.contains(where: { $0.id == id }) else { return }
        var updated = plan
        updated.removePerson(id)
        undoPlan = plan
        copied = false
        plan = updated
    }

    private func undoBatch() {
        guard let previous = undoPlan else { return }
        plan = previous; undoPlan = nil; copied = false
    }
    private var peopleSection: some View {
        Section {
            Button(action: addPerson) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(.primary.opacity(0.08), in: Circle())
                        .accessibilityHidden(true)
                    Text("Add person").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(plan.participants.count >= 100)
            .accessibilityIdentifier("splitAddPerson")

            ForEach(plan.participants) { person in
                let count = items.filter { plan.assignments[$0.id, default: []].contains(person.id) }.count
                let assignmentLabel = "\(count) \(count == 1 ? "item" : "items") assigned"
                Button { selectPerson(person.id) } label: {
                    HStack(spacing: 12) {
                        personBadge(person)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.name).font(.body.weight(.medium))
                            Text(assignmentLabel)
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("splitPerson-\(plan.number(for: person))")
                .accessibilityLabel("\(person.name), \(plan.color(for: person).title), \(assignmentLabel)")
                .accessibilityHint("Assign items or edit this person")
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    // The model removes the row. Avoid SwiftUI's separate optimistic removal animation.
                    Button("Delete", systemImage: "trash") {
                        removePerson(person.id)
                    }.tint(.red).accessibilityIdentifier("splitSwipeDelete")
                }
            }
            if let undoPlan {
                let title = undoPlan.participants.count > plan.participants.count ? "Undo removal" : "Undo assignment"
                Button(title, systemImage: "arrow.uturn.backward") { undoBatch() }
                    .accessibilityIdentifier("splitUndoBatch")
            }
        } header: {
            Text("People")
        } footer: {
            if !showsSplitDetails { Text("Add someone to choose their items. You can give them a name later.") }
        }
    }
    private var sharedCount: Int {
        selectedItems.filter { item in plan.assignments[item, default: []].contains { $0 != activePerson } }.count
    }
    private func personBadge(_ person: SplitParticipant) -> some View {
        Text("\(plan.number(for: person))")
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(width: 30, height: 30)
            .background(plan.color(for: person).tint.opacity(0.18), in: Circle())
            .overlay(Circle().strokeBorder(plan.color(for: person).tint, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
    private func purchaseRow(_ item: ReceiptLine) -> some View {
        let selected = activePerson != nil && selectedItems.contains(item.id)
        let ids = Set(plan.assignments[item.id, default: []].filter { $0 != activePerson })
            .union(selected ? [activePerson!] : activePerson == nil ? plan.assignments[item.id, default: []] : [])
        let highlight = plan.participants.first(where: { $0.id == activePerson })
            .map { plan.color(for: $0).tint.opacity(0.07) } ?? .clear
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.description ?? "Purchase")
                if let amount = item.amount { Text(money(amount.minorUnits)).font(.subheadline) }
                HStack(spacing: 4) {
                    ForEach(plan.participants.filter { ids.contains($0.id) }.prefix(5)) { person in personBadge(person) }
                    Text(ids.isEmpty ? "Unassigned" : ids.count > 1 ? "Shared equally · \(ids.count) people" : plan.participants.first(where: { ids.contains($0.id) })?.name ?? "Assigned")
                        .font(.caption)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if activePerson != nil { Image(systemName: selected ? "checkmark.circle.fill" : "circle") }
        }.foregroundStyle(.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(minHeight: 48)
            .background(selected ? highlight : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel((item.description ?? "Purchase") + ", " + (item.amount.map { money($0.minorUnits) } ?? "Amount missing") + ", " + (ids.isEmpty ? "Unassigned" : plan.participants.filter { ids.contains($0.id) }.map { "\($0.name), person \(plan.number(for: $0))" }.joined(separator: ", ")) + (ids.count > 1 ? ", Shared equally" : ""))
    }
    private func toggle(_ id: UUID, in ids: inout [UUID], selected: Bool) {
        ids.removeAll { $0 == id }; if selected { ids.append(id) }
    }
    private func itemEditor(_ item: ReceiptLine) -> some View {
        Form {
            Section {
                Text(item.description ?? "Purchase").font(.headline)
                if let amount = item.amount { Text(money(amount.minorUnits)) }
            }
            Section {
                if plan.participants.isEmpty { Text("Add people on the split screen first.") }
                ForEach(plan.participants) { person in
                    SplitSelectionRow(title: person.name, selection: Binding(get: { plan.assignments[item.id, default: []].contains(person.id) }, set: { selected in
                        change { p in
                            var selection = Set(items.filter { p.assignments[$0.id, default: []].contains(person.id) }.map(\.id))
                            if selected { selection.insert(item.id) } else { selection.remove(item.id) }
                            p.assign(person.id, selected: selection, items: Set(items.map(\.id)))
                        }
                    })).accessibilityIdentifier("splitOwner-\(person.name)")
                }
            } header: { Text("Assign to").foregroundStyle(Color(uiColor: .label)) }
        }.navigationTitle("Item owners").modifier(SplitEditorBack())
    }
    private func policy(_ adjustment: ReceiptAdjustment) -> SplitAdjustmentPolicy {
        plan.policies.first { $0.id == adjustment.id } ?? .standard(for: adjustment)
    }
    private func setPolicy(_ adjustment: ReceiptAdjustment, edit: (inout SplitAdjustmentPolicy) -> Void) {
        change { p in
            var next = policy(adjustment); edit(&next)
            p.policies.removeAll { $0.id == adjustment.id }; p.policies.append(next)
        }
    }
    private func policyEditor(_ adjustment: ReceiptAdjustment) -> some View {
        let p = policy(adjustment)
        return Form {
            Section {
                Text(adjustment.label ?? adjustment.kind.rawValue).font(.headline)
                if let amount = adjustment.amount { Text(money(amount.minorUnits)) }
                Picker("Allocation", selection: Binding(get: { policy(adjustment).method }, set: { method in
                    setPolicy(adjustment) { $0.method = method; $0.accepted = false }
                })) { ForEach(SplitMethod.allCases) { Text($0.title).tag($0) } }.accessibilityIdentifier("splitMethod").accessibilityValue(p.method.title)
                Picker("Allocate across", selection: Binding(get: { policy(adjustment).target }, set: { target in
                    setPolicy(adjustment) { $0.target = target; $0.selectedIDs = []; $0.accepted = false; $0.sourceConfirmed = false }
                })) { ForEach(SplitTarget.allCases) { Text($0.title).tag($0) } }.accessibilityIdentifier("splitTarget").accessibilityValue(p.target.title)
            }
            if p.target == .selectedPurchases, let record {
                Section {
                    ForEach(record.current.fields.items) { item in
                        SplitSelectionRow(title: item.description ?? "Purchase", selection: selection(adjustment, id: item.id))
                    }
                } header: { Text("Included purchases").foregroundStyle(Color(uiColor: .label)) }
            }
            if p.target == .selectedPeople {
                Section { ForEach(plan.participants) { person in SplitSelectionRow(title: person.name, selection: selection(adjustment, id: person.id)) } } header: { Text("Included people").foregroundStyle(Color(uiColor: .label)) }
            }
            if adjustment.kind == .tax && p.target == .selectedPurchases {
                Section("Tax scope") {
                    Button("Check original") { source = true }.disabled(workspace.image == nil)
                    SplitSelectionRow(title: "I verified which purchases this tax covers", selection: Binding(get: { policy(adjustment).sourceConfirmed }, set: { confirmed in
                        setPolicy(adjustment) { $0.sourceConfirmed = confirmed; $0.accepted = false }
                    })).accessibilityIdentifier("splitTaxConfirmed")
                }
            }
            if adjustment.kind == .tax || !p.matchesRule(.standard(for: adjustment)) {
                Section {
                    SplitSelectionRow(title: "Confirm allocation", selection: Binding(get: { policy(adjustment).accepted }, set: { accepted in
                        setPolicy(adjustment) { $0.accepted = accepted }
                    })).accessibilityIdentifier("splitPolicyAccepted")
                    Button("Use standard split") {
                        change { $0.policies.removeAll { $0.id == adjustment.id } }
                    }
                }
            }
            Section {
                DisclosureGroup("How adjustments are shared") {
                    Text("Proportional uses each person’s purchase share. Equal divides the amount among the people included in the rule. If the receipt does not identify taxable items, the standard split shares the printed tax across purchases.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if adjustment.kind == .tax {
                Button("Apply tax split") { applyTax(p) }
                    .buttonStyle(ReceiptProminentStyle()).disabled(!p.accepted)
                    .accessibilityIdentifier("splitApplyAdvancedTax")
                    .modifier(ReceiptActionBarLayout()).frame(maxWidth: .infinity)
                    .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .navigationTitle("Allocation policy").modifier(SplitEditorBack())
    }
    private func selection(_ adjustment: ReceiptAdjustment, id: UUID) -> Binding<Bool> {
        Binding(get: { policy(adjustment).selectedIDs.contains(id) }, set: { selected in
            setPolicy(adjustment) { p in toggle(id, in: &p.selectedIDs, selected: selected); p.accepted = false; p.sourceConfirmed = false }
        })
    }
}

private struct ReceiptTaxAllocationView: View {
    private enum Choice: String, CaseIterable {
        case proportional = "By purchase share"
        case equal = "Split equally"
        case people = "Choose who pays"

        var detail: String {
            switch self {
            case .proportional: "Based on each person’s assigned purchases"
            case .equal: "Same share for everyone"
            case .people: "One person or a group you select"
            }
        }
    }

    let adjustment: ReceiptAdjustment
    let people: [SplitParticipant]
    let plan: ReceiptSplitPlan
    let explanation: String
    let current: SplitAdjustmentPolicy
    let money: (Int64) -> String
    let advanced: () -> Void
    let apply: (SplitAdjustmentPolicy) -> Void
    @State private var choice: Choice?
    @State private var selectedPeople: Set<UUID> = []

    private var validChoice: Bool {
        choice != nil && (choice != .people || !selectedPeople.isEmpty)
    }

    var body: some View {
        Form {
            Section {
                Text(adjustment.label ?? "Tax").font(.headline)
                if let amount = adjustment.amount {
                    Text(money(amount.minorUnits)).font(.largeTitle.weight(.semibold).monospacedDigit())
                }
                Text(explanation).font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Who pays?") {
                ForEach(Choice.allCases, id: \.self) { option in
                    SplitSelectionRow(title: option.rawValue, subtitle: option.detail, selection: Binding(
                        get: { choice == option }, set: { _ in choice = option }
                    )).accessibilityIdentifier("splitTaxChoice-" + option.rawValue)
                }
            }
            if choice == .people {
                Section {
                    ForEach(people) { person in
                        Button {
                            if selectedPeople.contains(person.id) { selectedPeople.remove(person.id) }
                            else { selectedPeople.insert(person.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(plan.color(for: person).tint).frame(width: 14, height: 14)
                                    .accessibilityHidden(true)
                                Text(person.name).frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: selectedPeople.contains(person.id) ? "checkmark.circle.fill" : "circle")
                                    .accessibilityHidden(true)
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(selectedPeople.contains(person.id) ? "Selected" : "Not selected")
                        .accessibilityIdentifier("splitTaxPayer-" + person.name)
                    }
                } footer: {
                    Text("One person pays the full tax. Select several people to divide it equally among them.")
                }
            }
            Section {
                DisclosureGroup("More options") {
                    Button("Choose taxable items", action: advanced)
                }
            }
        }
        .navigationTitle("Share tax").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Apply tax split") {
                guard let choice, validChoice else { return }
                let policy = SplitAdjustmentPolicy(id: adjustment.id,
                    method: choice == .proportional ? .proportional : .equal,
                    target: choice == .people ? .selectedPeople : .allPurchases,
                    selectedIDs: choice == .people ? selectedPeople.sorted { $0.uuidString < $1.uuidString } : [],
                    accepted: true)
                apply(policy)
            }
            .buttonStyle(ReceiptProminentStyle()).disabled(!validChoice)
            .accessibilityIdentifier("splitApplyTax")
            .modifier(ReceiptActionBarLayout()).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .onAppear {
            guard current.accepted, current.target != .selectedPurchases else { return }
            choice = current.target == .selectedPeople ? .people : current.method == .equal ? .equal : .proportional
            selectedPeople = Set(current.selectedIDs.filter { id in people.contains { $0.id == id } })
        }
    }
}

/// Standard full-row selection button: a native 44pt action with an explicit selected state.
private struct SplitSelectionRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var selection: Bool
    var body: some View {
        Button { selection.toggle() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selection ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
            }.foregroundStyle(Color(uiColor: .label)).frame(minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(title).accessibilityValue(selection ? "Selected" : "Not selected")
            .accessibilityHint(subtitle ?? "")
            .accessibilityAddTraits(selection ? .isSelected : [])
    }
}

/// Keep UIKit's native Back button and interactive edge gesture on split subpages.
private struct SplitEditorBack: ViewModifier {
    func body(content: Content) -> some View { content }
}

private extension SplitPersonColor {
    var tint: Color {
        switch self {
        case .blue: .blue
        case .teal: .teal
        case .amber: .orange
        case .rose: .pink
        case .violet: .purple
        case .slate: .gray
        }
    }
}

private struct SplitPersonEditor: View {
    let person: SplitParticipant
    let number: Int
    let save: (String, SplitPersonColor) -> Void
    let remove: () -> Void
    @State private var name: String
    @State private var color: SplitPersonColor
    @State private var confirmRemoval = false
    @Environment(\.dismiss) private var dismiss
    init(person: SplitParticipant, number: Int, color: SplitPersonColor,
         save: @escaping (String, SplitPersonColor) -> Void, remove: @escaping () -> Void) {
        self.person = person; self.number = number; self.save = save; self.remove = remove
        _name = State(initialValue: person.name == "Person \(number)" ? "" : person.name)
        _color = State(initialValue: color)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (optional)", text: $name).textContentType(.nickname)
                        .accessibilityIdentifier("splitName")
                    Text("Leave blank to use Person \(number).").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Color") {
                    ForEach(SplitPersonColor.allCases) { candidate in
                        Button { color = candidate } label: {
                            HStack {
                                Circle().fill(candidate.tint).frame(width: 20, height: 20)
                                Text(candidate.title)
                                Spacer()
                                if color == candidate { Image(systemName: "checkmark") }
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("splitColor-\(candidate.rawValue)")
                            .accessibilityValue(color == candidate ? "Selected" : "Not selected")
                    }
                }
                Section {
                    Button("Remove person", role: .destructive) { confirmRemoval = true }
                        .accessibilityIdentifier("splitRemovePerson")
                } footer: { Text("Removes only this person’s assignments. Any items left without owners must be assigned again.") }
            }
            .navigationTitle("Person \(number)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.accessibilityIdentifier("splitPersonCancel") }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        save(trimmed.isEmpty ? "Person \(number)" : trimmed, color); dismiss()
                    }.disabled(name.count > 80).accessibilityIdentifier("splitPersonApply")
                }
            }
            .confirmationDialog("Remove \(person.name)?", isPresented: $confirmRemoval, titleVisibility: .visible) {
                Button("Remove person", role: .destructive) { remove(); dismiss() }.accessibilityIdentifier("splitConfirmRemoval")
            } message: { Text("Their item memberships will be removed. Adjustment policies will need confirmation again.") }
        }
    }
}
