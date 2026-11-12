import CoreFoundation
import Foundation

/// Implementations receive only the explicitly selected image. No OCR, labels or credentials
/// enter the canonical adapter. Settings/consent will supply a transport in a later milestone.
protocol ReceiptModelReader: Sendable {
    var provider: String { get }
    var model: String { get }
    func read(image: ReceiptImage) async throws -> ReceiptModelReading
}

struct ReceiptModelReading: Sendable {
    let extraction: ReceiptExtraction
    let draft: ReceiptReviewDraft
}

enum ReceiptModelError: Error { case malformedResponse, incompleteResponse, unsupportedShape }

/// All model text is untrusted data. No tool execution, inferred source boxes or balancing.
enum ReceiptModelAdapter {
    static let version = "p8-03-layout-v4"
    static let rootKeys: Set<String> = ["merchant", "date_raw", "date", "currency", "currency_raw", "subtotal", "total", "rows", "tax_legend"]
    static let rowKeys: Set<String> = ["kind", "description", "amount", "quantity", "unit", "unit_price", "raw_text", "product_code", "tax_marker", "tax_base", "tax_rate"]
    static let kinds: Set<String> = ["purchase", "return", "discount", "tax", "tip", "fee", "payment", "change", "other"]

    static func candidate(from envelope: Data) throws -> Data {
        guard envelope.count <= 262_144,
              let object = try JSONSerialization.jsonObject(with: envelope) as? [String: Any],
              let candidates = object["candidates"] as? [[String: Any]], candidates.count == 1,
              candidates[0]["finishReason"] as? String == "STOP",
              let content = candidates[0]["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { throw ReceiptModelError.incompleteResponse }
        var text = parts.filter { $0["thought"] as? Bool != true }.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json\n"), text.hasSuffix("```") { text = String(text.dropFirst(8).dropLast(3)) }
        return Data(text.utf8)
    }

    static func matches(_ pattern: String, _ text: String) -> [NSTextCheckingResult] {
        (try? NSRegularExpression(pattern: pattern))?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
    }
    static func group(_ match: NSTextCheckingResult, _ index: Int, _ text: String) -> String? {
        Range(match.range(at: index), in: text).map { String(text[$0]) }
    }
    static func token(_ input: String?) -> String? {
        guard var text = input?.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines), text.count <= 32 else { return nil }
        text = text.replacingOccurrences(of: "−", with: "-")
        var negative = false
        if !matches(#"^\([\d,.]+\)$"#, text).isEmpty { negative = true; text = String(text.dropFirst().dropLast()) }
        else if text.hasSuffix("-") { negative = true; text = String(text.dropLast()).trimmingCharacters(in: .whitespaces) }
        else if text.hasPrefix("-") { negative = true; text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces) }
        if text.hasPrefix("$") { text.removeFirst() }
        guard !matches(#"^(?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\.[0-9]{1,6})?$"#, text).isEmpty else { return nil }
        return (negative ? "-" : "") + text.replacingOccurrences(of: ",", with: "")
    }
    static func moneyText(_ input: String?) -> String? {
        guard let t = token(input), let value = Decimal(string: t, locale: Locale(identifier: "en_US_POSIX")),
              let minor = ExactInput.money(NSDecimalNumber(decimal: value).stringValue) else { return nil }
        return ExactInput.format(minor)
    }
    static func brand(_ text: String?) -> String? {
        guard let text else { return nil }
        let t = text.precomposedStringWithCompatibilityMapping.uppercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if !matches(#"\b(COMPARE|WITH|THAN|SHOP|AT|VISIT|FROM|SAVE|SAVINGS|BAG|PRODUCT|THANK|RETURN|NOT|LIKE|NEAR|OPPOSITE|TO)\b"#, t).isEmpty { return text }
        if !matches(#"^COSTCO(?:\s+WHOLESALE)?[ ®™*]*$"#, t).isEmpty { return "COSTCO" }
        if !matches(#"^(?:(?:[A-Z]+(?:[ -][A-Z]+)*['’]S)\s+)?NO\s*FRILLS$"#, t).isEmpty { return "NOFRILLS" }
        if !matches(#"^T\s*&\s*T(?:\s+SUPERMARKET)?$"#, t).isEmpty { return "T&T SUPERMARKET" }
        return text
    }
    static func date(_ raw: String?, brand: String?) -> String? {
        guard let raw else { return nil }
        var options = Set<String>()
        func add(_ year: Int, _ month: Int, _ day: Int) {
            if let value = try? ReceiptDate(year: year, month: month, day: day) { options.insert(ExactInput.dateText(value)) }
        }
        if let m = matches(#"\b(20[0-9]{2})[-/]([0-9]{2})[-/]([0-9]{2})\b"#, raw).first {
            add(Int(group(m, 1, raw)!)!, Int(group(m, 2, raw)!)!, Int(group(m, 3, raw)!)!)
        } else if let m = matches(#"\b([0-9]{1,2})/([0-9]{1,2})/((?:20)?[0-9]{2})\b"#, raw).first {
            let a = Int(group(m, 1, raw)!)!, b = Int(group(m, 2, raw)!)!, c = Int(group(m, 3, raw)!)!
            if brand == "NOFRILLS", group(m, 3, raw)!.count == 2, !matches(#"\b[0-9]{1,2}:[0-9]{2}|YY/MM/DD"#, raw).isEmpty { add(2000 + a, b, c) }
            else { let year = c >= 100 ? c : 2000 + c; if a <= 12 { add(year, a, b) }; if b <= 12 { add(year, b, a) } }
        } else {
            for format in ["dd-MMM-yyyy", "MMMM d, yyyy", "MMM d, yyyy"] {
                let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = format; formatter.isLenient = false
                if let parsed = formatter.date(from: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    var cal = Calendar(identifier: .gregorian); cal.timeZone = formatter.timeZone
                    let c = cal.dateComponents([.year, .month, .day], from: parsed); add(c.year!, c.month!, c.day!)
                }
            }
        }
        return options.count == 1 ? options.first : nil
    }

    static func recover(_ row: [String: Any], legend: String?) -> Bool {
        guard row["kind"] as? String == "purchase", let name = row["description"] as? String,
              let marker = row["tax_marker"] as? String, let amount = row["amount"] as? String,
              let raw = row["raw_text"] as? String, !matches("^[A-Z]{2,6}$", marker).isEmpty,
              name.split(whereSeparator: \.isWhitespace).last.map(String.init) != marker else { return false }
        let escaped = NSRegularExpression.escapedPattern(for: marker)
        if !matches("(?<!\\w)" + escaped + "(?!\\w)", legend ?? "").isEmpty { return false }
        let desc = name.split(whereSeparator: \.isWhitespace).map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "[ \\t]+")
        let head = "(?:^|\\n)[ \\t]*(?:\\(\\d+(?:\\.\\d+)?\\)[ \\t]*)?" + desc + "[ \\t]+" + escaped
        if !matches(head + "[ \\t]+" + NSRegularExpression.escapedPattern(for: amount) + "[ \\t]*(?:\\n|$)", raw).isEmpty { return true }
        let number = #"\d+(?:\.\d{1,6})?"#
        let pattern = head + #"[ \t]*\n[ \t]*("# + number + #")(?:[ \t]+([A-Za-z]+))?[ \t]*@[ \t]*\$?("# + number + #")(?:/([A-Za-z]+))?[ \t]+\$?("# + number + #")[ \t]*(?:\n|$)"#
        let found = matches(pattern, raw)
        guard found.count == 1 else { return false }
        let m = found[0]
        for (index, key) in [(1,"quantity"),(3,"unit_price"),(5,"amount")] {
            guard let actual = token(row[key] as? String), let literal = group(m, index, raw),
                  Decimal(string: actual) == Decimal(string: literal) else { return false }
        }
        for index in [2,4] {
            if let unit = group(m, index, raw), unit.lowercased() != (row["unit"] as? String)?.lowercased() { return false }
        }
        return true
    }

    static let departments: Set<String> = ["BAKERY", "DAIRY", "DELI", "FROZEN", "GROCERY", "GROCERIES", "MEAT", "PRODUCE", "SEAFOOD"]
    static func separateHeading(_ row: [String: Any]) -> String? {
        guard row["kind"] as? String == "purchase", let name = row["description"] as? String,
              let raw = row["raw_text"] as? String else { return nil }
        let parts = name.components(separatedBy: "\n")
        guard parts.count == 2, departments.contains(parts[0]), !parts[1].trimmingCharacters(in: .whitespaces).isEmpty,
              raw.hasPrefix(parts[0] + "\n" + parts[1]) else { return nil }
        let rest = raw.dropFirst(parts[0].count + 1 + parts[1].count)
        guard rest.isEmpty || rest.first!.isWhitespace else { return nil }
        return parts[1]
    }

    static func definesHSTMarker(_ label: String) -> Bool {
        !matches(#"(?i)^\s*H[ \t]*[=:][ \t]*HST\b"#, label).isEmpty
    }

    static func printedTaxLabels(_ rows: [[String: Any]]) -> [String] {
        // Model captures can have a printed tax charge before a currency is set.
        // Require the model's literal row to corroborate both label and charge.
        return rows.compactMap { row -> String? in
            guard row["kind"] as? String == "tax", let label = row["description"] as? String,
                  let raw = row["raw_text"] as? String,
                  let token = ReceiptModelAdapter.token(row["amount"] as? String),
                  let amount = Decimal(string: token, locale: Locale(identifier: "en_US_POSIX")), amount > 0 else { return nil }
            let labelWords = label.split(whereSeparator: \.isWhitespace)
            let printedWords = raw.split(whereSeparator: \.isWhitespace)
            guard !labelWords.isEmpty, printedWords.count > labelWords.count,
                  printedWords.starts(with: labelWords),
                  ReceiptModelAdapter.token(printedWords.last.map(String.init)).flatMap({
                      Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX"))
                  }) == amount else { return nil }
            return label
        }
    }

    private static func noFrillsCompositeName(_ row: [String: Any], name: String) -> String? {
        guard row["kind"] as? String == "purchase" else { return nil }
        var candidate = row
        let suffix = name.range(of: #"[ \t]+HMRJ$"#, options: .regularExpression)
        let clean = suffix.map { String(name[..<$0.lowerBound]) } ?? name
        guard !clean.isEmpty, suffix != nil || row["tax_marker"] as? String == "HMRJ" else { return nil }
        candidate["description"] = clean
        candidate["tax_marker"] = "HMRJ"
        return recover(candidate, legend: nil) ? clean : nil
    }

    private static func discountLabel(in raw: String, amount: String) -> String? {
        let tokens = ReceiptParser.monetaryTokens(raw)
        guard tokens.count == 1, let token = tokens.first, let range = Range(token.range, in: raw),
              let printed = ReceiptParser.printedMoney(String(raw[range])), printed < 0,
              printed == ExactInput.money(amount) else { return nil }
        return String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decode(_ envelope: Data, provider: String, model: String) throws -> ReceiptModelReading {
        let bytes = try candidate(from: envelope)
        guard var object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
            throw ReceiptModelError.unsupportedShape
        }
        // The model sometimes copies this literal from the request schema.
        // Check its JSON type explicitly: NSNumber also bridges numeric zero to Bool.
        if let echo = object["additionalProperties"] as? NSNumber,
           CFGetTypeID(echo) == CFBooleanGetTypeID(), !echo.boolValue {
            object.removeValue(forKey: "additionalProperties")
        }
        guard Set(object.keys) == rootKeys,
              let rows = object["rows"] as? [[String: Any]], rows.count <= 150 else { throw ReceiptModelError.unsupportedShape }
        func validStrings(_ object: [String: Any], excluding: Set<String>) -> Bool {
            object.filter { !excluding.contains($0.key) }.values.allSatisfy { $0 is NSNull || (($0 as? String).map { $0.utf8.count <= 8192 } ?? false) }
        }
        guard validStrings(object, excluding: ["rows"]), rows.allSatisfy({ rowKeys.isSubset(of: $0.keys) && Set($0.keys).isSubset(of: rowKeys.union(["discount_scope"])) && validStrings($0, excluding: []) && kinds.contains($0["kind"] as? String ?? "") }) else { throw ReceiptModelError.unsupportedShape }
        func string(_ key: String) -> String? { object[key] as? String }
        var draft = ReceiptReviewDraft(), issues: [ReceiptExtractionIssue] = []
        func issue(_ code: String) { issues.append(.init(code: code, sourceLineIDs: [], detail: nil)) }
        draft.merchant = brand(string("merchant")) ?? ""
        draft.date = date(string("date_raw"), brand: draft.merchant) ?? ""
        if draft.date.isEmpty { issue("model_date_needs_review") }
        if let currency = string("currency"), string("currency_raw")?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == currency,
           ExactInput.currency(currency) != nil { draft.currency = currency; draft.currencyOrigin = nil }
        draft.subtotal = moneyText(string("subtotal")) ?? ""; draft.total = moneyText(string("total")) ?? ""
        let noFrillsHST = draft.merchant == "NOFRILLS" && printedTaxLabels(rows).contains(where: definesHSTMarker)
        let rowIDs = rows.map { _ in UUID() }
        for (index, originalRow) in rows.enumerated() {
            var row = originalRow
            if let name = separateHeading(row) { row["description"] = name; issue("department_heading_needs_review") }
            let kind = row["kind"] as! String
            if ["other", "payment", "change"].contains(kind) { continue }
            var name = row["description"] as? String ?? "", marker = row["tax_marker"] as? String
            if noFrillsHST, let clean = noFrillsCompositeName(row, name: name) {
                name = clean
                marker = "HMRJ"
            } else if recover(row, legend: string("tax_legend")), let suffix = marker {
                name += " " + suffix; marker = nil; issue("description_boundary_needs_review")
            }
            let quantityToken = token(row["quantity"] as? String)
            let quantity = quantityToken.flatMap(ExactInput.decimal).map(ExactInput.quantity) ?? ""
            let rawUnit = row["unit"] as? String
            let unit = rawUnit.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !matches(#"[\d/@]"#, $0).isEmpty ? nil : $0 }
            let amount = moneyText(row["amount"] as? String) ?? ""
            let unitPrice = token(row["unit_price"] as? String)
            if kind == "purchase" || kind == "return" {
                name = ReceiptLine.removingUnitPrice(from: name, matching: unitPrice)
            }
            if amount.isEmpty { issue("missing_line_amount") }
            if row["quantity"] is String && quantity.isEmpty { issue("invalid_quantity_needs_review") }
            if let unitPrice, moneyText(unitPrice) == nil { issue("unit_price_precision_needs_review") }
            let rate = token(row["tax_rate"] as? String).flatMap(ExactInput.decimal)
            var scope: ReceiptDiscountScope?
            if kind == "discount", let printedScope = row["discount_scope"] as? String {
                if printedScope == "subtotal" {
                    scope = .subtotal
                } else if let rowNumber = Int(printedScope), (1...rows.count).contains(rowNumber),
                          let targetKind = rows[rowNumber - 1]["kind"] as? String,
                          targetKind == "purchase" || targetKind == "return" {
                    scope = .item(rowIDs[rowNumber - 1])
                }
            }
            draft.lines.append(.init(id: rowIDs[index], kind: kind == "return" ? "purchase" : (kind == "fee" ? "other" : kind), name: name,
                quantity: quantity, amount: amount, sourceLineIDs: [], sku: row["product_code"] as? String,
                unitPriceText: unitPrice, taxMarker: marker, rate: rate, unit: unit, discountScope: scope))
        }
        if draft.lines.contains(where: { $0.kind == "discount" }) {
            let references = ReceiptDiscountReferences(merchant: draft.merchant, items: draft.fields.items)
            let rawRows = Dictionary(uniqueKeysWithValues: zip(rowIDs, rows))
            for index in draft.lines.indices where draft.lines[index].kind == "discount" {
                let discount = draft.lines[index]
                let rawLabel = (rawRows[discount.id]?["raw_text"] as? String).flatMap {
                    discountLabel(in: $0, amount: discount.amount)
                }
                if let item = references.itemID(for: rawLabel) ?? references.itemID(for: discount.name) {
                    draft.lines[index].discountScope = .item(item)
                }
            }
        }
        issue("model_source_review_required")
        // Preserve recognized fields before applying a visible user default; never claim CAD was read.
        let fields = draft.fields
        let extraction = ReceiptExtraction(capturedAt: Date(), recognizer: provider, recognizerVersion: model,
            parser: "Sliplet image model adapter", parserVersion: version, rawOCR: [], rawParserOutput: envelope,
            fields: fields, issues: issues)
        try extraction.validate()
        draft.applyDefaultCurrency()
        return ReceiptModelReading(extraction: extraction, draft: draft)
    }
}

/// No default transport or embedded developer key. The caller must provide an
/// explicitly authorized request operation; production connection UI is P8-04/05.
struct GeminiReceiptReader: ReceiptModelReader {
    let provider = "Google Gemini"
    let model: String
    let response: @Sendable (ReceiptImage) async throws -> Data
    func read(image: ReceiptImage) async throws -> ReceiptModelReading {
        try Task.checkCancellation()
        let bytes = try await response(image)
        try Task.checkCancellation()
        return try ReceiptModelAdapter.decode(bytes, provider: provider, model: model)
    }
}


extension ReceiptExtraction {
    /// The same receipt must explicitly define the printed marker. Unmapped codes
    /// and bare tax totals do not establish which purchases were taxed.
    var paperTaxedMarkers: Set<String> {
        let candidate = modelTaxCandidate
        let legends = rawOCR.map(\.text) + [candidate?["tax_legend"] as? String].compactMap { $0 }
        var markers = Set<String>()
        for line in legends {
            for match in ReceiptModelAdapter.matches(
                #"(?im)^[ \t]*([A-Z0-9]{1,8})[ \t]*[=:–-][ \t]*TAXED[ \t]*$"#, line
            ) {
                if let marker = ReceiptModelAdapter.group(match, 1, line) { markers.insert(marker.uppercased()) }
            }
        }
        let taxLabels = fields.adjustments.compactMap { adjustment in
            adjustment.kind == .tax && (adjustment.amount?.minorUnits ?? 0) > 0 ? adjustment.label : nil
        }
        let modelTaxLabels = ReceiptModelAdapter.printedTaxLabels(candidate?["rows"] as? [[String: Any]] ?? [])
        if ReceiptModelAdapter.brand(fields.merchant) == "NOFRILLS",
           (taxLabels + modelTaxLabels).contains(where: ReceiptModelAdapter.definesHSTMarker) {
            markers.insert("HMRJ")
        }
        for label in taxLabels + modelTaxLabels {
            guard let match = ReceiptModelAdapter.matches(
                #"(?i)^\s*([A-Z0-9]{1,8})[ \t]*[=:][ \t]*(?:GST|HST|PST|QST|VAT|SALES TAX)\b"#, label
            ).first, let marker = ReceiptModelAdapter.group(match, 1, label) else { continue }
            markers.insert(marker.uppercased())
        }
        return markers
    }

    private var modelTaxCandidate: [String: Any]? {
        guard parser == "Sliplet image model adapter",
              let bytes = try? ReceiptModelAdapter.candidate(from: rawParserOutput) else { return nil }
        return (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any]
    }
}
