import Foundation

struct EditableReceiptLine: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var kind: String
    var name: String
    var quantity: String
    var amount: String
    var sourceLineIDs: [UUID]
    var sku: String? = nil
    var unitPrice: ReceiptMoney? = nil
    /// Raw editable decimal survives even when currency is unknown or changed.
    var unitPriceText: String? = nil
    var editableUnitPrice: String {
        unitPriceText ?? unitPrice.map { ExactInput.format($0.minorUnits, scale: $0.currency.minorUnitScale) } ?? ""
    }
    var taxMarker: String? = nil
    var rate: ReceiptDecimal? = nil
    var unit: String? = nil
    static func blank(kind: String = "purchase") -> Self {
        .init(id: UUID(), kind: kind, name: "", quantity: "", amount: "", sourceLineIDs: [])
    }
}

struct ReceiptReviewDraft: Codable, Equatable, Sendable {
    var merchant = ""
    var date = ""
    enum CurrencyOrigin: String, Codable, Sendable { case defaultCAD, userSelected }
    /// Nil preserves legacy/recognized provenance; never writes context into raw extraction.
    var currencyOrigin: CurrencyOrigin? = nil
    var currency = "" {
        didSet { if currency != oldValue { currencyOrigin = .userSelected } }
    }
    var currencyContextMessage: String? {
        switch currencyOrigin {
        case .defaultCAD: "CAD is your default, not read from the receipt. Change it if needed."
        case .userSelected: "Currency selected by you. Amounts are not exchanged or converted."
        case nil: nil
        }
    }
    mutating func applyDefaultCurrency() {
        guard currency.isEmpty else { return }
        currency = "CAD"
        currencyOrigin = .defaultCAD
    }
    var lines: [EditableReceiptLine] = []
    var subtotal = ""
    var total = ""
    var subtotalNotPrinted = false
    var sourceOpened = false
    var sourceChecked = false
    /// Optional for backward-compatible decoding of installed drafts. Checks are scoped to current values.
    var guidanceChecks: [String: String]? = nil
    /// Optional encrypted history of explicit region-assisted edits; older drafts decode nil.
    var assistedReadings: [ReceiptAssistedReading]? = nil

    init() {}
    init(parsed: ParsedReceipt, useDefaultCurrency: Bool = false) {
        merchant = parsed.merchant ?? ""; date = ExactInput.dateText(parsed.date)
        currency = parsed.currency?.code ?? ""
        subtotal = parsed.subtotal.map { ExactInput.format($0) } ?? ""
        total = parsed.total.map { ExactInput.format($0) } ?? ""
        lines = parsed.lines.map {
            EditableReceiptLine(id: $0.id, kind: $0.kind, name: $0.description,
                quantity: ExactInput.quantity($0.quantity), amount: ExactInput.format($0.amount), sourceLineIDs: $0.sourceLineIDs,
                sku: $0.sku, unitPriceText: $0.unitPrice.map { ExactInput.format($0) }, taxMarker: $0.taxMarker, rate: $0.rate, unit: $0.unit?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
        }
        if useDefaultCurrency && !parsed.issues.contains(where: { $0.code == "currency_conflicting" }) { applyDefaultCurrency() }
    }
    init(fields: ReceiptFields) {
        merchant = fields.merchant ?? ""; date = ExactInput.dateText(fields.purchaseDate); currency = fields.currency?.code ?? ""
        func text(_ value: ReceiptMoney?) -> String { value.map { ExactInput.format($0.minorUnits, scale: $0.currency.minorUnitScale) } ?? "" }
        subtotal = text(fields.subtotal); total = text(fields.total)
        lines = fields.items.map {
            EditableReceiptLine(id: $0.id, kind: "purchase", name: $0.description ?? "", quantity: ExactInput.quantity($0.quantity),
                amount: text($0.amount), sourceLineIDs: $0.sourceLineIDs, sku: $0.sku, unitPrice: $0.unitPrice, taxMarker: $0.taxMarker, unit: $0.unit?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
        } + fields.adjustments.map {
            EditableReceiptLine(id: $0.id, kind: $0.kind.rawValue, name: $0.label ?? "", quantity: "", amount: text($0.amount),
                sourceLineIDs: $0.sourceLineIDs, rate: $0.rate)
        }
    }
    /// Raw editable values matter even while a typed value is temporarily malformed.
    func hasSameReceiptValues(as other: Self) -> Bool {
        merchant == other.merchant && date == other.date && currency == other.currency && currencyOrigin == other.currencyOrigin
            && lines == other.lines && subtotal == other.subtotal && total == other.total
            && subtotalNotPrinted == other.subtotalNotPrinted
    }
    var fields: ReceiptFields {
        let c = ExactInput.currency(currency)
        func money(_ value: String) -> ReceiptMoney? {
            guard let c, let cents = ExactInput.money(value, scale: c.minorUnitScale) else { return nil }
            return ReceiptMoney(minorUnits: cents, currency: c)
        }
        return ReceiptFields(merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            purchaseDate: ExactInput.date(date), currency: c,
            items: lines.filter { $0.kind == "purchase" }.map {
                ReceiptLine(id: $0.id, description: $0.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    sku: $0.sku, quantity: ExactInput.decimal($0.quantity),
                    unitPrice: money($0.editableUnitPrice), amount: money($0.amount),
                    taxMarker: $0.taxMarker, sourceLineIDs: $0.sourceLineIDs, unit: $0.unit?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
            }, adjustments: lines.filter { $0.kind != "purchase" }.map {
                ReceiptAdjustment(id: $0.id, kind: ReceiptAdjustment.Kind(rawValue: $0.kind) ?? .other,
                    label: $0.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty, amount: money($0.amount),
                    rate: $0.rate, sourceLineIDs: $0.sourceLineIDs)
            }, subtotal: money(subtotal), total: money(total))
    }
    var reconciliation: ReceiptReconciliation {
        var issues: [String] = []
        let f = fields
        if f.merchant == nil { issues.append("Merchant is missing.") }
        if f.purchaseDate == nil { issues.append("Choose the printed purchase date.") }
        if f.currency == nil { issues.append("Choose the currency printed on the receipt, or verify it with the store.") }
        if f.items.isEmpty { issues.append("Add the missing purchases.") }
        if lines.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { issues.append("Each line needs a description.") }
        if lines.contains(where: { !$0.quantity.isEmpty && ExactInput.decimal($0.quantity) == nil }) { issues.append("Quantities must be positive decimals (for example 1 or 0.375).") }
        let scale = f.currency?.minorUnitScale ?? 2
        if lines.contains(where: { ExactInput.money($0.amount, scale: scale) == nil }) { issues.append("Every line needs a valid printed amount.") }
        if lines.contains(where: { !$0.editableUnitPrice.isEmpty && ExactInput.money($0.editableUnitPrice, scale: scale) == nil }) { issues.append("Check unit prices for the selected currency. Values are kept unchanged; no rounding or exchange is applied.") }
        if lines.contains(where: { $0.kind == "discount" && (ExactInput.money($0.amount, scale: scale) ?? 0) > 0 }) { issues.append("Enter discounts as negative amounts.") }
        if f.total == nil { issues.append("The printed total is missing or invalid.") }
        if !subtotal.isEmpty && f.subtotal == nil { issues.append("The subtotal is invalid.") }
        if subtotal.isEmpty && !subtotalNotPrinted { issues.append("Enter the printed subtotal or confirm that it is not printed.") }
        var difference: Int64?
        var subtotalNote: String?
        do {
            try f.validate()
            if let c = f.currency, f.items.allSatisfy({ $0.amount != nil }), f.adjustments.allSatisfy({ $0.amount != nil }), let total = f.total {
                let zero = ReceiptMoney(minorUnits: 0, currency: c)
                let purchaseSum = try f.items.reduce(zero) { try $0.adding($1.amount!) }
                let all = try f.adjustments.reduce(purchaseSum) { try $0.adding($1.amount!) }
                difference = try total.subtracting(all).minorUnits
                if difference != 0 { issues.append("Line amounts and adjustments do not match the printed total.") }
                if let subtotal = f.subtotal {
                    let discounted = try f.adjustments.filter { $0.kind == .discount }.reduce(purchaseSum) { try $0.adding($1.amount!) }
                    if subtotal == purchaseSum { subtotalNote = "Subtotal matches purchases before separate discounts." }
                    else if subtotal == discounted { subtotalNote = "Subtotal matches purchases after separate discounts." }
                    else {
                        let nonTax = try f.adjustments.filter { $0.kind != .tax && $0.kind != .tip }.reduce(purchaseSum) { try $0.adding($1.amount!) }
                        if subtotal == nonTax { subtotalNote = "Subtotal matches purchases and all separate non-tax adjustments (excluding tips)." }
                        else { issues.append("Subtotal does not match purchases before or after the printed non-tax adjustments. Check source lines and classifications.") }
                    }
                }
            }
        } catch { issues.append("These values exceed supported arithmetic bounds or use inconsistent currencies.") }
        return ReceiptReconciliation(issues: issues, difference: difference, subtotalNote: subtotalNote)
    }
    var canFinalize: Bool { reconciliation.issues.isEmpty && sourceOpened && sourceChecked }
    /// Drafts allow missing fields, never malformed typed values that would be silently discarded.
    var canSaveDraft: Bool {
        guard (try? validateAssistedReadings()) != nil else { return false }
        let scale = ExactInput.currency(currency)?.minorUnitScale ?? 2
        return (date.isEmpty || ExactInput.date(date) != nil)
            && (currency.isEmpty || ExactInput.currency(currency) != nil)
            && (subtotal.isEmpty || ExactInput.money(subtotal, scale: scale) != nil)
            && (total.isEmpty || ExactInput.money(total, scale: scale) != nil)
            && lines.allSatisfy { ($0.amount.isEmpty || ExactInput.money($0.amount, scale: scale) != nil)
                && ($0.quantity.isEmpty || ExactInput.decimal($0.quantity) != nil)
                && ($0.editableUnitPrice.isEmpty || ExactInput.money($0.editableUnitPrice, scale: scale) != nil) }

    }
}

struct ReceiptReconciliation: Equatable, Sendable {
    let issues: [String]
    let difference: Int64?
    let subtotalNote: String?
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// This is the gate future splitting must use, in addition to complete participant assignment.
enum ReceiptCompletion {
    static func isComplete(_ record: ReceiptRecord) -> Bool {
        var draft = ReceiptReviewDraft(fields: record.current.fields)
        draft.subtotalNotPrinted = record.current.fields.subtotal == nil
        draft.sourceOpened = true; draft.sourceChecked = record.current.review == .sourceReviewed
        return draft.canFinalize
    }
}

/// Revocation can occur synchronously during a UI lifecycle callback while a store actor is busy.
final class ReceiptOperationPermit: @unchecked Sendable {
    private let lock = NSLock()
    private var valid = true
    func revoke() { lock.lock(); valid = false; lock.unlock() }
    /// Commit and lifecycle revocation are mutually exclusive. A commit already in progress
    /// completes before revocation returns; queued or revoked writes roll back.
    func committing<T>(_ body: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        guard valid, !Task.isCancelled else { throw CancellationError() }
        return try body()
    }
    func check() throws {
        lock.lock(); let allowed = valid; lock.unlock()
        if !allowed || Task.isCancelled { throw CancellationError() }
    }
}

/// Explicit human-selected recovery targets. No automatic field or row assignment.
enum ReceiptAssistedField: String, Codable, CaseIterable, Sendable {
    case merchant, date, subtotal, total, description, amount, quantity
    var title: String {
        switch self {
        case .merchant: "Merchant"
        case .date: "Purchase date"
        case .subtotal: "Subtotal"
        case .total: "Total"
        case .description: "Description"
        case .amount: "Line amount"
        case .quantity: "Quantity"
        }
    }
    var needsLine: Bool { self == .description || self == .amount || self == .quantity }
    var isMoney: Bool { self == .subtotal || self == .total || self == .amount }
}

struct ReceiptAssistedChoice: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let observationID: UUID
    /// UTF-16 offsets into the retained observation, never offsets into normalized text.
    let rangeStart: Int
    let rangeLength: Int
    let literal: String
    let value: String
}

/// Historical explicit edit event. Later manual changes do not rewrite this evidence.
/// Region and observation boxes are in the original upright image's normalized space.
struct ReceiptAssistedReading: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let date: Date
    let assetSHA256: Data
    let region: ReceiptOCRBox
    let revision: Int
    let observations: [ReceiptOCRLine]
    let choice: ReceiptAssistedChoice
    let field: ReceiptAssistedField
    let lineID: UUID?
    let previousValue: String
    let currency: ReceiptCurrency?
    var value: String { choice.value }

    static let maximumEvents = 32
    static let maximumObservations = 128
    static let maximumTextBytes = 256 * 1_024

    static func choices(lines: [ReceiptOCRLine], field: ReceiptAssistedField,
                        currency: ReceiptCurrency?) -> [ReceiptAssistedChoice] {
        guard lines.count <= maximumObservations else { return [] }
        return lines.flatMap { observation -> [ReceiptAssistedChoice] in
            let text = observation.text
            guard text.utf8.count <= 8_192 else { return [] }
            let ranges: [NSRange]
            switch field {
            case .merchant, .description:
                let literal = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !literal.isEmpty, let range = text.range(of: literal) else { return [] }
                ranges = [NSRange(range, in: text)]
            case .date:
                // Year-first dates have no month/day convention ambiguity.
                ranges = ReceiptParser.matches(#"(?<![\p{L}\d/.-])\d{4}[-/]\d{2}[-/]\d{2}(?![\p{L}\d/.-])"#, text).map(\.range)
            case .subtotal, .total, .amount, .quantity:
                // Whole whitespace tokens only: never strip a sign, unit, parentheses,
                // percentage, or ambiguous punctuation to manufacture a valid number.
                ranges = ReceiptParser.matches(#"\S+"#, text).map(\.range)
            }
            return ranges.compactMap { nsRange in
                guard let range = Range(nsRange, in: text) else { return nil }
                let literal = String(text[range])
                let value: String
                switch field {
                case .merchant, .description: value = literal
                case .date:
                    guard !(literal.contains("/") && literal.contains("-")) else { return nil }
                    let normalized = literal.replacingOccurrences(of: "/", with: "-")
                    guard let parsed = ExactInput.date(normalized) else { return nil }
                    value = ExactInput.dateText(parsed)
                case .subtotal, .total, .amount:
                    let prefix = String(text[..<range.lowerBound])
                    let suffix = String(text[range.upperBound...])
                    guard ReceiptParser.first(#"(?:[-+]|\()\s*\$?\s*$"#, prefix) == nil,
                          ReceiptParser.first(#"^\s*(?:[-)%]|/\s*(?:KG|LBS?))"#, suffix) == nil else { return nil }
                    guard let currency, currency == ExactInput.currency(currency.code),
                          let amount = ExactInput.money(literal, scale: currency.minorUnitScale) else { return nil }
                    value = ExactInput.format(amount, scale: currency.minorUnitScale)
                case .quantity:
                    let prefix = String(text[..<range.lowerBound])
                    let suffix = String(text[range.upperBound...])
                    guard ReceiptParser.first(#"(?:[-+]|\()\s*$"#, prefix) == nil,
                          ReceiptParser.first(#"^\s*[-)%/]"#, suffix) == nil,
                          let quantity = ExactInput.decimal(literal) else { return nil }
                    value = ExactInput.quantity(quantity)
                }
                return ReceiptAssistedChoice(id: "\(observation.id.uuidString):\(nsRange.location):\(nsRange.length):\(field.rawValue)",
                    observationID: observation.id, rangeStart: nsRange.location, rangeLength: nsRange.length,
                    literal: literal, value: value)
            }
        }
    }

    func validate(assetSHA256 expectedHash: Data?) throws {
        guard assetSHA256.count == 32, expectedHash.map({ $0 == assetSHA256 }) ?? true,
              date.timeIntervalSince1970.isFinite, revision > 0,
              field.needsLine == (lineID != nil), !observations.isEmpty,
              observations.count <= Self.maximumObservations,
              Set(observations.map(\.id)).count == observations.count,
              previousValue.utf8.count <= 8_192,
              currency.map({ $0 == ExactInput.currency($0.code) }) ?? true else {
            throw ReceiptValidationError.invalidEvidence
        }
        try ReceiptReadingPass(lines: observations, revision: revision, usesLanguageCorrection: false).validate()
        for observation in observations {
            guard let box = observation.boundingBox,
                  box.x >= region.x - 0.000_001, box.y >= region.y - 0.000_001,
                  box.x + box.width <= region.x + region.width + 0.000_001,
                  box.y + box.height <= region.y + region.height + 0.000_001 else {
                throw ReceiptValidationError.invalidEvidence
            }
        }
        guard Self.choices(lines: observations, field: field, currency: currency).contains(choice) else {
            throw ReceiptValidationError.invalidEvidence
        }
    }
}

extension ReceiptReviewDraft {
    func assistedValue(field: ReceiptAssistedField, lineID: UUID? = nil) -> String? {
        guard field.needsLine == (lineID != nil) else { return nil }
        switch field {
        case .merchant: return merchant
        case .date: return date
        case .subtotal: return subtotal
        case .total: return total
        case .description: return lines.first { $0.id == lineID }?.name
        case .amount: return lines.first { $0.id == lineID }?.amount
        case .quantity: return lines.first { $0.id == lineID }?.quantity
        }
    }

    func validateAssistedReadings(assetSHA256: Data? = nil) throws {
        guard let history = assistedReadings else { return }
        guard history.count <= ReceiptAssistedReading.maximumEvents,
              Set(history.map(\.id)).count == history.count else { throw ReceiptValidationError.invalidEvidence }
        var bytes = 0
        var hash = assetSHA256
        for event in history {
            try event.validate(assetSHA256: hash)
            hash = event.assetSHA256
            bytes += event.previousValue.utf8.count + event.choice.literal.utf8.count + event.choice.value.utf8.count
            bytes += event.observations.reduce(0) { $0 + $1.text.utf8.count }
            guard bytes <= ReceiptAssistedReading.maximumTextBytes else { throw ReceiptValidationError.invalidEvidence }
        }
    }

    mutating func useAssistedReading(_ reading: ReceiptAssistedReading) throws {
        guard assistedValue(field: reading.field, lineID: reading.lineID) == reading.previousValue,
              !reading.field.isMoney || ExactInput.currency(currency) == reading.currency else {
            throw ReceiptValidationError.invalidEvidence
        }
        // Work transactionally: validation/cap failures never partially change a field.
        var next = self
        next.assistedReadings = (assistedReadings ?? []) + [reading]
        try next.validateAssistedReadings()
        switch reading.field {
        case .merchant: next.merchant = reading.value
        case .date: next.date = reading.value
        case .subtotal: next.subtotal = reading.value; next.subtotalNotPrinted = false
        case .total: next.total = reading.value
        case .description, .amount, .quantity:
            guard let index = next.lines.firstIndex(where: { $0.id == reading.lineID }) else {
                throw ReceiptValidationError.invalidEvidence
            }
            switch reading.field {
            case .description: next.lines[index].name = reading.value
            case .amount: next.lines[index].amount = reading.value
            case .quantity: next.lines[index].quantity = reading.value
            default: break
            }
        }
        next.sourceChecked = false
        self = next
    }
}
