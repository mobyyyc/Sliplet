import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

/// Only these freshly encoded pixels may cross the upload boundary. Original bytes
/// and metadata are never passed to the transport. Coordinates use top-left origin.
struct ReceiptUploadImage: Sendable, Identifiable {
    let id = UUID()
    let bytes: Data
    let width: Int
    let height: Int
    static let maximumBytes = 8_000_000

    static func prepare(_ original: ReceiptImage, redactions: [CGRect]) throws -> Self {
        try Task.checkCancellation()
        guard redactions.count <= 100,
              let source = CGImageSourceCreateWithData(original.bytes as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary),
              let context = CGContext(data: nil, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw ImportFailure.unsupportedImage }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(bounds)
        context.draw(image, in: bounds)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        for rect in redactions {
            guard [rect.minX, rect.minY, rect.width, rect.height].allSatisfy({ $0.isFinite }),
                  rect.size.width > 0, rect.size.height > 0 else { throw ImportFailure.unsupportedImage }
            let clipped = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard !clipped.isNull else { continue }
            // Round outward to cover every selected pixel, including the selection boundary.
            let pixels = CGRect(x: clipped.minX * bounds.width, y: (1 - clipped.maxY) * bounds.height,
                                width: clipped.width * bounds.width, height: clipped.height * bounds.height).integral
            context.fill(pixels)
        }
        try Task.checkCancellation()
        guard let flattened = context.makeImage() else { throw ImportFailure.unsupportedImage }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { throw ImportFailure.unsupportedImage }
        // A new destination receives only our CGImage and quality, never source properties.
        CGImageDestinationAddImage(destination, flattened, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length <= maximumBytes else { throw ImportFailure.tooLarge }
        return Self(bytes: output as Data, width: image.width, height: image.height)
    }
}
