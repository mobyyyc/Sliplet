import Foundation

/// Identity is a saved purchase row, not a description or a model-generated SKU.
struct PurchaseEndpoint: Codable, Equatable, Hashable, Sendable {
    let receiptID: UUID
    let lineID: UUID
}

struct PurchaseEvidence: Codable, Equatable, Sendable {
    let endpoint: PurchaseEndpoint
    let revisionID: UUID
    let assetHash: Data

    init(record: ReceiptRecord, lineID: UUID) {
        endpoint = PurchaseEndpoint(receiptID: record.id, lineID: lineID)
        revisionID = record.current.id
        assetHash = record.asset.sha256
    }

    func matches(_ record: ReceiptRecord) -> Bool {
        record.id == endpoint.receiptID && record.current.id == revisionID &&
            record.asset.sha256 == assetHash && record.current.fields.items.contains { $0.id == endpoint.lineID }
    }
}

struct PurchaseLinkDecision: Codable, Equatable, Sendable, Identifiable {
    enum Verdict: String, Codable, Sendable { case sameProduct, differentProduct }
    enum Pack: String, Codable, Sendable { case same, different, unknown }
    let id: UUID
    let first: PurchaseEvidence
    let second: PurchaseEvidence
    let verdict: Verdict
    let pack: Pack
    var priceEvidence: PurchasePriceEvidence? = nil

    func connects(_ a: PurchaseEndpoint, _ b: PurchaseEndpoint) -> Bool {
        Set([first.endpoint, second.endpoint]) == Set([a, b])
    }

}

/// Mirrored in both encrypted receipt payloads. A link resolves only when both agree.
struct PurchaseLinks: Codable, Equatable, Sendable {
    var version = 1
    var id = UUID()
    var decisions: [PurchaseLinkDecision] = []

    func validate(owner: ReceiptRecord) throws {
        guard version == 1, decisions.count <= 1_000,
              Set(decisions.map(\.id)).count == decisions.count else {
            throw ReceiptValidationError.invalidEvidence
        }
        var pairs = Set<Set<PurchaseEndpoint>>()
        for decision in decisions {
            let a = decision.first, b = decision.second
            if let price = decision.priceEvidence {
                guard decision.verdict == .sameProduct, decision.pack == .same,
                      price.firstUnit != .unknown, price.secondUnit != .unknown,
                      price.firstUnit.standard == price.secondUnit.standard, price.tax != .unknown else {
                    throw ReceiptValidationError.invalidEvidence
                }
            }
            guard a.endpoint.receiptID != b.endpoint.receiptID,
                  a.assetHash.count == 32, b.assetHash.count == 32,
                  a.assetHash != b.assetHash,
                  pairs.insert(Set([a.endpoint, b.endpoint])).inserted,
                  let local = [a, b].first(where: { $0.endpoint.receiptID == owner.id }),
                  owner.revisions.contains(where: {
                      $0.id == local.revisionID && $0.fields.items.contains { $0.id == local.endpoint.lineID }
                  }), local.assetHash == owner.asset.sha256 else {
                throw ReceiptValidationError.invalidEvidence
            }
        }
    }
}

enum PurchaseLinkEngine {
    enum Reason: Equatable { case sameStoreCode, sameStoreDescription }

    /// Discovery only. Even matching codes do not confirm package or product identity.
    static func candidate(_ first: ReceiptRecord, line firstID: UUID,
                          _ second: ReceiptRecord, line secondID: UUID) -> Reason? {
        guard decision(first, line: firstID, second, line: secondID) == nil,
              let (a, b) = purchases(first, line: firstID, second, line: secondID),
              let merchant = normalized(first.current.fields.merchant),
              merchant == normalized(second.current.fields.merchant) else { return nil }
        let firstCode = normalized(a.sku), secondCode = normalized(b.sku)
        if let firstCode, let secondCode {
            return firstCode == secondCode ? .sameStoreCode : nil
        }
        // A missing code is not evidence that two conflicting codes are equivalent.
        guard let name = normalized(a.description), name == normalized(b.description) else { return nil }
        return .sameStoreDescription
    }

    static func purchases(_ first: ReceiptRecord, line firstID: UUID,
                          _ second: ReceiptRecord, line secondID: UUID) -> (ReceiptLine, ReceiptLine)? {
        guard first.id != second.id, first.asset.sha256 != second.asset.sha256,
              let a = first.current.fields.items.first(where: { $0.id == firstID }),
              let b = second.current.fields.items.first(where: { $0.id == secondID }),
              let amountA = a.amount, let amountB = b.amount,
              amountA.minorUnits > 0, amountB.minorUnits > 0 else { return nil }
        return (a, b)
    }

    /// Direct confirmed pair only. Never infer transitive identity or comparable prices.
    static func decision(_ first: ReceiptRecord, line firstID: UUID,
                         _ second: ReceiptRecord, line secondID: UUID) -> PurchaseLinkDecision? {
        guard purchases(first, line: firstID, second, line: secondID) != nil else { return nil }
        let a = PurchaseEndpoint(receiptID: first.id, lineID: firstID)
        let b = PurchaseEndpoint(receiptID: second.id, lineID: secondID)
        guard let decision = first.purchaseLinks?.decisions.first(where: { $0.connects(a, b) }),
              second.purchaseLinks?.decisions.contains(decision) == true,
              [decision.first, decision.second].allSatisfy({ $0.matches(first) || $0.matches(second) }) else { return nil }
        return decision
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let folded = value.precomposedStringWithCompatibilityMapping.lowercased()
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return folded.isEmpty ? nil : folded
    }
}

struct PurchaseHistoryEntry: Identifiable {
    let record: ReceiptRecord
    let line: ReceiptLine
    var id: PurchaseEndpoint { PurchaseEndpoint(receiptID: record.id, lineID: line.id) }

    static func entries(for endpoint: PurchaseEndpoint, in records: [ReceiptRecord]) -> [Self] {
        guard let source = records.first(where: { $0.id == endpoint.receiptID }),
              source.current.fields.items.contains(where: { $0.id == endpoint.lineID }) else { return [] }
        return records.sorted(by: ReceiptHistory.newestFirst).filter { $0.id != source.id }.flatMap { record in
            record.current.fields.items.compactMap { line -> Self? in
                let decision = PurchaseLinkEngine.decision(source, line: endpoint.lineID, record, line: line.id)
                // Honor saved exclusions. An old approval must satisfy current matching rules after an edit.
                let peer = PurchaseEndpoint(receiptID: record.id, lineID: line.id)
                if [source, record].contains(where: { receipt in
                    receipt.purchaseLinks?.decisions.contains {
                        $0.verdict == .differentProduct && $0.connects(endpoint, peer)
                    } == true
                }) { return nil }
                guard decision?.verdict == .sameProduct ||
                    PurchaseLinkEngine.candidate(source, line: endpoint.lineID, record, line: line.id) != nil else { return nil }
                return Self(record: record, line: line)
            }
        }
    }
}
