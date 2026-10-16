import XCTest
import UIKit
import CoreImage
import ImageIO
@testable import Sliplet

@MainActor final class ReceiptRegionReaderTests: XCTestCase {
    private func image() throws -> ReceiptImage { try ReceiptImage.decode(SyntheticFixture.imageData()) }
    func testLocalBoxMapsOnceIntoOriginalImage() throws {
        let region = try ReceiptOCRBox(x: 0.2, y: 0.3, width: 0.5, height: 0.4)
        let mapped = try ReceiptRegionReadingJob.originalBox(local: CGRect(x: 0.1, y: 0.2, width: 0.6, height: 0.3), region: region)
        XCTAssertEqual(mapped.x, 0.25, accuracy: 0.000001)
        XCTAssertEqual(mapped.y, 0.38, accuracy: 0.000001)
        XCTAssertEqual(mapped.width, 0.3, accuracy: 0.000001)
        XCTAssertEqual(mapped.height, 0.12, accuracy: 0.000001)
        XCTAssertEqual(try ReceiptRegionReadingJob.originalBox(local: CGRect(x: 0, y: 0, width: 1, height: 1), region: region), region)
    }
    func testInvalidLocalBoxesAreRejectedInsteadOfFabricatingGeometry() throws {
        let region = try ReceiptOCRBox(x: 0.1, y: 0.2, width: 0.7, height: 0.6)
        for invalid in [CGRect.zero, CGRect(x: -0.1, y: 0, width: 0.2, height: 0.2),
                        CGRect(x: 0.9, y: 0.1, width: 0.2, height: 0.2),
                        CGRect(x: CGFloat.nan, y: 0, width: 0.2, height: 0.2)] {
            XCTAssertThrowsError(try ReceiptRegionReadingJob.originalBox(local: invalid, region: region))
        }
    }
    func testTinyRegionsAreRejectedAndOrientationControlsPixelThreshold() throws {
        let original = try image()
        for region in [try ReceiptOCRBox(x: 0, y: 0, width: 0.001, height: 0.9),
                       try ReceiptOCRBox(x: 0, y: 0, width: 0.9, height: 0.001),
                       try ReceiptOCRBox(x: 0, y: 0, width: 0.02, height: 0.01)] {
            XCTAssertThrowsError(try ReceiptRegionReadingJob.validate(region: region, image: original))
        }
        let region = try ReceiptOCRBox(x: 0, y: 0, width: 0.02, height: 0.5)
        let wide = ReceiptImage(bytes: original.bytes, mediaType: original.mediaType, orientation: .up, pixelWidth: 2000, pixelHeight: 500)
        let rotated = ReceiptImage(bytes: original.bytes, mediaType: original.mediaType, orientation: .right, pixelWidth: 2000, pixelHeight: 500)
        XCTAssertNoThrow(try ReceiptRegionReadingJob.validate(region: region, image: wide))
        XCTAssertThrowsError(try ReceiptRegionReadingJob.validate(region: region, image: rotated))
    }
    func testCancelledJobRemainsCancelledAcrossAttempts() throws {
        let job = ReceiptRegionReadingJob(), original = try image()
        let full = try ReceiptOCRBox(x: 0, y: 0, width: 1, height: 1)
        job.cancel()
        for _ in 0..<2 {
            XCTAssertThrowsError(try job.run(original, region: full)) { XCTAssertTrue($0 is CancellationError) }
        }
    }
    func testTaskCancellationIsRecognizedBeforeVision() async throws {
        let original = try image(), full = try ReceiptOCRBox(x: 0, y: 0, width: 1, height: 1)
        let task = Task.detached {
            while !Task.isCancelled { await Task.yield() }
            return try ReceiptRegionReadingJob().run(original, region: full)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled read unexpectedly returned") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
    private func fixture() throws -> ReceiptImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let data = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1200), format: format).pngData { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1000, height: 1200))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 42, weight: .regular), .foregroundColor: UIColor.black]
            ("ALPHA MARKET" as NSString).draw(at: CGPoint(x: 150, y: 180), withAttributes: attributes)
            ("FICTIONAL APPLES 12.34" as NSString).draw(at: CGPoint(x: 150, y: 750), withAttributes: attributes)
        }
        return try ReceiptImage.decode(data)
    }
    func testNativeROICoordinatesForAllEightEXIFOrientationsPreserveOriginalBytes() async throws {
        let decoded = try fixture(), full = try ReceiptOCRBox(x: 0, y: 0, width: 1, height: 1)
        for orientation: CGImagePropertyOrientation in [.up, .upMirrored, .down, .downMirrored, .leftMirrored, .right, .rightMirrored, .left] {
            let inverse: CGImagePropertyOrientation = orientation == .right ? .left : orientation == .left ? .right : orientation
            let source = try XCTUnwrap(CIImage(data: decoded.bytes)), transformed = source.oriented(inverse)
            let pixels = try XCTUnwrap(CIContext().createCGImage(transformed, from: transformed.extent))
            let buffer = NSMutableData()
            let destination = try XCTUnwrap(CGImageDestinationCreateWithData(buffer, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, pixels, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
            let original = ReceiptImage(bytes: buffer as Data, mediaType: decoded.mediaType, orientation: orientation, pixelWidth: pixels.width, pixelHeight: pixels.height)
            let retained = original.bytes
            let baseline = try await Task.detached { try ReceiptRegionReadingJob().run(original, region: full) }.value
            let marker = try XCTUnwrap(baseline.lines.first { $0.text.contains("ALPHA MARKET") }?.boundingBox)
            let rectangle = CGRect(x: marker.x, y: marker.y, width: marker.width, height: marker.height)
                .insetBy(dx: -0.08, dy: -0.08).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            let region = try ReceiptOCRBox(x: rectangle.minX, y: rectangle.minY, width: rectangle.width, height: rectangle.height)
            let reread = try await Task.detached { try ReceiptRegionReadingJob().run(original, region: region) }.value
            let found = try XCTUnwrap(reread.lines.first { $0.text.contains("ALPHA MARKET") }?.boundingBox)
            XCTAssertEqual(found.x + found.width / 2, marker.x + marker.width / 2, accuracy: 0.04)
            XCTAssertEqual(found.y + found.height / 2, marker.y + marker.height / 2, accuracy: 0.04)
            XCTAssertEqual(found.width, marker.width, accuracy: 0.08)
            XCTAssertFalse(reread.lines.contains { $0.text.contains("APPLES") })
            XCTAssertEqual(original.bytes, retained)
            XCTAssertTrue(Set(baseline.lines.map(\.id)).isDisjoint(with: Set(reread.lines.map(\.id))))
        }
    }
    func testRegionCuttingAnotherRowStillReturnsContainedEvidence() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let bytes = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 600), format: format).pngData { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1000, height: 600))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 42, weight: .regular), .foregroundColor: UIColor.black]
            ("PARTIALLY CUT HEADING" as NSString).draw(at: CGPoint(x: 20, y: 50), withAttributes: attributes)
            ("APPLES 12.34" as NSString).draw(at: CGPoint(x: 300, y: 300), withAttributes: attributes)
        }
        let image = try ReceiptImage.decode(bytes)
        let region = try ReceiptOCRBox(x: 0.15, y: 0.05, width: 0.8, height: 0.9)
        let result = try await Task.detached { try ReceiptRegionReadingJob().run(image, region: region) }.value
        XCTAssertTrue(result.lines.contains { $0.text.contains("12.34") })
        for line in result.lines {
            let box = try XCTUnwrap(line.boundingBox)
            XCTAssertGreaterThanOrEqual(box.x, region.x)
            XCTAssertLessThanOrEqual(box.x + box.width, region.x + region.width + 0.000001)
        }
    }

}
