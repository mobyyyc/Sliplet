import Foundation
struct OCRResult { let lines: [ReceiptOCRLine]; let revision: Int; let readingEvidence: ReceiptReadingEvidence? }
struct Response: Encodable { let observations: [ReceiptOCRLine]; let parsed: ParsedReceipt; let draftFields: ReceiptFields }
@main struct Worker {
 static func main() {
  do {
   let lines = try JSONDecoder().decode([ReceiptOCRLine].self, from: FileHandle.standardInput.readDataToEndOfFile())
   let parsed = ReceiptItemBoundaryCandidate.candidate(lines)
   var conversion = parsed
   if conversion.currency == nil { conversion.currency = .cad }
   let data = try JSONEncoder().encode(Response(observations: lines, parsed: parsed, draftFields: conversion.fields()))
   FileHandle.standardOutput.write(data)
  } catch { FileHandle.standardError.write(Data("Item proof failed; private content suppressed\n".utf8)); exit(1) }
 }
}
