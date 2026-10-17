import Foundation

/// Deliberately small, local directory. Aliases match complete header lines;
/// adding a retailer requires positive and misleading-mention regression cases.
/// Identity controls parser policy; display names may preserve fictional demos.
enum ReceiptMerchantDirectory {
    enum Identity: String, Hashable { case noFrills, costco, tnt }
    struct Entry {
        let identity: Identity
        let name: String
        let aliases: [String]
    }
    struct Match {
        let identity: Identity
        let displayName: String
    }
    static let entries: [Entry] = [
        .init(identity: .noFrills, name: "NOFRILLS", aliases: [
            #"(?:[\p{L}]+(?:[ -][\p{L}]+)*['’]S\s+|[\p{L}]+\s+[\p{L}]+\s*)?NO\s*FRILLS"#
        ]),
        .init(identity: .costco, name: "COSTCO", aliases: [#"COSTCO(?:\s+WHOLESALE)?"#]),
        .init(identity: .tnt, name: "T&T SUPERMARKET", aliases: [#"T\s*&\s*T(?:\s+SUPERMARKET)?"#])
    ]
    private static func editDistance(_ a: String, _ b: String) -> Int {
        var previous = Array(0...b.count)
        for (i, x) in a.enumerated() {
            var next = [i + 1]
            for (j, y) in b.enumerated() {
                next.append(min(next[j] + 1, previous[j + 1] + 1, previous[j] + (x == y ? 0 : 1)))
            }
            previous = next
        }
        return previous.last ?? 0
    }
    static func match(_ text: String) -> Match? {
        var normalized = text.precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A clear T&T identity can have a noisy printed descriptor. Correct only
        // that descriptor, within two edits; never fuzzy-match the store name.
        if let tail = ReceiptParser.first(#"(?<=T&T)[A-Z]+$"#,
            normalized.uppercased().replacingOccurrences(of: " ", with: "")),
           editDistance(tail, "SUPERMARKET") <= 2,
           ReceiptParser.first(#"^T\s*&\s*T\s*[A-Z]+$"#, normalized) != nil {
            normalized = "T&T SUPERMARKET"
        }
        // Context words describe a mention rather than a merchant identity. Bare
        // operator names are allowed only before the complete No Frills brand.
        guard ReceiptParser.first(#"\b(?:COMPARE|WITH|THAN|SHOP|AT|VISIT|FROM|SAVE|SAVINGS|BAG|PRODUCT|THANK|RETURN|NOT|LIKE|NEAR|OPPOSITE|TO)\b"#, normalized) == nil else { return nil }
        let distinctBrands = [#"\bNO\s*FRILLS\b"#, #"\bCOSTCO\b"#, #"\bT\s*&\s*T\b"#]
            .filter { ReceiptParser.first($0, normalized) != nil }
        guard distinctBrands.count <= 1 else { return nil }
        let fictional = ReceiptParser.first(#"^(?:DEMO(?:\s+\d+)?|SYNTHETIC|FICTIONAL)\b"#, normalized) != nil
        let prefix = #"(?:DEMO(?:\s+\d+)?[\s·:—-]+|SYNTHETIC\s+|FICTIONAL\s+)?"#
        let suffix = #"(?:\s+(?:CAD|USD|HKD|EUR|GBP|CNY|JPY))?[\s®™*]*$"#
        let candidates = entries.filter { entry in
            entry.aliases.contains { alias in
                ReceiptParser.first("^[^\\p{L}\\p{N}]*" + prefix + "(?:" + alias + ")" + suffix, normalized) != nil
            }
        }
        guard candidates.count == 1, let entry = candidates.first else { return nil }
        return Match(identity: entry.identity, displayName: fictional ? text : entry.name)
    }
}
