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
    private enum Pending { case select(UUID), add, close }
    @State private var pending: Pending?
    @State private var confirmBatch = false
    @State private var unassignedOnly = false
    @State private var source = false
    @State private var discard = false
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
                if activePerson == nil {
                    Section {
                        Text(record?.current.fields.merchant ?? "Receipt").font(.headline)
                        if let total = record?.current.fields.total { LabeledContent("Receipt total") { Text(money(total.minorUnits)).foregroundStyle(Color(uiColor: .label)) } }
                        Text("\(assignedCount) of \(items.count) items assigned").font(.subheadline).foregroundStyle(.secondary)
                        DisclosureGroup("How splitting works") {
                            Text("Add a person, select their items, then Apply. Selecting an owned item shares it equally. Save choices keeps an unfinished split; Finalize requires every item and adjustment reviewed.").font(.footnote)
                        }
                        if let record, !ReceiptCompletion.isComplete(record) {
                            Label("Receipt needs review. Finish its corrections first.", systemImage: "exclamationmark.triangle")
                        }
                    }
                }
                if effectiveTypeSize.isAccessibilitySize, let person = plan.participants.first(where: { $0.id == activePerson }) {
                    Section {
                        Text("\(selectedItems.count) selected · \(sharedCount) shared").fixedSize(horizontal: false, vertical: true)
                        Text(selectionSubtotal).font(.footnote).fixedSize(horizontal: false, vertical: true)
                        Button("Edit person") { editingPerson = person }.accessibilityIdentifier("splitEditPerson")
                    } header: { Text(person.name) }
                }
                Section {
                    if plan.participants.isEmpty {
                        Text("Add a person above to start. Names are optional.").foregroundStyle(.secondary)
                    }
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
                    Text(activePerson == nil ? "Choose a person above to assign several items. Tap an item to inspect all owners." : "Other owners stay assigned. Shared items are divided equally; adjustments are reviewed separately.")
                }
                if activePerson == nil, let record, !record.current.fields.adjustments.isEmpty {
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
                if activePerson == nil { Section {
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
            .navigationTitle("Split receipt").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if path.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button { request(.close) } label: { Text("Done") }.disabled(workspace.saving).accessibilityIdentifier("splitDone")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { source = true } label: { Text("Original") }.disabled(workspace.image == nil || workspace.saving).accessibilityIdentifier("splitOriginal")
                }

                }
            }
            .safeAreaBar(edge: .top, spacing: 0) {
                if path.isEmpty { peopleBar }
            }
            .safeAreaBar(edge: .bottom, spacing: 0) {
                if path.isEmpty {
                    if activePerson != nil {
                        ReceiptPairedActions {
                            Button("Cancel") { cancelBatch() }.buttonStyle(ReceiptSecondaryStyle()).accessibilityIdentifier("splitBatchCancel")
                        } primary: {
                            Button("Apply") { applyBatch() }.buttonStyle(ReceiptProminentStyle())
                                .accessibilityIdentifier("splitBatchApply")
                        }.modifier(ReceiptActionBarLayout())
                    } else {
                        VStack(spacing: 8) {
                            if undoPlan != nil { Button("Undo last assignment") { undoBatch() }.accessibilityIdentifier("splitUndoBatch") }
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
                } remove: { change { $0.removePerson(person.id) }; cancelBatch() }
            }
            .confirmationDialog("Apply this person’s item selection?", isPresented: $confirmBatch, titleVisibility: .visible) {
                Button("Apply and continue") { applyBatch(); continuePending() }
                Button("Discard selection", role: .destructive) { cancelBatch(); continuePending() }
                Button("Keep editing", role: .cancel) { pending = nil }
            }
            .sheet(isPresented: $source) { ReceiptSourceView(workspace: workspace) }
            .confirmationDialog("Discard unsaved split choices?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard choices", role: .destructive) { dismiss() }
            }
            .onChange(of: record?.splitPlan) { _, _ in
                if let saved = record?.splitPlan { plan = saved; copied = false; undoPlan = nil; cancelBatch() }
            }
            .onChange(of: workspace.active) { _, active in
                if !active { cancelBatch(); pending = nil; confirmBatch = false; editingPerson = nil; undoPlan = nil }
            }
            .onChange(of: workspace.privacyCovered) { _, covered in
                if covered { cancelBatch(); pending = nil; confirmBatch = false; editingPerson = nil; undoPlan = nil }
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
    private func cancelBatch() { activePerson = nil; selectedItems = [] }
    private func request(_ action: Pending) {
        if batchDirty { pending = action; confirmBatch = true }
        else { cancelBatch(); perform(action) }
    }
    private func continuePending() { if let action = pending { pending = nil; perform(action) } }
    private func perform(_ action: Pending) {
        switch action {
        case .close: if pristine { dismiss() } else { discard = true }
        case .add:
            var id: UUID?
            change { id = $0.addPerson() }
            if let id { activePerson = id; selectedItems = baselineSelection }
        case .select(let id): activePerson = id; selectedItems = baselineSelection
        }
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
    private func undoBatch() {
        guard let previous = undoPlan else { return }
        plan = previous; undoPlan = nil; copied = false
    }
    private var peopleBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
            if effectiveTypeSize.isAccessibilitySize {
                Menu {
                    ForEach(plan.participants) { person in
                        Button("\(person.name) · Person \(plan.number(for: person))") { request(.select(person.id)) }
                            .accessibilityIdentifier("splitPerson-\(plan.number(for: person))")
                    }
                } label: {
                    Text(plan.participants.first(where: { $0.id == activePerson }).map { "Person \(plan.number(for: $0))" } ?? "People")
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                }.disabled(plan.participants.isEmpty).accessibilityIdentifier("splitPeopleMenu").padding(.leading, 20)
            } else { ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(plan.participants) { person in
                        Button { request(.select(person.id)) } label: {
                            HStack { personBadge(person); Text(person.name).lineLimit(1).frame(maxWidth: 160) }
                                .padding(8)
                                .background(plan.color(for: person).tint.opacity(activePerson == person.id ? 0.22 : 0.08), in: Capsule())
                                .overlay(Capsule().strokeBorder(activePerson == person.id ? plan.color(for: person).tint : .clear, lineWidth: 2))
                        }.buttonStyle(.plain).accessibilityIdentifier("splitPerson-\(plan.number(for: person))")
                            .accessibilityLabel("\(person.name), person \(plan.number(for: person)), \(plan.color(for: person).title)")
                    }
                }.padding(.leading, 20)
            }.scrollIndicators(.hidden) }
                Button { request(.add) } label: { Image(systemName: "plus").fontWeight(.bold) }
                    .buttonStyle(ReceiptSecondaryStyle()).disabled(plan.participants.count >= 100)
                    .accessibilityLabel("Add person").accessibilityIdentifier("splitAddPerson")
                    .padding(.trailing, 20)
            }
            if !effectiveTypeSize.isAccessibilitySize, let person = plan.participants.first(where: { $0.id == activePerson }) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Assigning to \(person.name)").font(.subheadline.weight(.semibold))
                        Text("\(selectedItems.count) selected · \(sharedCount) shared").font(.footnote)
                        Text(selectionSubtotal).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button("Edit person") { editingPerson = person }.font(.subheadline).frame(minHeight: 44)
                        .accessibilityIdentifier("splitEditPerson")
                }.padding(.horizontal, 20)
            }
        }.padding(.vertical, 8)
    }
    private var sharedCount: Int {
        selectedItems.filter { item in plan.assignments[item, default: []].contains { $0 != activePerson } }.count
    }
    private var selectionSubtotal: String {
        do {
            let total = try items.filter { selectedItems.contains($0.id) }.reduce(Int64(0)) { partial, item in
                guard let amount = item.amount else { throw SplitError.invalidPlan }
                return try ReceiptSplitEngine.add(partial, amount.minorUnits)
            }
            return "Selected item totals: \(money(total)) · before sharing and adjustments"
        } catch { return "Selected total unavailable" }
    }
    private func personBadge(_ person: SplitParticipant) -> some View {
        Text("\(plan.number(for: person))").font(.caption.weight(.bold)).monospacedDigit()
            .frame(minWidth: 28, minHeight: 28)
            .background(plan.color(for: person).tint.opacity(0.18), in: Circle())
            .overlay(Circle().strokeBorder(plan.color(for: person).tint, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
    private func purchaseRow(_ item: ReceiptLine) -> some View {
        let selected = activePerson != nil && selectedItems.contains(item.id)
        let ids = Set(plan.assignments[item.id, default: []].filter { $0 != activePerson })
            .union(selected ? [activePerson!] : activePerson == nil ? plan.assignments[item.id, default: []] : [])
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
        }.foregroundStyle(.primary).padding(.vertical, 6).frame(minHeight: 48)
            .background(selected ? plan.participants.first(where: { $0.id == activePerson }).map { plan.color(for: $0).tint.opacity(0.10) } ?? .clear : .clear)
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
