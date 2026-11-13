import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Sliplet

@MainActor final class ReceiptShareTests: XCTestCase {
    func testExportUsesOpaqueRGBPNGAndScalesLongReceipts() throws {
        let short = try ReceiptShareRenderer.render(SplitFixture.record(amounts: [499, 699]))
        let long = try ReceiptShareRenderer.render(SplitFixture.record(amounts: Array(repeating: 499, count: 500)))
        XCTAssertEqual(short.width, 1380)
        XCTAssertGreaterThan(long.height, short.height)
        XCTAssertGreaterThanOrEqual(long.width, 460)
        XCTAssertLessThanOrEqual(long.height, 32_000)
        for image in [short, long] {
            let bytes = try ReceiptShareRenderer.pngData(image)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(bytes as CFData, nil))
            XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.png.identifier)
            XCTAssertEqual(CGImageSourceGetCount(source), 1)
            let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(decoded.width, image.width)
            XCTAssertEqual(decoded.height, image.height)
            XCTAssertEqual(decoded.colorSpace?.model, .rgb)
            XCTAssertTrue([CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(decoded.alphaInfo))
        }
    }
}
