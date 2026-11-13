import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Local editing surface. Explicit Save/Finalize persist; Copy/Share exist only for the committed current split.
struct ReceiptSplitView: View {
    @Bindable var workspace: ReceiptWorkspace
    private enum Destination: Hashable { case item(UUID), policy(UUID), summary }
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
    private var result: ReceiptSplitResult? { record.flatMap { try? ReceiptSplitEngine.compute($0, plan: plan) } }
    private var failure: String? {
        guard let record else { return "Receipt unavailable." }
        do { _ = try ReceiptSplitEngine.compute(record, plan: plan); return nil }
        catch { return (error as? SplitError)?.errorDescription ?? "Check this split before finalizing." }
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
        NavigationStack(path: $path) {
            Form {
                if let person = plan.participants.first(where: { $0.id == activePerson }) {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            personBadge(person)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name).font(.headline).accessibilityIdentifier("splitActivePerson")
                                Text("\(selectedItems.count) selected · \(sharedCount) shared").font(.subheadline)
                            }.fixedSize(horizontal: false, vertical: true)
                        }
                        Button("Edit name or color") { editingPerson = person }.accessibilityIdentifier("splitEditPerson")
                    }
                } else {
                    peopleSection
                }
                if activePerson == nil {
                    Section {
                        Text(record?.current.fields.merchant ?? "Receipt").font(.headline)
                        if let total = record?.current.fields.total { LabeledContent("Receipt total") { Text(money(total.minorUnits)).foregroundStyle(Color(uiColor: .label)) } }
                        Text("\(assignedCount) of \(items.count) items assigned").font(.subheadline).foregroundStyle(.secondary)
                        if let record, !ReceiptCompletion.isComplete(record) {
                            Label(workspace.receiptReviewBlocker ?? "Finish this receipt before finalizing a split.",
                                  systemImage: "exclamationmark.triangle")
                            Button("Continue review", action: continueReview)
                                .accessibilityIdentifier("splitContinueReview")
                        }
                    }
                }
                if showsSplitDetails {
                    Section {
                        Picker("Show items", selection: $unassignedOnly) {
                            Text("All items").tag(false); Text("Unassigned").tag(true)
                        }.pickerStyle(.segmented).accessibilityIdentifier("splitItemFilter")
                        if activePerson != nil {
                            let selectionLayout = effectiveTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())
                            selectionLayout {
                                Button("Select unassigned") {
                                    selectedItems.formUnion(items.filter { plan.assignments[$0.id, default: []].isEmpty }.map(\.id))
                                }.accessibilityIdentifier("splitSelectUnassigned")
                                if !effectiveTypeSize.isAccessibilitySize { Spacer() }
                                Button("Clear selection") { selectedItems = [] }
                                    .accessibilityLabel("Clear this person’s selection")
                                    .accessibilityIdentifier("splitClearSelection")
                            }.buttonStyle(.borderless)
                        }
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
                    } header: { Text("Purchases") } footer: {
                        Text(activePerson == nil ? "Tap a purchase to see who shares it." : "Tap the items this person will pay for. Selecting an assigned item shares it equally.")
                    }
                }
                if activePerson == nil, showsSplitDetails, let record, !record.current.fields.adjustments.isEmpty {
                    Section {
                        ForEach(Array(record.current.fields.adjustments.enumerated()), id: \.element.id) { index, adjustment in
                            NavigationLink(value: Destination.policy(adjustment.id)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(adjustment.label ?? adjustment.kind.rawValue)
                                    if let amount = adjustment.amount { Text(money(amount.minorUnits)).font(.subheadline) }
                                    if let policy = plan.policies.first(where: { $0.id == adjustment.id }) {
                                        Text("\(policy.method.title) · \(policy.target.title) · \(policy.accepted ? "Confirmed" : "Needs confirmation")").font(.footnote)
                                    } else { Text("Choose an allocation policy").font(.footnote) }
                                }.foregroundStyle(Color(uiColor: .label))
                            }.accessibilityIdentifier("splitAdjustment-\(index)")
                        }
                    } header: { Text("Adjustments").foregroundStyle(Color(uiColor: .label)) } footer: {
                        Text("Confirm how each tax, discount or fee is shared before finalizing.")
                    }
                }
                if activePerson == nil, showsSplitDetails { Section {
                    if let result {
                        ForEach(plan.participants) { person in
                            LabeledContent(person.name) { Text(money(result.totals[person.id] ?? 0)).foregroundStyle(Color(uiColor: .label)) }.accessibilityIdentifier("splitTotal-\(person.name)")
                        }
                        LabeledContent("Exact total") { Text(money(result.total)).foregroundStyle(Color(uiColor: .label)) }.font(.headline).accessibilityElement(children: .combine).accessibilityIdentifier("splitExactTotal")
                        Text(summary == nil ? "Preview · finalize to copy or share." : "Finalized for this receipt revision.")
                            .accessibilityIdentifier("splitStatus")
                    } else if let failure { Text(failure).accessibilityIdentifier("splitFailure") }
                    if let error = workspace.errorMessage { Text(error).foregroundStyle(Color(uiColor: .label)) }
                    if let summary {
                        NavigationLink("View summary", value: Destination.summary)
                        Button("Copy summary", systemImage: "doc.on.doc") {
                            guard workspace.active, !workspace.privacyCovered else { return }
                            UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: summary]], options: [.localOnly: true])
                            copied = true
                        }.accessibilityIdentifier("splitCopy")
                        ShareLink(item: summary) { Label("Share summary", systemImage: "square.and.arrow.up") }.accessibilityIdentifier("splitShare")
                        if copied { Text("Copied on this device.").accessibilityIdentifier("splitCopied") }
                    }
                } header: { Text("Amounts").foregroundStyle(Color(uiColor: .label)) } }
            }
            .id(activePerson)
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .item(let id):
                    if let item = record?.current.fields.items.first(where: { $0.id == id }) { itemEditor(item) }
                case .policy(let id):
                    if let adjustment = record?.current.fields.adjustments.first(where: { $0.id == id }) { policyEditor(adjustment) }
                case .summary:
                    ScrollView { Text(summary ?? "Finalize this split first.").textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20) }
                        .navigationTitle("Split summary").modifier(SplitEditorBack())
                }
            }
            .navigationTitle(activePerson == nil ? "Split receipt" : "Assign items").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if path.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: closeSplit) { Text("Done") }.disabled(workspace.saving).accessibilityIdentifier("splitDone")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { source = true } label: { Text("Original") }.disabled(workspace.image == nil || workspace.saving).accessibilityIdentifier("splitOriginal")
                }

                }
            }
            .safeAreaBar(edge: .bottom, spacing: 0) {
                if path.isEmpty {
                    if activePerson != nil {
                        ReceiptPairedActions {
                            Button("Cancel") { cancelBatch() }.buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("splitBatchCancel")
                        } primary: {
                            Button("Apply items") { applyBatch() }.buttonStyle(ReceiptProminentStyle())
                                .accessibilityIdentifier("splitBatchApply")
                        }.modifier(ReceiptActionBarLayout())
                    } else if !plan.participants.isEmpty || !pristine || undoPlan != nil {
                        VStack(spacing: 8) {
                            ReceiptPairedActions {
                                Button("Save choices") { workspace.saveSplit(plan, finalize: false) }
                                    .buttonStyle(ReceiptSecondaryStyle())
                                    .disabled(workspace.saving || (try? plan.validateStructure()) == nil).accessibilityIdentifier("splitSave")
                            } primary: {
                                Button("Finalize") { workspace.saveSplit(plan, finalize: true) }
                                    .buttonStyle(ReceiptProminentStyle())
                                    .disabled(workspace.saving || result == nil || summary != nil).accessibilityIdentifier("splitFinalize")
                            }
                        }.modifier(ReceiptActionBarLayout())
                    }
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
                if let saved = record?.splitPlan { plan = saved; copied = false; undoPlan = nil; cancelBatch() }
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
    private var items: [ReceiptLine] { record?.current.fields.items ?? [] }
    private var assignedCount: Int { items.filter { !plan.assignments[$0.id, default: []].isEmpty }.count }
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
                if let marker = item.taxMarker { Text("Printed tax marker: \(marker). Applicability has not been inferred.").font(.footnote) }
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
        plan.policies.first { $0.id == adjustment.id } ?? .init(id: adjustment.id)
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
                Text("Proportional uses each person’s purchase share before discounts and other adjustments; returns count by their positive value. Equal includes all people for All purchases, selected item owners for Selected purchases, or the chosen people. A deposit or item coupon can be limited to the relevant purchases or people.").font(.footnote)
            }
            if p.target == .selectedPurchases, let record {
                Section {
                    ForEach(record.current.fields.items) { item in
                        SplitSelectionRow(title: item.description ?? "Purchase", selection: selection(adjustment, id: item.id))
                        if let marker = item.taxMarker { Text("Raw marker: \(marker)").font(.footnote) }
                    }
                } header: { Text("Included purchases").foregroundStyle(Color(uiColor: .label)) }
            }
            if p.target == .selectedPeople {
                Section { ForEach(plan.participants) { person in SplitSelectionRow(title: person.name, selection: selection(adjustment, id: person.id)) } } header: { Text("Included people").foregroundStyle(Color(uiColor: .label)) }
            }
            if adjustment.kind == .tax {
                Section {
                    Text("A printed tax marker can be ambiguous. Check the original tax legend to select taxable items. If it is unclear, choose All purchases and confirm how to share this tax.")
                    if p.target == .allPurchases { Label(p.method == .equal ? "Fallback: applicability unknown; share equally among all people." : "Fallback: applicability unknown; allocate by all purchase owners’ shares.", systemImage: "info.circle") }
                    else {
                        Button("Check original") { source = true }.disabled(workspace.image == nil)
                        SplitSelectionRow(title: "I verified this tax scope against the original", selection: Binding(get: { policy(adjustment).sourceConfirmed }, set: { confirmed in
                            setPolicy(adjustment) { $0.sourceConfirmed = confirmed; $0.accepted = false }
                        })).accessibilityIdentifier("splitTaxConfirmed")
                    }
                } header: { Text("Tax applicability").foregroundStyle(Color(uiColor: .label)) }
            }
            Section {
                SplitSelectionRow(title: adjustment.kind == .tax && p.target == .allPurchases ? "Accept this unknown-tax fallback" : "Confirm this allocation policy", selection: Binding(get: { policy(adjustment).accepted }, set: { accepted in
                    setPolicy(adjustment) { $0.accepted = accepted }
                })).accessibilityIdentifier("splitPolicyAccepted")
            }
        }.navigationTitle("Allocation policy").modifier(SplitEditorBack())
    }
    private func selection(_ adjustment: ReceiptAdjustment, id: UUID) -> Binding<Bool> {
        Binding(get: { policy(adjustment).selectedIDs.contains(id) }, set: { selected in
            setPolicy(adjustment) { p in toggle(id, in: &p.selectedIDs, selected: selected); p.accepted = false; p.sourceConfirmed = false }
        })
    }
}

/// Standard full-row selection button: a native 44pt action with an explicit selected state.
private struct SplitSelectionRow: View {
    let title: String
    @Binding var selection: Bool
    var body: some View {
        Button { selection.toggle() } label: {
            HStack(spacing: 12) {
                Text(title).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selection ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
            }.foregroundStyle(Color(uiColor: .label)).frame(minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(title).accessibilityValue(selection ? "Selected" : "Not selected")
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
