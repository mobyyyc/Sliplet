import XCTest
import UIKit
import CoreImage
import Vision
import CryptoKit
import ImageIO
@testable import PaddleOCRDemo

@MainActor final class SlipletIndependentOCRTests: XCTestCase {
    struct Box: Codable { let x: Double; let y: Double; let width: Double; let height: Double }
    struct Line: Codable { let id: UUID; let text: String; let confidence: Double; let boundingBox: Box }
    struct Slot: Decodable { let slot: Int; let image: String; let sha256: String; let region: Box }
    struct Request: Decodable { let slots: [Slot] }
    struct Reading: Codable { let engine: String; let condition: String; let pass: Int; let slot: Int; let observations: [Line]; let milliseconds: Double; let residentBytes: UInt64 }
    func residentBytes() -> UInt64 {
        var info=mach_task_basic_info(); var count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let status=withUnsafeMutablePointer(to:&info) { ptr in ptr.withMemoryRebound(to:integer_t.self,capacity:Int(count)) { task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count) } }
        return status==KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }
    enum Failure: Error { case invalid }
    let ci = CIContext(options: [.cacheIntermediates: false])
    func upright(_ data: Data) throws -> CGImage {
        guard let raw = CIImage(data: data, options: [.applyOrientationProperty: true]), let cg = ci.createCGImage(raw, from: raw.extent) else { throw Failure.invalid }; return cg
    }
    func paddle(_ image: CGImage, engine: OCREngine, roi: Box) async throws -> [Line] {
        let result = try await engine.run(image, params: .noOverrides)
        return result.results.map { r in
            let xs = r.polygon.map { Double($0[0]) / Double(image.width) }
            let ys = r.polygon.map { Double($0[1]) / Double(image.height) }
            let x = max(0, xs.min() ?? 0), y = max(0, 1 - (ys.max() ?? 1))
            let w = min(1, xs.max() ?? 1) - x, h = min(1, 1 - (ys.min() ?? 0)) - y
            return Line(id: UUID(), text: r.text, confidence: Double(r.confidence), boundingBox: Box(x: roi.x+x*roi.width, y: roi.y+y*roi.height, width: w*roi.width, height: h*roi.height))
        }
    }
    func vision(_ image: CGImage, roi: Box) throws -> [Line] {
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = false
        let supported = try request.supportedRecognitionLanguages(); request.recognitionLanguages = ["en-US","fr-FR","zh-Hans","zh-Hant"].filter(supported.contains)
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        return (request.results ?? []).compactMap { o in
            guard let t = o.topCandidates(1).first else { return nil }; let b = o.boundingBox
            return Line(id: UUID(), text: t.string, confidence: Double(t.confidence), boundingBox: Box(x: roi.x+b.minX*roi.width, y: roi.y+b.minY*roi.height, width: b.width*roi.width, height: b.height*roi.height))
        }
    }
    func fixture() -> CGImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1000,height: 700), format: format).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x:0,y:0,width:1000,height:700))
            for (i,s) in ["DEMO MARKET", "APPLES 12.50", "REFUND -9.25", "TOTAL 42.75"].enumerated() {
                (s as NSString).draw(at: CGPoint(x:100,y:70+i*130), withAttributes: [.font:UIFont.monospacedSystemFont(ofSize:48,weight:.regular),.foregroundColor:UIColor.black])
            }
        }.cgImage!
    }
    func testFictionalOfflineRecognitionAndMapping() async throws {
        let manager = ORTSessionManager(); try await manager.loadModels(executionProvider: .cpu)
        let engine = try OCREngine(sessionManager: manager); let image = fixture(); let full = Box(x:0,y:0,width:1,height:1)
        let lines = try await paddle(image, engine: engine, roi: full)
        XCTAssertTrue(lines.contains { $0.text.contains("42.75") })
        XCTAssertTrue(lines.contains { $0.text.contains("-9.25") })
        XCTAssertTrue(lines.contains { $0.text.contains("DEMO") })
        for l in lines { XCTAssertGreaterThanOrEqual(l.boundingBox.x,0); XCTAssertGreaterThanOrEqual(l.boundingBox.y,0); XCTAssertLessThanOrEqual(l.boundingBox.x+l.boundingBox.width,1.001); XCTAssertLessThanOrEqual(l.boundingBox.y+l.boundingBox.height,1.001) }
        let top = try XCTUnwrap(lines.first { $0.text.contains("DEMO") }); let bottom = try XCTUnwrap(lines.first { $0.text.contains("42.75") }); XCTAssertGreaterThan(top.boundingBox.y,bottom.boundingBox.y)
        let roi = Box(x:0,y:0.1,width:1,height:0.4)
        let crop = try XCTUnwrap(image.cropping(to:CGRect(x:0,y:350,width:1000,height:280)))
        let mapped = try await paddle(crop,engine:engine,roi:roi)
        XCTAssertTrue(mapped.contains { $0.text.contains("42.75") })
        for l in mapped { XCTAssertGreaterThanOrEqual(l.boundingBox.y,roi.y); XCTAssertLessThanOrEqual(l.boundingBox.y+l.boundingBox.height,roi.y+roi.height+0.001) }
    }
    func testEXIFOrientationNormalization() throws {
        let original = fixture(); let inverses: [Int32] = [1,2,3,4,5,8,7,6]
        for tag in 1...8 {
            let raw=CIImage(cgImage:original).oriented(forExifOrientation:inverses[tag-1])
            let pixels=try XCTUnwrap(ci.createCGImage(raw,from:raw.extent))
            let bytes=NSMutableData(); let dest=try XCTUnwrap(CGImageDestinationCreateWithData(bytes,"public.tiff" as CFString,1,nil))
            CGImageDestinationAddImage(dest,pixels,[kCGImagePropertyOrientation:tag] as CFDictionary); XCTAssertTrue(CGImageDestinationFinalize(dest))
            let result=try upright(bytes as Data)
            XCTAssertEqual(result.width,original.width); XCTAssertEqual(result.height,original.height)
            // Compare normalized raster samples, including asymmetric printed text.
            func raster(_ cg:CGImage) -> [UInt8] {
                var v=[UInt8](repeating:0,count:cg.width*cg.height*4)
                v.withUnsafeMutableBytes { b in let c=CGContext(data:b.baseAddress,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!; c.draw(cg,in:CGRect(x:0,y:0,width:cg.width,height:cg.height)) }; return v
            }
            let a=raster(original),b=raster(result); let mean=zip(a,b).reduce(0.0) { $0+abs(Double($1.0)-Double($1.1)) } / Double(a.count)
            XCTAssertLessThan(mean,1.0)
        }
    }
    func testPrivateComparison() async throws {
        guard ProcessInfo.processInfo.environment["SLIPLET_P701_PRIVATE"] == "YES" else { throw XCTSkip("Explicit private benchmark only") }
        do {
            let docs = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("P701")
            let request = try JSONDecoder().decode(Request.self,from:Data(contentsOf:docs.appendingPathComponent("request.json")))
            let manager = ORTSessionManager(); let start = ProcessInfo.processInfo.systemUptime
            try await manager.loadModels(executionProvider:.cpu); let engine = try OCREngine(sessionManager:manager)
            try JSONEncoder().encode(["loadMilliseconds":(ProcessInfo.processInfo.systemUptime-start)*1000]).write(to:docs.appendingPathComponent("load.json"))
            for slot in request.slots {
                let data = try Data(contentsOf:docs.appendingPathComponent(slot.image)); guard SHA256.hash(data:data).map({String(format:"%02x",$0)}).joined()==slot.sha256 else { throw Failure.invalid }
                let cg = try upright(data); let r = slot.region
                let rect = CGRect(x:r.x*Double(cg.width),y:(1-r.y-r.height)*Double(cg.height),width:r.width*Double(cg.width),height:r.height*Double(cg.height)).integral.intersection(CGRect(x:0,y:0,width:cg.width,height:cg.height))
                guard let crop=cg.cropping(to:rect) else { throw Failure.invalid }
                let mapped=Box(x:rect.minX/Double(cg.width),y:1-rect.maxY/Double(cg.height),width:rect.width/Double(cg.width),height:rect.height/Double(cg.height))
                var readings:[Reading]=[]
                for pass in 1...2 {
                    for (condition,input,roi) in [("full",cg,Box(x:0,y:0,width:1,height:1)),("strip",crop,mapped)] {
                        for name in (pass==1 ? ["vision","paddle"] : ["paddle","vision"]) {
                            let t=ProcessInfo.processInfo.systemUptime
                            let lines = name=="vision" ? try vision(input,roi:roi) : try await paddle(input,engine:engine,roi:roi)
                            readings.append(Reading(engine:name,condition:condition,pass:pass,slot:slot.slot,observations:lines,milliseconds:(ProcessInfo.processInfo.systemUptime-t)*1000,residentBytes:residentBytes()))
                        }
                    }
                }
                try JSONEncoder().encode(readings).write(to:docs.appendingPathComponent("readings-\(slot.slot).json"),options:.atomic)
            }
        } catch { XCTFail("Private comparison failed; details remain private.") }
    }
}
