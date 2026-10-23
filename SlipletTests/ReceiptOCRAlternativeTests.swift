import XCTest
import Vision
import ImageIO
import CoreImage
import CryptoKit
@testable import Sliplet

@MainActor final class ReceiptOCRAlternativeTests: XCTestCase {
    struct Input: Decodable { let nonce: String; let slots: [Slot] }
    struct Slot: Decodable { let slot: Int; let image: String; let sha256: String }
    struct Choice: Codable { let text: String; let confidence: Float }
    struct Observation: Codable { let id: UUID; let box: ReceiptOCRBox; let choices: [Choice] }
    struct Rejected: Encodable { let localBox: CGRect; let choices: [Choice] }
    struct Reading: Encodable { let rejected: [Rejected]; let region: ReceiptOCRBox; let observations: [Observation]; let milliseconds: Double; let revision: Int }
    struct Result: Encodable { let full: Reading; let regions: [Reading]; let parsed: ParsedReceipt }
    enum Failure: Error { case invalid }
    func read(_ image: CIImage, region: ReceiptOCRBox, original: ReceiptImage? = nil) throws -> Reading {
        let start = ProcessInfo.processInfo.systemUptime
        let e = image.extent
        let crop = CGRect(x:e.minX+region.x*e.width,y:e.minY+region.y*e.height,width:region.width*e.width,height:region.height*e.height).integral.intersection(e)
        let cg: CGImage
        let orientation: CGImagePropertyOrientation
        if let original {
            guard let source = CGImageSourceCreateWithData(original.bytes as CFData,nil),
                  let decoded = CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCache:false] as CFDictionary) else { throw Failure.invalid }
            cg = decoded; orientation = original.orientation
        } else {
            guard let rendered = CIContext(options:[.cacheIntermediates:false]).createCGImage(image.cropped(to:crop),from:crop) else { throw Failure.invalid }
            cg = rendered; orientation = .up
        }
        let actual = try ReceiptOCRBox(x:(crop.minX-e.minX)/e.width,y:(crop.minY-e.minY)/e.height,width:crop.width/e.width,height:crop.height/e.height)
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = false
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["en-US","fr-FR","zh-Hans","zh-Hant"].filter(supported.contains)
        let cancel = DispatchWorkItem { request.cancel() }
        DispatchQueue.global().asyncAfter(deadline:.now()+30,execute:cancel);defer { cancel.cancel() }
        try VNImageRequestHandler(cgImage:cg,orientation:orientation).perform([request])
        var rejected: [Rejected] = []
        let observations = (request.results ?? []).compactMap { o -> Observation? in
            let choices = o.topCandidates(5).map { Choice(text:$0.string,confidence:$0.confidence) }
            guard let mapped = try? ReceiptRegionReadingJob.originalBox(local:o.boundingBox,region:actual) else {
                rejected.append(Rejected(localBox:o.boundingBox,choices:choices));return nil
            }
            return Observation(id:UUID(),box:mapped,choices:choices)
        }
        return Reading(rejected:rejected,region:actual,observations:observations,milliseconds:(ProcessInfo.processInfo.systemUptime-start)*1000,revision:request.revision)
    }

    func lines(_ r: Reading) -> [ReceiptOCRLine] {
        r.observations.compactMap { o in o.choices.first.map { ReceiptOCRLine(id:o.id,text:$0.text,engineConfidence:$0.confidence,boundingBox:o.box) } }
    }
    func regions(_ lines: [ReceiptOCRLine]) throws -> [ReceiptOCRBox] {
        let parsed=ReceiptParser.parse(lines)
        let issueIDs=Set(parsed.issues.filter { ["unpriced_source_row","unpaired_amount","item_amount_ambiguous","amount_unparsed_check_source"].contains($0.code) }.flatMap(\.sourceLineIDs))
        let low=Set(lines.filter { ($0.engineConfidence ?? 1)<0.8 }.map(\.id))
        let rows=ReceiptParser.rows(lines)
        let selected=rows.enumerated().compactMap { index,row -> (Int,Int,ReceiptParser.Row)? in
            let priority=ReceiptParser.summaryLabel(row.text)?.kind == .total ? 0 : (!Set(row.ids).isDisjoint(with:issueIDs) ? 1 : (!Set(row.ids).isDisjoint(with:low) ? 2 : 3))
            return priority<3 ? (priority,index,row) : nil
        }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }.prefix(8)
        return try selected.map { _,_,row in
            let height=max(row.height*3,0.012), bottom=max(0,row.center-height/2), top=min(1,row.center+height/2)
            return try ReceiptOCRBox(x:0,y:bottom,width:1,height:top-bottom)
        }
    }
    func testFictionalRegionSelection() throws {
        let input = try [ReceiptOCRLine(id:UUID(),text:"TOTAL",engineConfidence:1,boundingBox:ReceiptOCRBox(x:0.1,y:0.4,width:0.2,height:0.02))]
        let selected=try regions(input);XCTAssertEqual(selected.count,1);XCTAssertEqual(selected[0].width,1);XCTAssertGreaterThan(selected[0].height,0.02)
        XCTAssertEqual(try regions([]).count,0)
    }
    func testPrivateAlternatives() throws {
        guard ProcessInfo.processInfo.environment["SLIPLET_P707_PRIVATE"] == "YES" else { throw XCTSkip("Explicit private experiment only") }
        do {
            guard let nonce=ProcessInfo.processInfo.environment["SLIPLET_P401_NONCE"],UUID(uuidString:nonce) != nil else { throw Failure.invalid }
            let root=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("P401Lab").appendingPathComponent(nonce)
            let input=try JSONDecoder().decode(Input.self,from:Data(contentsOf:root.appendingPathComponent("request.json")))
            guard input.nonce==nonce,input.slots.count==5 else { throw Failure.invalid }
            for slot in input.slots {
                guard !slot.image.contains("/"),!slot.image.contains("..") else { throw Failure.invalid }
                let bytes=try Data(contentsOf:root.appendingPathComponent(slot.image))
                guard SHA256.hash(data:bytes).map({String(format:"%02x",$0)}).joined()==slot.sha256 else { throw Failure.invalid }
                let decoded=try ReceiptImage.decode(bytes)
                guard let raw=CIImage(data:bytes) else { throw Failure.invalid }
                let image=raw.oriented(forExifOrientation:Int32(decoded.orientation.rawValue))
                for pass in 1...2 {
                    let full=try read(image,region:ReceiptOCRBox(x:0,y:0,width:1,height:1),original:decoded);let baseline=lines(full)
                    let reads=try regions(baseline).map { try read(image,region:$0) }
                    let result=Result(full:full,regions:reads,parsed:ReceiptParser.parse(baseline))
                    try JSONEncoder().encode(result).write(to:root.appendingPathComponent("alternatives-\(slot.slot)-\(pass).json"),options:.atomic)
                }
            }
        } catch { let e = error as NSError; XCTFail("Private alternative probe failed: domain=\(e.domain), code=\(e.code); contents suppressed") }
    }
}
