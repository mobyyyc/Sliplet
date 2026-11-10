import Foundation

struct SplitParticipant: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var number: Int? = nil
    var color: SplitPersonColor? = nil
}
enum SplitPersonColor: String, Codable, CaseIterable, Sendable, Identifiable {
    case blue, teal, amber, rose, violet, slate
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
enum SplitMethod: String, Codable, CaseIterable, Sendable, Identifiable {
    case proportional, equal
    var id: String { rawValue }
    var title: String { self == .proportional ? "Proportional" : "Equal" }
}
enum SplitTarget: String, Codable, CaseIterable, Sendable, Identifiable {
    case allPurchases, selectedPurchases, selectedPeople
    var id: String { rawValue }
    var title: String {
        switch self { case .allPurchases: "All purchases"; case .selectedPurchases: "Selected purchases"; case .selectedPeople: "Selected people" }
    }
}
struct SplitAdjustmentPolicy: Codable, Equatable, Sendable, Identifiable {
    var id: UUID // receipt adjustment identity
    var method: SplitMethod = .proportional
    var target: SplitTarget = .allPurchases
    var selectedIDs: [UUID] = []
    /// No retailer/jurisdiction inference. Only explicit source review permits a restricted tax base.
    var sourceConfirmed = false
    var accepted = false
}
struct ReceiptSplitPlan: Codable, Equatable, Sendable {
    var version = 1
    var id = UUID() // optimistic concurrency token, replaced on each committed plan write
    var participants: [SplitParticipant] = []
    var assignments: [UUID: [UUID]] = [:]
    var policies: [SplitAdjustmentPolicy] = []
    var finalizedRevision: UUID? = nil
    // Optional metadata keeps version-1 plans/backups readable; never reuse removed numbers.
    var nextPersonNumber: Int? = nil

    func number(for person: SplitParticipant) -> Int {
        if let number = person.number { return number }
        var used = Set(participants.compactMap(\.number))
        var candidate = 1
        for legacy in participants where legacy.number == nil {
            while used.contains(candidate) { candidate += 1 }
            if legacy.id == person.id { return candidate }
            used.insert(candidate)
        }
        return candidate
    }
    func color(for person: SplitParticipant) -> SplitPersonColor {
        person.color ?? SplitPersonColor.allCases[(number(for: person) - 1) % SplitPersonColor.allCases.count]
    }
    mutating func materializeAppearance() {
        for index in participants.indices {
            if participants[index].number == nil { participants[index].number = number(for: participants[index]) }
            if participants[index].color == nil { participants[index].color = color(for: participants[index]) }
        }
        nextPersonNumber = max(nextPersonNumber ?? 1, (participants.compactMap(\.number).max() ?? 0) + 1)
    }
    @discardableResult mutating func addPerson() -> UUID? {
        guard participants.count < 100 else { return nil }
        materializeAppearance()
        let number = nextPersonNumber ?? 1
        guard number < 1_000_000 else { return nil }
        let person = SplitParticipant(id: UUID(), name: "Person \(number)", number: number,
            color: SplitPersonColor.allCases[(number - 1) % SplitPersonColor.allCases.count])
        participants.append(person); nextPersonNumber = number + 1; finalizedRevision = nil
        for i in policies.indices { policies[i].accepted = false }
        return person.id
    }
    mutating func removePerson(_ id: UUID) {
        materializeAppearance()
        participants.removeAll { $0.id == id }
        assignments = assignments.mapValues { $0.filter { $0 != id } }
        for i in policies.indices {
            policies[i].accepted = false
            if policies[i].target == .selectedPeople {
                policies[i].selectedIDs.removeAll { $0 == id }; policies[i].sourceConfirmed = false
            }
        }
        finalizedRevision = nil
    }
    mutating func assign(_ person: UUID, selected: Set<UUID>, items: Set<UUID>) {
        guard participants.contains(where: { $0.id == person }), selected.isSubset(of: items) else { return }
        var changed = false
        for item in items {
            var owners = assignments[item, default: []]
            let wasSelected = owners.contains(person)
            guard wasSelected != selected.contains(item) else { continue }
            owners.removeAll { $0 == person }
            if selected.contains(item) { owners.append(person) }
            assignments[item] = owners; changed = true
        }
        if changed {
            finalizedRevision = nil
            for i in policies.indices { policies[i].accepted = false }
        }
    }

    func validateStructure() throws {
        let numbers = participants.compactMap(\.number)
        guard numbers.allSatisfy({ (1..<1_000_000).contains($0) }), Set(numbers).count == numbers.count,
              nextPersonNumber.map({ $0 > (numbers.max() ?? 0) && $0 <= 1_000_000 }) ?? true,
              version == 1, participants.count <= 100, assignments.count <= 10_000, policies.count <= 10_000,
              Set(participants.map(\.id)).count == participants.count,
              Set(policies.map(\.id)).count == policies.count,
              participants.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.name.count <= 80 }),
              assignments.values.allSatisfy({ $0.count <= 100 && Set($0).count == $0.count }),
              policies.allSatisfy({ $0.selectedIDs.count <= 10_000 && Set($0.selectedIDs).count == $0.selectedIDs.count }) else { throw SplitError.invalidPlan }
    }
    /// Keep choices for surviving identities; new lines remain unassigned/unconfirmed. Never retain finalization.
    func rebased(to fields: ReceiptFields) -> Self {
        var next = self
        next.id = UUID(); next.finalizedRevision = nil
        let items = Set(fields.items.map(\.id)), adjustments = Set(fields.adjustments.map(\.id))
        next.assignments = assignments.filter { items.contains($0.key) }
        next.policies = policies.filter { adjustments.contains($0.id) }.map { policy in
            var p = policy; p.accepted = false; p.sourceConfirmed = false
            if p.target == .selectedPurchases { p.selectedIDs = p.selectedIDs.filter(items.contains) }
            return p
        }
        return next
    }
}
enum SplitError: Error, Equatable, LocalizedError {
    case invalidPlan, receiptNeedsReview, incompleteAssignments, policiesNeedReview, invalidTargets, unknownTaxScope, zeroBase, overflow, discrepancy
    var errorDescription: String? {
        switch self {
        case .invalidPlan: "Use 1–100 people with names up to 80 characters and unique assignments."
        case .receiptNeedsReview: "Finish reviewing and reconciling this receipt before finalizing a split."
        case .incompleteAssignments: "Assign every purchase to at least one person. Remove stale assignments."
        case .policiesNeedReview: "Review and accept an allocation policy for every adjustment."
        case .invalidTargets: "Choose valid purchases or people for each adjustment."
        case .unknownTaxScope: "Confirm the tax scope against the original, or choose the all-purchases fallback."
        case .zeroBase: "Proportional allocation has no purchase value to use. Choose Equal for this adjustment."
        case .overflow: "These amounts exceed supported arithmetic bounds."
        case .discrepancy: "The split does not match the receipt total. Resolve the receipt discrepancy."
        }
    }
}
struct SplitComponent: Equatable, Sendable, Identifiable {
    let id: UUID
    let label: String
    let adjustment: Bool
    let shares: [UUID: Int64]
    let detail: String
}
struct ReceiptSplitResult: Equatable, Sendable {
    let currency: ReceiptCurrency
    let total: Int64
    let totals: [UUID: Int64]
    let components: [SplitComponent]
}

/// Pure integer arithmetic. Each line is apportioned once. UUID lexical order breaks remainder ties.
enum ReceiptSplitEngine {
    static func add(_ a: Int64, _ b: Int64) throws -> Int64 {
        let (value, overflow) = a.addingReportingOverflow(b)
        guard !overflow else { throw SplitError.overflow }; return value
    }
    /// Full-width products keep representable quotients even when amount*weight exceeds 64 bits.
    /// Allocate magnitudes, then restore the sign; Int64.min is supported without negation traps.
    static func allocate(_ amount: Int64, weights: [UUID: UInt64]) throws -> [UUID: Int64] {
        guard !weights.isEmpty else { throw SplitError.invalidTargets }
        let ids = weights.keys.sorted { $0.uuidString < $1.uuidString }
        var base: UInt64 = 0
        for id in ids {
            let (next, overflow) = base.addingReportingOverflow(weights[id]!)
            guard !overflow else { throw SplitError.overflow }; base = next
        }
        if base == 0 {
            guard amount == 0 else { throw SplitError.zeroBase }
            return Dictionary(uniqueKeysWithValues: ids.map { ($0, 0) })
        }
        var values: [UUID: UInt64] = [:], remainders: [UUID: UInt64] = [:]
        var assigned: UInt64 = 0
        for id in ids {
            let product = amount.magnitude.multipliedFullWidth(by: weights[id]!)
            // weight <= base makes the quotient <= magnitude; guard the division's precondition explicitly.
            guard product.high < base else { throw SplitError.overflow }
            let division = base.dividingFullWidth(product)
            values[id] = division.quotient; remainders[id] = division.remainder
            let (next, overflow) = assigned.addingReportingOverflow(division.quotient)
            guard !overflow else { throw SplitError.overflow }; assigned = next
        }
        let leftover = amount.magnitude - assigned
        guard leftover < UInt64(ids.count) else { throw SplitError.overflow }
        let ranking = ids.sorted {
            remainders[$0]! == remainders[$1]! ? $0.uuidString < $1.uuidString : remainders[$0]! > remainders[$1]!
        }
        for id in ranking.prefix(Int(leftover)) { values[id]! += 1 }
        return try Dictionary(uniqueKeysWithValues: ids.map { id in
            let value = values[id]!
            if amount < 0 && value == UInt64(Int64.max) + 1 { return (id, Int64.min) }
            guard value <= UInt64(Int64.max) else { throw SplitError.overflow }
            return (id, amount < 0 ? -Int64(value) : Int64(value))
        })
    }
    private struct OwnerBucket: Hashable { let owners: [UUID]; let negative: Bool }

    static func compute(_ record: ReceiptRecord, plan: ReceiptSplitPlan) throws -> ReceiptSplitResult {
        do { try record.validate() } catch { throw SplitError.invalidPlan }
        guard ReceiptCompletion.isComplete(record) else { throw SplitError.receiptNeedsReview }
        try plan.validateStructure()
        let fields = record.current.fields
        guard let currency = fields.currency, let total = fields.total, fields.items.count <= 10_000,
              fields.adjustments.count <= 10_000 else { throw SplitError.invalidPlan }
        let people = Set(plan.participants.map(\.id)), items = Set(fields.items.map(\.id))
        guard !people.isEmpty, Set(plan.assignments.keys) == items,
              plan.assignments.values.allSatisfy({ !$0.isEmpty && Set($0).isSubset(of: people) }) else { throw SplitError.incompleteAssignments }
        guard Set(plan.policies.map(\.id)) == Set(fields.adjustments.map(\.id)), plan.policies.allSatisfy(\.accepted) else { throw SplitError.policiesNeedReview }
        var totals = Dictionary(uniqueKeysWithValues: people.map { ($0, Int64(0)) })
        var components: [SplitComponent] = []
        var groupTotals: [OwnerBucket: Int64] = [:]
        var groupShares: [OwnerBucket: [UUID: Int64]] = [:]
        for item in fields.items {
            let owners = plan.assignments[item.id]!.sorted { $0.uuidString < $1.uuidString }
            // Separate sign buckets preserve floor/ceil-equal line shares when returns cross zero.
            // Their remainder prefixes cancel, so the net owner-set totals also differ by at most one unit.
            let bucket = OwnerBucket(owners: owners, negative: item.amount!.minorUnits < 0)
            let running = try add(groupTotals[bucket, default: 0], item.amount!.minorUnits)
            let cumulative = try allocate(running, weights: Dictionary(uniqueKeysWithValues: owners.map { ($0, 1) }))
            let previous = groupShares[bucket] ?? [:]
            let shares = try Dictionary(uniqueKeysWithValues: owners.map { id in
                let (value, overflow) = cumulative[id]!.subtractingReportingOverflow(previous[id, default: 0])
                guard !overflow else { throw SplitError.overflow }
                return (id, value)
            })
            groupTotals[bucket] = running; groupShares[bucket] = cumulative
            for (id, value) in shares { totals[id] = try add(totals[id]!, value) }
            components.append(.init(id: item.id, label: item.description ?? "Purchase", adjustment: false, shares: shares,
                detail: owners.count == 1 ? "Individual" : "Shared equally · \(owners.count) people"))
        }
        for adjustment in fields.adjustments {
            let policy = plan.policies.first { $0.id == adjustment.id }!
            let selection = Set(policy.selectedIDs)
            if policy.target == .allPurchases && !selection.isEmpty { throw SplitError.invalidTargets }
            if policy.target == .selectedPurchases && (selection.isEmpty || !selection.isSubset(of: items)) { throw SplitError.invalidTargets }
            if policy.target == .selectedPeople && (selection.isEmpty || !selection.isSubset(of: people)) { throw SplitError.invalidTargets }
            if adjustment.kind == .tax && policy.target != .allPurchases && !policy.sourceConfirmed { throw SplitError.unknownTaxScope }
            var weights: [UUID: UInt64] = [:]
            for component in components where !component.adjustment && (policy.target != .selectedPurchases || selection.contains(component.id)) {
                for (person, value) in component.shares where policy.target != .selectedPeople || selection.contains(person) {
                    // Absolute gross purchase shares handle return lines without negative allocation weights.
                    let (next, overflow) = weights[person, default: 0].addingReportingOverflow(value.magnitude)
                    guard !overflow else { throw SplitError.overflow }; weights[person] = next
                }
            }
            if policy.target == .selectedPeople {
                for person in selection where weights[person] == nil { weights[person] = 0 }
            }
            if policy.method == .equal {
                if policy.target == .allPurchases { weights = Dictionary(uniqueKeysWithValues: people.map { ($0, 1) }) }
                else { weights = weights.mapValues { _ in 1 } }
            }
            let shares = try allocate(adjustment.amount!.minorUnits, weights: weights)
            for (id, value) in shares { totals[id] = try add(totals[id]!, value) }
            let scope: String
            switch policy.target {
            case .allPurchases: scope = policy.method == .equal ? "All people" : "All purchase owners"
            case .selectedPurchases: scope = "Owners of " + fields.items.filter { selection.contains($0.id) }.map { $0.description ?? "Purchase" }.joined(separator: ", ")
            case .selectedPeople: scope = plan.participants.filter { selection.contains($0.id) }.sorted { $0.id.uuidString < $1.id.uuidString }.map(\.name).joined(separator: ", ")
            }
            let source = adjustment.kind == .tax && policy.target != .allPurchases ? " · Source-confirmed scope" : ""
            let fallback = adjustment.kind == .tax && policy.target == .allPurchases ? " · Unknown tax applicability fallback" : ""
            components.append(.init(id: adjustment.id, label: adjustment.label ?? adjustment.kind.rawValue, adjustment: true,
                shares: shares, detail: "\(policy.method.title) · \(scope)\(fallback)\(source)"))
        }
        // Stable accumulation, with checked bounds, is also used for the final invariant.
        let sum = try totals.keys.sorted { $0.uuidString < $1.uuidString }.reduce(Int64(0)) { try add($0, totals[$1]!) }
        guard sum == total.minorUnits else { throw SplitError.discrepancy }
        return .init(currency: currency, total: total.minorUnits, totals: totals, components: components)
    }
    static func summary(_ record: ReceiptRecord, plan: ReceiptSplitPlan) throws -> String {
        guard let revision = record.revisions.last, plan.finalizedRevision == revision.id else { throw SplitError.receiptNeedsReview }
        let result = try compute(record, plan: plan)
        func money(_ value: Int64) -> String { "\(result.currency.code) \(ExactInput.format(value, scale: result.currency.minorUnitScale))" }
        var lines = [record.current.fields.merchant ?? "Receipt", ExactInput.dateText(record.current.fields.purchaseDate), "Receipt total: \(money(result.total))"]
        for person in plan.participants.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            lines += ["", "\(person.name): \(money(result.totals[person.id]!))"]
            for component in result.components where component.shares[person.id] != nil {
                lines.append("  \(component.label): \(money(component.shares[person.id]!)) (\(component.detail))")
            }
        }
        lines += ["", "Proportional adjustments use each person’s purchase share before discounts and other adjustments; returns count by their positive value. Shared items with the same owners are rounded together so extra cents stay balanced. Other adjustments distribute extra cents consistently."]
        return lines.joined(separator: "\n")
    }
}
