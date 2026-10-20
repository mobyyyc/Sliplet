import Foundation
#if !P703_CLI
@testable import Sliplet
#endif

/// Evaluation only. Never called by the shipped app.
enum ReceiptItemBoundaryCandidate {
 static func candidate(_ observations: [ReceiptOCRLine]) -> ParsedReceipt {
  var parsed = ReceiptParser.parse(observations)
  guard let merchant = parsed.merchant, ReceiptMerchantDirectory.match(merchant) != nil else { return parsed }
  let rows = ReceiptParser.rows(observations)
  guard rows.count > 1 else { return parsed }
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
   // No reference labels or expected amounts enter this worker.
   var line = ParsedReceipt.Line(kind: "purchase", description: String(head.text.dropFirst(countPrefix.count)), amount: amount,
                                 quantity: quantity, sourceLineIDs: ids)
   line.sku = ReceiptParser.printedSKU(String(head.text.dropFirst(countPrefix.count)))
   line.unitPrice = rate
   parsed.lines.append(line)
  }
  return parsed
 }
}
