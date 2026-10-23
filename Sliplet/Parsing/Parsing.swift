import Foundation

/// T03's geometric row grouping and deterministic parser, ported to Swift.
/// OCR observations and parser output are retained separately. No inferred tax arithmetic.
struct ParsedReceipt: Codable, Sendable {
    struct Line: Codable, Sendable {
        var kind: String
        var description: String
        var amount: Int64
        var quantity: ReceiptDecimal?
        var sourceLineIDs: [UUID]
        var id = UUID()
        // Optional for decoding historical parser evidence unchanged.
        var sku: String? = nil
        var unitPrice: Int64? = nil
        var taxMarker: String? = nil
        var rate: ReceiptDecimal? = nil
        var unit: String? = nil
    }
    var merchant: String?
    var date: ReceiptDate?
    var currency: ReceiptCurrency?
    var subtotal: Int64?
    var total: Int64?
    var lines: [Line] = []
    var issues: [ReceiptExtractionIssue] = []

    func fields() -> ReceiptFields {
        func money(_ value: Int64?) -> ReceiptMoney? {
            guard let currency, let value else { return nil }
            return ReceiptMoney(minorUnits: value, currency: currency)
        }
        return ReceiptFields(merchant: merchant, purchaseDate: date, currency: currency,
            items: lines.filter { $0.kind == "purchase" }.map {
                ReceiptLine(id: $0.id, description: $0.description, sku: $0.sku, quantity: $0.quantity,
                            unitPrice: money($0.unitPrice), amount: money($0.amount), taxMarker: $0.taxMarker,
                            sourceLineIDs: $0.sourceLineIDs, unit: $0.unit)
            }, adjustments: lines.filter { $0.kind != "purchase" }.map {
                ReceiptAdjustment(id: $0.id, kind: ReceiptAdjustment.Kind(rawValue: $0.kind) ?? .other,
                                  label: $0.description, amount: money($0.amount), rate: $0.rate, sourceLineIDs: $0.sourceLineIDs)
            }, subtotal: money(subtotal), total: money(total))
    }
}

enum ExactInput {
    static let maximumMinorUnits: Int64 = 100_000_000_000
    static func money(_ input: String, scale: UInt8 = 2) -> Int64? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 24 else { return nil }
        let negative = text.hasPrefix("-") || text.hasSuffix("-")
        guard !(text.hasPrefix("-") && text.hasSuffix("-")) else { return nil }
        if text.hasPrefix("-") { text.removeFirst() }
        if text.hasSuffix("-") { text.removeLast() }
        if text.hasPrefix("$") { text.removeFirst() }
        if text.contains(",") {
            guard ReceiptParser.first(#"^\d{1,3}(?:,\d{3})+(?:\.\d{1,6})?$"#, text) == text else { return nil }
            text = text.replacingOccurrences(of: ",", with: "")
        }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, !parts[0].isEmpty,
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              parts.count == 1 || (!parts[1].isEmpty && parts[1].count <= Int(scale)),
              let whole = Int64(parts[0]), scale <= 6 else { return nil }
        let multiplier = (0..<scale).reduce(Int64(1)) { value, _ in value * 10 }
        let (base, overflow) = whole.multipliedReportingOverflow(by: multiplier)
        guard !overflow else { return nil }
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        let tail = Int64(fraction + String(repeating: "0", count: Int(scale) - fraction.count)) ?? 0
        let (sum, addedOverflow) = base.addingReportingOverflow(tail)
        guard !addedOverflow, sum <= maximumMinorUnits else { return nil }
        return negative ? -sum : sum
    }
    static func decimal(_ input: String) -> ReceiptDecimal? {
        let parts = input.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 2, !parts[0].isEmpty,
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }),
              (parts.count == 1 || parts[1].count <= 9), let coefficient = Int64(parts.joined()), coefficient > 0 else { return nil }
        return try? ReceiptDecimal(coefficient: coefficient, scale: UInt8(parts.count == 2 ? parts[1].count : 0))
    }
    static func format(_ value: Int64, scale: UInt8 = 2) -> String {
        let digits = String(value.magnitude)
        guard scale > 0 else { return (value < 0 ? "-" : "") + digits }
        let padded = String(repeating: "0", count: max(0, Int(scale) + 1 - digits.count)) + digits
        let index = padded.index(padded.endIndex, offsetBy: -Int(scale))
        return (value < 0 ? "-" : "") + padded[..<index] + "." + padded[index...]
    }
    static func quantity(_ value: ReceiptDecimal?) -> String {
        value.map { format($0.coefficient, scale: $0.scale) } ?? ""
    }
    static func date(_ text: String) -> ReceiptDate? {
        let p = text.split(separator: "-")
        guard p.count == 3, p[0].count == 4, let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]) else { return nil }
        return try? ReceiptDate(year: y, month: m, day: d)
    }
    static func dateText(_ value: ReceiptDate?) -> String {
        value.map { String(format: "%04d-%02d-%02d", $0.year, $0.month, $0.day) } ?? ""
    }
    static let currencies: [String: UInt8] = ["CAD": 2, "USD": 2, "EUR": 2, "GBP": 2, "CNY": 2, "HKD": 2, "JPY": 0]
    static func currency(_ code: String) -> ReceiptCurrency? {
        guard let scale = currencies[code] else { return nil }
        return try? ReceiptCurrency(code: code, minorUnitScale: scale)
    }
}

enum ReceiptParser {
    static let version = "p7-06-weight-extensions-0.7.1"
    struct Row { var text: String; var ids: [UUID]; var center: Double; var height: Double; var parts: [ReceiptOCRLine] }
    static func matches(_ pattern: String, _ text: String) -> [NSTextCheckingResult] {
        (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
    }
    static func first(_ pattern: String, _ text: String) -> String? {
        guard let match = matches(pattern, text).first, let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }
    static func rows(_ lines: [ReceiptOCRLine]) -> [Row] {
        // Without complete geometry, input order is the only trustworthy ordering.
        if lines.contains(where: { $0.boundingBox == nil }) {
            return lines.enumerated().map { index, line in
                Row(text: line.text, ids: [line.id], center: -Double(index), height: 0, parts: [line])
            }
        }
        var groups: [Row] = []
        for line in lines.sorted(by: {
            let a = $0.boundingBox, b = $1.boundingBox
            if a == nil || b == nil { return false }
            let ay = a!.y + a!.height / 2, by = b!.y + b!.height / 2
            return ay == by ? a!.x < b!.x : ay > by
        }) {
            guard let box = line.boundingBox else {
                groups.append(Row(text: line.text, ids: [line.id], center: -Double(groups.count), height: 0, parts: [line])); continue
            }
            let center = box.y + box.height / 2
            if let index = groups.firstIndex(where: { abs($0.center - center) <= min($0.height, box.height) * 0.45 }) {
                groups[index].parts.append(line)
            } else { groups.append(Row(text: "", ids: [], center: center, height: box.height, parts: [line])) }
        }
        return groups.sorted { $0.center > $1.center }.map { group in
            var group = group
            let parts = group.parts.sorted { ($0.boundingBox?.x ?? 0) < ($1.boundingBox?.x ?? 0) }
            group.text = parts.map(\.text).joined(separator: " ")
            group.ids = parts.map(\.id)
            return group
        }
    }
    static let moneyPattern = #"(?<![\d.,])(-?\$?(?:(?:\d{1,3}(?:,\d{3})+|\d{1,7})\.\d{2}|\d{1,7},\d{2})-?)(?![\d.,])"#
    /// Decimal comma is accepted only with exactly two fractional digits and no dot.
    /// This never inserts a missing separator, sign or currency.
    static func printedMoney(_ token: String) -> Int64? {
        if !token.contains("."), token.filter({ $0 == "," }).count == 1,
           first(#"^-?\$?\d{1,7},\d{2}-?$"#, token) == token {
            return ExactInput.money(token.replacingOccurrences(of: ",", with: "."))
        }
        return ExactInput.money(token)
    }
    static func monetaryTokens(_ text: String) -> [NSTextCheckingResult] {
        matches(moneyPattern, text).filter { token in
            guard let range = Range(token.range, in: text) else { return false }
            let tail = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
            return !tail.hasPrefix("%") && first(#"^(?:KG|LBS|LB|X)\b|^@"#, tail) == nil
        }
    }
    static func firstPrintedMoney(_ text: String) -> Int64? {
        guard let token = monetaryTokens(text).first, let range = Range(token.range, in: text) else { return nil }
        return printedMoney(String(text[range]))
    }
    static func printedSKU(_ description: String) -> String? {
        // Keep the full printed description. Only explicit SKU labels or long leading
        // product codes are metadata; short leading numbers may instead be quantities.
        if let marked = first(#"^SKU\s*[:#]?\s*\d{1,14}\b"#, description) {
            return first(#"\d{1,14}"#, marked)
        }
        guard let prefix = first(#"^(?:[AEHN]\s+)?\d{5,14}\s+(?=\p{L})"#, description) else { return nil }
        return first(#"\d{5,14}"#, prefix)
    }
    static func printedUnit(_ text: String) -> String? {
        guard let quantity = first(quantityPattern, text) else { return nil }
        return first(#"\b(?:KG|LBS|LB)\b"#, quantity)?.uppercased()
    }
    static func printedTaxRate(_ text: String) -> ReceiptDecimal? {
        let tokens = matches(#"(?<![\d.,])\d{1,3}(?:[.,]\d{1,6})?\s*%"#, text)
        guard tokens.count == 1, let range = Range(tokens[0].range, in: text) else { return nil }
        let numeric = text[range].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        let pieces = numeric.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= 2, let coefficient = Int64(pieces.joined()), coefficient >= 0 else { return nil }
        let scale = pieces.count == 2 ? pieces[1].count : 0
        guard scale <= 6 else { return nil }
        return try? ReceiptDecimal(coefficient: coefficient, scale: UInt8(scale + 2))
    }
    static let quantityPattern = #"\b\d+(?:\.\d+)?\s*(?:(?:KG|LB|LBS|X)\b|@)"#
    static let metadataPattern = #"^(?:CASH|VISA|MASTERCARD|DEBIT|CREDIT|CHANGE|TENDER|BALANCE|SAVINGS|YOU SAVED|MEMBER|REGISTER|AUTH|TRANSACTION|STORE|TERMINAL|TEL|PHONE|DATE|TIME|ITEMS SOLD|TOTAL ITEMS|TOTAL NUMBER OF ITEMS|TOTAL SAVINGS|TOTAL DISCOUNT)\b"#

    /// Strip decoration for field classification only; purchase descriptions/SKUs stay intact.
    static func fieldText(_ text: String) -> String {
        text.replacingOccurrences(of: #"^[\s*:=]+"#, with: "", options: .regularExpression).uppercased()
    }
    enum SummaryKind { case subtotal, total }

    /// Match a complete field label, not a product that happens to begin with TOTAL.
    /// Only label decoration is normalized; financial characters are never repaired.
    static func summaryLabel(_ text: String) -> (kind: SummaryKind, remainder: String)? {
        let value = text.replacingOccurrences(of: #"^[\s*:=#•·_]+"#, with: "", options: .regularExpression).uppercased()
        let labels: [(SummaryKind, String)] = [
            (.subtotal, #"^(?:SUB\s*TOTAL|SOUS[- ]?TOTAL)\b"#),
            (.total, #"^(?:GRAND\s+TOTAL|TOTAL(?:\s+(?:DUE|[ÀA]\s+PAYER|TTC))?|AMOUNT\s+DUE)\b"#)
        ]
        for (kind, pattern) in labels {
            guard let prefix = first(pattern, value) else { continue }
            let rest = String(value.dropFirst(prefix.count))
            // A label may contain a currency, numeric evidence or separators, but
            // additional words establish a different role (e.g. TOTAL CEREAL).
            // Words before the amount distinguish a product. Stray text after an
            // amount leaves a summary unresolved; it must not turn into a purchase.
            let amountRange = monetaryTokens(rest).first.flatMap { Range($0.range, in: rest) }
            let beforeAmount = amountRange.map { String(rest[..<$0.lowerBound]) } ?? rest
            let withoutCurrency = beforeAmount.replacingOccurrences(of: #"\b(?:CAD|USD|HKD|EUR|GBP|CNY|JPY)\b"#, with: "", options: .regularExpression)
            guard first(#"\p{L}"#, withoutCurrency) == nil else { return nil }
            return (kind, rest)
        }
        return nil
    }

    static func summaryAmountSyntaxIsClear(_ text: String) -> Bool {
        guard let label = summaryLabel(text) else { return false }
        var rest = label.remainder.replacingOccurrences(of: moneyPattern, with: "", options: .regularExpression)
        rest = rest.replacingOccurrences(of: #"\b(?:CAD|USD|HKD|EUR|GBP|CNY|JPY)\b\$?"#, with: "", options: .regularExpression)
        // Bars, parentheses, separated signs and stray digits are not decoration:
        // they could change an amount. Keep them unresolved rather than guessing.
        return first(#"^[\s:*=]*$"#, rest) != nil
    }

    static func merchant(_ text: String) -> String? {
        ReceiptMerchantDirectory.match(text)?.displayName
    }
    static func dateCandidates(_ text: String, noFrills: Bool = false) -> [(ReceiptDate, Bool)] {
        let pattern = #"\b(?:20\d{2}[-/]\d{2}[-/]\d{2}|\d{1,2}/\d{1,2}/(?:20)?\d{2}|\d{1,2}-[A-Za-z]{3}-20\d{2})\b"#
        return matches(pattern, text).flatMap { match -> [(ReceiptDate, Bool)] in
            guard let range = Range(match.range, in: text) else { return [] }
            let token = String(text[range])
            if token.hasPrefix("20"), token.count == 10 {
                return ExactInput.date(token.replacingOccurrences(of: "/", with: "-")).map { [($0, false)] } ?? []
            }
            if token.contains("/") {
                let parts = token.split(separator: "/").compactMap { Int($0) }
                guard parts.count == 3 else { return [] }
                let year = parts[2] < 100 ? 2000 + parts[2] : parts[2]
                let dayFirst = parts[0] > 12 && parts[1] <= 12
                let ordinary = try? ReceiptDate(year: year, month: dayFirst ? parts[1] : parts[0],
                                                day: dayFirst ? parts[0] : parts[1])
                if noFrills && token.split(separator: "/").last?.count == 2 {
                    let yearFirst = try? ReceiptDate(year: 2000 + parts[0], month: parts[1], day: parts[2])
                    // Audited No Frills transaction timestamps use YY/MM/DD with a printed clock.
                    // A bare short date does not establish that format; competing valid readings stay unknown.
                    if let yearFirst, first(#"\b\d{1,2}:\d{2}(?::\d{2})?\b|YY/MM/DD"#, text) != nil { return [(yearFirst, true)] }
                    if let yearFirst, let ordinary, yearFirst != ordinary { return [(yearFirst, true), (ordinary, true)] }
                    return (ordinary ?? yearFirst).map { [($0, true)] } ?? []
                }
                return ordinary.map { [($0, true)] } ?? []
            }
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "d-MMM-yyyy"; formatter.isLenient = false
            guard let date = formatter.date(from: token) else { return [] }
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            return (try? ReceiptDate(year: c.year!, month: c.month!, day: c.day!)).map { [($0, false)] } ?? []
        }
    }

    /// Join only an explicit SKU description with its immediately following,
    /// indented priced continuation. Unanchored wrapping remains reviewable.
    static func purchaseContinuationRows(_ input: [Row]) -> [Row] {
        var result: [Row] = []
        var index = 0
        while index < input.count {
            let head = input[index]
            guard index + 1 < input.count,
                  printedSKU(fieldText(head.text)) != nil,
                  matches(moneyPattern, head.text).isEmpty,
                  first(quantityPattern, head.text) == nil else {
                result.append(head); index += 1; continue
            }
            let tail = input[index + 1]
            let text = fieldText(tail.text)
            let distance = head.center - tail.center
            let height = min(head.height, tail.height)
            guard distance > height * 0.45, distance <= height * 1.75,
                  monetaryTokens(tail.text).count == 1,
                  first(#"^\p{L}"#, text) != nil,
                  printedSKU(text) == nil, summaryLabel(text) == nil,
                  first(metadataPattern, text) == nil,
                  first(#"^(?:HST|GST|PST|QST|TPS|TVQ|TAX|TAXES|DISCOUNT|COUPON|DEPOSIT|ADJUSTMENT)\b"#, text) == nil,
                  merchant(text) == nil, dateCandidates(text).isEmpty,
                  first(quantityPattern, text) == nil,
                  let left = head.parts.compactMap(\.boundingBox).map(\.x).min(),
                  let continuationLeft = tail.parts.compactMap(\.boundingBox).map(\.x).min(),
                  continuationLeft >= left + height * 0.5,
                  continuationLeft <= left + height * 4 else {
                result.append(head); index += 1; continue
            }
            var joined = head
            joined.text += " " + tail.text
            joined.ids += tail.ids
            joined.parts += tail.parts
            result.append(joined); index += 2
        }
        return result
    }

    /// Interpret an unpriced description and a separate single printed amount only when geometry
    /// gives a unique local pair. Existing priced rows and original grouping remain untouched.
    static func interpretationRows(_ input: [Row], knownRetailer: Bool) -> [Row] {
        guard input.allSatisfy({ $0.height > 0 }) else { return input }
        let input = knownRetailer ? purchaseContinuationRows(input) : input
        func isPrice(_ r: Row) -> Bool {
            guard matches(moneyPattern, r.text).count == 1, let token = first(moneyPattern, r.text) else { return false }
            let rest = r.text.replacingOccurrences(of: token, with: "").trimmingCharacters(in: .whitespaces)
            return rest.isEmpty || first(#"^[AEHN]$"#, rest) != nil
        }
        func isSummaryPrice(_ r: Row) -> Bool {
            guard monetaryTokens(r.text).count == 1, let token = first(moneyPattern, r.text) else { return false }
            let rest = r.text.replacingOccurrences(of: token, with: "").trimmingCharacters(in: .whitespaces)
            return rest.isEmpty || first(#"^(?:CAD|USD|HKD|EUR|GBP|CNY|JPY)\s*\$?$"#, rest.uppercased()) != nil
        }
        func isDescription(_ r: Row) -> Bool {
            let t = fieldText(r.text)
            if let label = summaryLabel(r.text) {
                return matches(moneyPattern, r.text).isEmpty && first(#"\d|[|()+-]"#, label.remainder) == nil
            }
            return matches(moneyPattern, r.text).isEmpty && first(#"\p{L}"#, t) != nil
                && first(quantityPattern, t) == nil && first(metadataPattern, t) == nil
                // Long explicit product-code prefixes are evidence; short numbers
                // and unlabelled quantity-like prefixes remain unresolved.
                && (first(#"^\d"#, t) == nil || printedSKU(t) != nil)
                && merchant(r.text) == nil && dateCandidates(r.text).isEmpty
                && first(#"\bCAD\b|CA\$|^\d+\s+(?:ST|AVE|ROAD|RD)\b"#, t) == nil
        }
        let prices = input.indices.filter { isPrice(input[$0]) || isSummaryPrice(input[$0]) }
        let descriptions = input.indices.filter { isDescription(input[$0]) }
        func distance(_ d: Int, _ p: Int) -> Double? {
            let a = input[d], b = input[p]
            let summary = summaryLabel(a.text) != nil
            guard summary ? isSummaryPrice(b) : isPrice(b) else { return nil }
            guard let right = a.parts.compactMap(\.boundingBox).map({ $0.x + $0.width }).max(),
                  let left = b.parts.compactMap(\.boundingBox).map(\.x).min(), left > right,
                  abs(a.center - b.center) <= min(a.height, b.height) * (summary ? 1.75 : 1) else { return nil }
            if input.indices.contains(where: { $0 != d && $0 != p && input[$0].center > min(a.center, b.center)
                && input[$0].center < max(a.center, b.center) }) { return nil }
            return abs(a.center - b.center) / min(a.height, b.height)
        }
        func nearest(_ target: Int, _ choices: [Int], reversed: Bool) -> Int? {
            let candidates = choices.compactMap { i -> (Int, Double)? in
                (reversed ? distance(target, i) : distance(i, target)).map { (i, $0) }
            }.sorted { $0.1 < $1.1 }
            guard let best = candidates.first, candidates.count == 1 || candidates[1].1 - best.1 > 0.25 else { return nil }
            return best.0
        }
        var merged: [Int: Row] = [:], consumed = Set<Int>()
        for p in prices {
            guard let d = nearest(p, descriptions, reversed: false), nearest(d, prices, reversed: true) == p else { continue }
            // Unknown-store product labels still compete for nearby prices, but
            // only explicit summary labels may be merged without a retailer profile.
            guard knownRetailer || summaryLabel(input[d].text) != nil else { continue }
            var row = input[d]; row.text += " " + input[p].text; row.ids += input[p].ids; row.parts += input[p].parts
            merged[d] = row; consumed.insert(p)
        }
        return input.indices.compactMap { consumed.contains($0) ? nil : (merged[$0] ?? input[$0]) }
    }

    static func extensionMatches(_ quantity: ReceiptDecimal, rate: Int64, amount: Int64) -> Bool {
        guard rate >= 0, amount >= 0 else { return false }
        let (product, overflow) = rate.multipliedReportingOverflow(by: quantity.coefficient)
        let divisor = (0..<quantity.scale).reduce(Int64(1)) { value, _ in value * 10 }
        guard !overflow else { return false }
        // Check the printed extension using exact rational half-up cent rounding; never fill a missing price.
        let rounded = product / divisor + (2 * (product % divisor) >= divisor ? 1 : 0)
        return rounded == amount
    }
    static func linkedQuantity(_ rateRow: Row, purchase: Row, amount: Int64) -> ReceiptDecimal? {
        guard rateRow.height > 0, purchase.height > 0, rateRow.center > purchase.center,
              rateRow.center - purchase.center <= 2 * min(rateRow.height, purchase.height),
              let q = first(quantityPattern, rateRow.text).flatMap({ first(#"\d+(?:\.\d+)?"#, $0) }).flatMap(ExactInput.decimal),
              monetaryTokens(rateRow.text).count == 1,
              let rate = firstPrintedMoney(rateRow.text),
              extensionMatches(q, rate: rate, amount: amount) else { return nil }
        return q
    }

    /// A following weight/rate row must contain its own printed extension.
    /// Relative geometry and explicit units establish the group; totals never supply a price.
    private static func recoverWeightedExtensions(_ parsed: inout ParsedReceipt, rows: [Row]) {
        guard let merchant = parsed.merchant, ReceiptMerchantDirectory.match(merchant) != nil,
              rows.count > 1 else { return }
        let order = Dictionary(rows.enumerated().flatMap { index, row in row.ids.map { ($0, index) } }, uniquingKeysWith: min)
        for index in 0..<(rows.count - 1) {
            let head = rows[index], tail = rows[index + 1]
            let description = head.text.trimmingCharacters(in: .whitespacesAndNewlines)
            // Do not recover purchases from a payment/total footer.
            guard !rows[..<index].contains(where: {
                (summaryLabel($0.text)?.kind == .total && !monetaryTokens($0.text).isEmpty)
                    || first(#"^(?:CASH|VISA|MASTERCARD|DEBIT|CREDIT|CHANGE|TENDER)\b"#, fieldText($0.text)) != nil
            }) else { continue }
            let syntax = #"^\d+(?:\.\d+)?\s*(?:KG|LB|LBS)\s*@\s*\$?\d+\.\d{2}\s*/\s*(?:KG|LB|LBS)\s+(?:[A-Z]\s+)?\$?\d+\.\d{2}\s*$"#
            guard first(syntax, tail.text.uppercased()) != nil,
                  monetaryTokens(description).isEmpty, first(quantityPattern, description) == nil,
                  first(#"\p{L}"#, description) != nil, summaryLabel(description) == nil,
                  first(metadataPattern, fieldText(description)) == nil,
                  first(#"^(?:HST|GST|PST|TAX|DISCOUNT|COUPON|DEPOSIT|ADJUSTMENT)\b"#, fieldText(description)) == nil,
                  ReceiptParser.merchant(description) == nil, dateCandidates(description).isEmpty,
                  first(#"^(?:PRODUCE|MEAT|MEATS|DAIRY|SEAFOOD|BAKERY|GROCERY|GROCERIES)(?:\s+DEPARTMENT)?$"#, fieldText(description)) == nil,
                  head.height > 0, tail.height > 0, head.center > tail.center,
                  head.center - tail.center <= min(head.height, tail.height) * 1.5,
                  let hx = head.parts.compactMap(\.boundingBox).map(\.x).min(),
                  let tx = tail.parts.compactMap(\.boundingBox).map(\.x).min(), tx > hx,
                  let qText = first(#"^\d+(?:\.\d+)?"#, tail.text), let q = ExactInput.decimal(qText),
                  let unit = printedUnit(tail.text),
                  let rateUnit = first(#"/\s*(?:KG|LBS|LB)\b"#, tail.text.uppercased()),
                  rateUnit.replacingOccurrences(of: "/", with: "").trimmingCharacters(in: .whitespaces) == unit else { continue }
            let tokens = monetaryTokens(tail.text)
            guard tokens.count == 2, let rr = Range(tokens[0].range, in: tail.text),
                  let ar = Range(tokens[1].range, in: tail.text),
                  let rate = printedMoney(String(tail.text[rr])), let amount = printedMoney(String(tail.text[ar])),
                  extensionMatches(q, rate: rate, amount: amount) else { continue }
            let ids = head.ids + tail.ids
            guard !parsed.lines.contains(where: { !Set($0.sourceLineIDs).isDisjoint(with: ids) }) else { continue }
            var line = ParsedReceipt.Line(kind: "purchase", description: description, amount: amount, quantity: q, sourceLineIDs: ids)
            line.sku = printedSKU(description); line.unit = unit; line.unitPrice = rate
            let position = parsed.lines.firstIndex { existing in
                existing.sourceLineIDs.compactMap { order[$0] }.min().map { $0 > index } ?? false
            } ?? parsed.lines.endIndex
            parsed.lines.insert(line, at: position)
            let resolved = Set(ids)
            parsed.issues.removeAll { issue in
                ["unpriced_source_row", "quantity_association_uncertain"].contains(issue.code)
                    && !issue.sourceLineIDs.isEmpty && Set(issue.sourceLineIDs).isSubset(of: resolved)
            }
        }
    }

    /// Recover only the verified split count/rate/extension layout. Original OCR is immutable.
    private static func recoverExplicitCountExtensions(_ parsed: inout ParsedReceipt, rows: [Row]) {
        guard let merchant = parsed.merchant, ReceiptMerchantDirectory.match(merchant) != nil else { return }
        guard rows.count > 1 else { return }
        let order = Dictionary(rows.enumerated().flatMap { index, row in row.ids.map { ($0, index) } }, uniquingKeysWith: min)
        for index in 0..<(rows.count - 1) {
            let head = rows[index], tail = rows[index + 1]
            // Explicit repeated count and long SKU, followed immediately by a complete printed extension.
            // A multi-observation head can contain an unrelated row absorbed by grouping.
            guard head.parts.count == 1, let countPrefix = ReceiptParser.first(#"^\(\d+\)\s*"#, head.text),
                 let countText = ReceiptParser.first(#"\d+"#, countPrefix),
                 let quantity = ExactInput.decimal(countText),
                 ReceiptParser.monetaryTokens(head.text).isEmpty,
                 ReceiptParser.printedSKU(String(head.text.dropFirst(countPrefix.count))) != nil,
                 ReceiptParser.first(#"^\d+\s*@\s*\$?\d+\.\d{2}\s+\$?\d+\.\d{2}\s*$"#, tail.text) == tail.text,
                 ReceiptParser.first(#"^\d+"#, tail.text) == countText,
                 head.height > 0, tail.height > 0,
                 head.center > tail.center,
                 head.center - tail.center <= min(head.height, tail.height) * 1.5,
                 let hx = head.parts.compactMap(\.boundingBox).map(\.x).min(),
                 let tx = tail.parts.compactMap(\.boundingBox).map(\.x).min(), tx > hx else { continue }
            let tokens = ReceiptParser.monetaryTokens(tail.text)
            guard tokens.count == 2,
                 let rr = Range(tokens[0].range, in: tail.text), let ar = Range(tokens[1].range, in: tail.text),
                 let rate = ReceiptParser.printedMoney(String(tail.text[rr])),
                 let amount = ReceiptParser.printedMoney(String(tail.text[ar])),
                 ReceiptParser.extensionMatches(quantity, rate: rate, amount: amount) else { continue }
            let ids = head.ids + tail.ids
            guard !parsed.lines.contains(where: { !Set($0.sourceLineIDs).isDisjoint(with: ids) }) else { continue }
            // The repeated count is a separate quantity field; retain all product text and trailing codes.
            // Original text remains in the linked OCR evidence.
            var line = ParsedReceipt.Line(kind: "purchase", description: String(head.text.dropFirst(countPrefix.count)), amount: amount,
                                         quantity: quantity, sourceLineIDs: ids)
            line.sku = ReceiptParser.printedSKU(String(head.text.dropFirst(countPrefix.count)))
            line.unitPrice = rate
            // Insert at the source position without reordering any existing purchases.
            let position = parsed.lines.firstIndex { existing in
                existing.sourceLineIDs.compactMap { order[$0] }.min().map { $0 > index } ?? false
            } ?? parsed.lines.endIndex
            parsed.lines.insert(line, at: position)
            let resolved = Set(ids)
            parsed.issues.removeAll { issue in
                ["unpriced_source_row", "quantity_association_uncertain"].contains(issue.code)
                    && !issue.sourceLineIDs.isEmpty && Set(issue.sourceLineIDs).isSubset(of: resolved)
            }
        }
    }

    static func parse(_ observations: [ReceiptOCRLine]) -> ParsedReceipt {
        var result = ParsedReceipt()
        let grouped = rows(observations)
        // Only the early, unpriced header can select a retailer. Never search a
        // payment footer or let a conflicting header select a parsing policy.
        let header = grouped.prefix(12).prefix {
            matches(moneyPattern, $0.text).isEmpty && summaryLabel($0.text) == nil
                && first(#"^(?:DEBIT|CREDIT|PAYMENT|THANK\s+YOU)\b"#, fieldText($0.text)) == nil
        }
        let merchantEvidence = header.compactMap { row in
            ReceiptMerchantDirectory.match(row.text).map { (match: $0, ids: row.ids) }
        }
        let identities = Set(merchantEvidence.map { $0.match.identity })
        let merchantMatch = identities.count == 1 ? merchantEvidence.first?.match : nil
        result.merchant = merchantMatch?.displayName
        if identities.count > 1 {
            result.issues.append(.init(code: "merchant_conflicting",
                sourceLineIDs: merchantEvidence.flatMap(\.ids), detail: nil))
        }
        var finished = false, pendingQuantity: Row?
        var totals: [(Int64, [UUID])] = [], subtotals: [(Int64, [UUID])] = []
        var totalAmbiguous = false, subtotalAmbiguous = false
        var dates: [(ReceiptDate, [UUID])] = []
        var currencies: [(ReceiptCurrency, [UUID])] = []
        func issue(_ code: String, _ ids: [UUID]) { result.issues.append(.init(code: code, sourceLineIDs: ids, detail: nil)) }
        if observations.contains(where: { $0.boundingBox == nil }) {
            issue("geometry_incomplete", observations.filter { $0.boundingBox == nil }.map(\.id))
        }
        for row in interpretationRows(grouped, knownRetailer: merchantMatch != nil) {
            let text = row.text.trimmingCharacters(in: .whitespacesAndNewlines), upper = fieldText(text)
            // Pending quantity belongs only to the next purchase; every intervening boundary clears it.
            let previousQuantity = pendingQuantity; pendingQuantity = nil
            var quantityLinked = false
            defer { if let previousQuantity, !quantityLinked { issue("quantity_association_uncertain", previousQuantity.ids) } }
            // Codes in an unpriced header/footer or explicit summary/currency row are
            // evidence. A priced product named CAD/USD must not select the currency.
            let currencyContext = matches(moneyPattern, text).isEmpty
                || summaryLabel(text) != nil || first(#"^CURRENCY\b"#, upper) != nil
                || first(#"^(?:CAD|USD|HKD|EUR|GBP|CNY|JPY)\s*\$?\s*[^\p{L}]*$"#, upper) != nil
            // A currency/amount observation can share a grouped row with a payment
            // label. Inspect that self-contained observation without borrowing meaning
            // from the neighbouring text or treating a product name as currency.
            for part in row.parts {
                let value = fieldText(part.text)
                if first(#"^(?:CAD|USD|HKD|EUR|GBP|CNY|JPY)\s*\$?\s*[^\p{L}]*$"#, value) != nil,
                   let code = first(#"^[A-Z]{3}"#, value), let currency = ExactInput.currency(code) {
                    currencies.append((currency, [part.id]))
                }
            }
            if currencyContext {
                for code in ExactInput.currencies.keys.sorted() {
                    if first("\\b" + code + "\\b", upper) != nil, let currency = ExactInput.currency(code) {
                        currencies.append((currency, row.ids))
                    }
                }
                for (symbol, code) in [(#"CA\$"#, "CAD"), (#"US\$"#, "USD"), (#"HK\$"#, "HKD")] {
                    if first(symbol, upper) != nil, let currency = ExactInput.currency(code) { currencies.append((currency, row.ids)) }
                }
            }
            let candidates = dateCandidates(text, noFrills: merchantMatch?.identity == .noFrills)
            for (date, orderCheck) in candidates {
                dates.append((date, row.ids)); if orderCheck { issue("date_order_check", row.ids) }
            }
            if (merchant(text) != nil && matches(moneyPattern, text).isEmpty) || !candidates.isEmpty { continue }
            let tokens = monetaryTokens(text)
            let summaryField = summaryLabel(text)
            let summary = summaryField != nil
            let tax = first(#"^(?:HST|GST|PST|QST|TPS|TVQ|TAX|TAXES)\b"#, upper) != nil
            let adjustment = first(#"^(?:DISCOUNT|COUPON|DEPOSIT|ADJUSTMENT)\b"#, upper) != nil
            // A complete final-total label establishes the footer boundary even
            // when its amount needs review. Subtotals can precede another department.
            if summaryField?.kind == .total && !tokens.isEmpty { finished = true }
            if first(metadataPattern, upper) != nil {
                // Payment is a terminal boundary even if the total itself is unreadable.
                if !tokens.isEmpty, first(#"^(?:CASH|VISA|MASTERCARD|DEBIT|CREDIT|CHANGE|TENDER)(?:\s+(?:CARD|PAID|TENDERED))?\s*[:$\d., -]+$"#, upper) != nil { finished = true }
                continue
            }
            if finished && !summary && !tax && !adjustment { continue }
            guard let last = tokens.last, let range = Range(last.range, in: text),
                  let amount = printedMoney(String(text[range])) else {
                if first(#"\d+[.,]\d+"#, text) != nil { issue("amount_unparsed_check_source", row.ids) }
                if first(#"^\d+(?:\.\d+)?\s*(?:(?:KG|LB|LBS|X)\b|@)"#, upper) != nil && !finished { pendingQuantity = row }
                else if !finished && !summary && first(#"\p{L}"#, text) != nil { issue("unpriced_source_row", row.ids) }
                continue
            }
            let prefix = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            if summary {
                // The new decimal-comma path does not promote signed summaries until
                // their refund/return context is established. Preserve established dot
                // decimal behavior and never remove a printed or OCR trailing sign.
                let decimalComma = String(text[range]).contains(",") && !String(text[range]).contains(".")
                guard !decimalComma || amount >= 0 else {
                    issue("negative_summary_check_source", row.ids)
                    if summaryField?.kind == .subtotal { subtotalAmbiguous = true }
                    else { totalAmbiguous = true }
                    continue
                }
                guard tokens.count == 1 else {
                    issue("summary_amount_ambiguous", row.ids)
                    if summaryField?.kind == .subtotal { subtotalAmbiguous = true }
                    else { totalAmbiguous = true }
                    continue
                }
                guard summaryAmountSyntaxIsClear(text) else {
                    issue("summary_amount_ambiguous", row.ids)
                    if summaryField?.kind == .subtotal { subtotalAmbiguous = true }
                    else { totalAmbiguous = true }
                    continue
                }
                if summaryField?.kind == .subtotal { subtotals.append((amount, row.ids)) }
                else {
                    totals.append((amount, row.ids))
                    finished = true
                }
                continue
            }
            // A standalone rate never supplies a purchase or a calculated extension.
            if first(#"^\d+(?:\.\d+)?\s*(?:(?:KG|LB|LBS|X)\b|@)"#, upper) != nil { pendingQuantity = row; continue }
            // Numeric-only promotion codes stay unresolved until their printed meaning is
            // verified; a matching product code alone does not establish an adjustment.
            guard !prefix.isEmpty, first(#"\p{L}"#, prefix) != nil else {
                issue("unpaired_amount", row.ids); continue
            }
            let inlineQuantity = first(quantityPattern, prefix)
            let inlineRate = inlineQuantity.map { first(#"(?:\bX\b|@)"#, $0) != nil } ?? false
            var unitPrice: Int64?
            if tokens.count > 1 {
                guard tokens.count == 2, let qText = inlineQuantity,
                      let q = first(#"\d+(?:\.\d+)?"#, qText).flatMap(ExactInput.decimal),
                      let qRange = prefix.range(of: qText), let rateRange = Range(tokens[0].range, in: text),
                      qRange.upperBound <= rateRange.lowerBound,
                      let rate = printedMoney(String(text[rateRange])), extensionMatches(q, rate: rate, amount: amount) else {
                    issue("item_amount_ambiguous", row.ids); continue
                }
                unitPrice = rate
            } else if inlineRate { issue("extension_missing", row.ids); continue }
            let suffix = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !suffix.isEmpty && first(#"^[AEHN]$"#, suffix) == nil { issue("item_amount_ambiguous", row.ids); continue }
            var quantity = inlineQuantity.flatMap { first(#"\d+(?:\.\d+)?"#, $0) }.flatMap(ExactInput.decimal)
            var unit = printedUnit(prefix)
            var qIDs: [UUID] = []
            if let previousQuantity, inlineQuantity == nil, !tax, !adjustment, amount >= 0 {
                if let q = linkedQuantity(previousQuantity, purchase: row, amount: amount) {
                    quantity = q; qIDs = previousQuantity.ids; quantityLinked = true
                    unitPrice = firstPrintedMoney(previousQuantity.text)
                    unit = printedUnit(previousQuantity.text)
                    issue("quantity_association_check", previousQuantity.ids + row.ids)
                }
            }
            var kind = tax ? "tax" : (amount < 0 ? "discount" : "purchase")
            if adjustment { kind = upper.hasPrefix("DEPOSIT") ? "deposit" : (amount < 0 ? "discount" : "other") }
            if adjustment && amount >= 0 && !upper.hasPrefix("DEPOSIT") { issue("adjustment_sign_check", row.ids) }
            var line = ParsedReceipt.Line(kind: kind, description: prefix, amount: amount, quantity: quantity, sourceLineIDs: qIDs + row.ids)
            if kind == "purchase" {
                line.sku = printedSKU(prefix); line.unitPrice = unitPrice; line.unit = unit
                line.taxMarker = suffix.isEmpty ? nil : suffix.uppercased()
            }
            if kind == "tax" { line.rate = printedTaxRate(prefix) }
            result.lines.append(line)
        }
        if let pendingQuantity { issue("quantity_association_uncertain", pendingQuantity.ids) }
        func resolved(_ values: [(Int64, [UUID])], code: String) -> Int64? {
            guard let value = values.first?.0 else { return nil }
            guard values.allSatisfy({ $0.0 == value }) else { issue(code, Array(Set(values.flatMap { $0.1 })).sorted { $0.uuidString < $1.uuidString }); return nil }
            return value
        }
        if let currency = currencies.first?.0 {
            if currencies.allSatisfy({ $0.0 == currency }) { result.currency = currency }
            else { issue("currency_conflicting", Array(Set(currencies.flatMap { $0.1 })).sorted { $0.uuidString < $1.uuidString }) }
        }
        result.subtotal = subtotalAmbiguous ? nil : resolved(subtotals, code: "subtotal_conflicting")
        result.total = totalAmbiguous ? nil : resolved(totals, code: "total_conflicting")
        if let date = dates.first?.0 {
            if dates.allSatisfy({ $0.0 == date }) { result.date = date } else { issue("date_conflicting", Array(Set(dates.flatMap { $0.1 })).sorted { $0.uuidString < $1.uuidString }) }
        }
        recoverExplicitCountExtensions(&result, rows: grouped)
        recoverWeightedExtensions(&result, rows: grouped)
        for (missing, code) in [(result.merchant == nil, "merchant_missing"), (result.date == nil, "date_missing"), (result.currency == nil, "currency_missing"), (result.total == nil, "total_missing")] where missing { issue(code, []) }
        issue("source_review_required", observations.map(\.id))
        return result
    }
    static func extraction(_ result: OCRResult) throws -> ReceiptExtraction {
        let parsed = parse(result.lines)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return ReceiptExtraction(capturedAt: Date(), recognizer: "Apple Vision accurate", recognizerVersion: String(result.revision),
            parser: "Deterministic retailer Swift parser", parserVersion: version, rawOCR: result.lines,
            rawParserOutput: try encoder.encode(parsed), fields: parsed.fields(), issues: parsed.issues, readingEvidence: result.readingEvidence)
    }
}
