import Foundation
import UIKit
import ImageIO

/// Crop is normalized in the oriented, rotated image. The source bytes remain untouched.
struct ReceiptPhotoAdjustment: Codable, Equatable, Sendable {
    var turns = 0
    var crop = CGRect(x: 0, y: 0, width: 1, height: 1)
    var isIdentity: Bool { turns == 0 && crop == CGRect(x: 0, y: 0, width: 1, height: 1) }

    static func displayImage(_ original: ReceiptImage) throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(original.bytes as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw ImportFailure.unsupportedImage }
        return UIImage(cgImage: cg)
    }

    func prepare(_ original: ReceiptImage) throws -> ReceiptImage {
        if isIdentity { return original }
        guard crop.minX >= 0, crop.minY >= 0, crop.maxX <= 1, crop.maxY <= 1,
              crop.width >= 0.02, crop.height >= 0.02, (0...3).contains(turns),
              let source = CGImageSourceCreateWithData(original.bytes as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 4096
              ] as CFDictionary) else { throw ImportFailure.unsupportedImage }
        try Task.checkCancellation()
        let size = turns % 2 == 0 ? CGSize(width: cg.width, height: cg.height) : CGSize(width: cg.height, height: cg.width)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let rotated = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.cgContext.rotate(by: CGFloat(turns) * .pi / 2)
            UIImage(cgImage: cg).draw(in: CGRect(x: -CGFloat(cg.width) / 2, y: -CGFloat(cg.height) / 2,
                                                width: CGFloat(cg.width), height: CGFloat(cg.height)))
        }
        // Resample the exact normalized crop rather than rounding its bounds outward;
        // this keeps source-coordinate mapping correct even at fractional pixel edges.
        let outputSize = CGSize(width: max(1, floor(crop.width * size.width)), height: max(1, floor(crop.height * size.height)))
        let clipped = UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            rotated.draw(in: CGRect(x: -crop.minX * outputSize.width / crop.width,
                y: -crop.minY * outputSize.height / crop.height,
                width: outputSize.width / crop.width, height: outputSize.height / crop.height))
        }
        guard let bytes = clipped.jpegData(compressionQuality: 0.98) else { throw ImportFailure.unsupportedImage }
        return try ReceiptImage.decode(bytes)
    }

    /// Map lower-left OCR coordinates back to the unmodified, oriented source image.
    func originalBox(_ box: ReceiptOCRBox) throws -> ReceiptOCRBox {
        let corners = [(box.x, box.y), (box.x + box.width, box.y),
                       (box.x, box.y + box.height), (box.x + box.width, box.y + box.height)].map { x, y in
            let u = crop.minX + x * crop.width
            let v = crop.minY + (1 - y) * crop.height
            switch turns {
            case 1: return CGPoint(x: v, y: 1 - u)
            case 2: return CGPoint(x: 1 - u, y: 1 - v)
            case 3: return CGPoint(x: 1 - v, y: u)
            default: return CGPoint(x: u, y: v)
            }
        }
        let x = max(0, corners.map(\.x).min()!), top = max(0, corners.map(\.y).min()!)
        let right = min(1, corners.map(\.x).max()!), bottom = min(1, corners.map(\.y).max()!)
        let y = max(0, 1 - bottom)
        return try ReceiptOCRBox(x: x, y: y, width: min(right - x, 1 - x), height: min(bottom - top, 1 - y))
    }
    func sourceEvidence(_ extraction: ReceiptExtraction) throws -> ReceiptExtraction {
        guard !isIdentity else { return extraction }
        func lines(_ values: [ReceiptOCRLine]) throws -> [ReceiptOCRLine] {
            try values.map { ReceiptOCRLine(id: $0.id, text: $0.text, engineConfidence: $0.engineConfidence,
                                           boundingBox: try $0.boundingBox.map(originalBox)) }
        }
        func pass(_ p: ReceiptReadingPass) throws -> ReceiptReadingPass {
            try ReceiptReadingPass(lines: lines(p.lines), revision: p.revision, usesLanguageCorrection: p.usesLanguageCorrection)
        }
        let evidence = try extraction.readingEvidence.map {
            try ReceiptReadingEvidence(baseline: pass($0.baseline), corrected: $0.corrected.map(pass), outcome: $0.outcome)
        }
        return try ReceiptExtraction(capturedAt: extraction.capturedAt, recognizer: extraction.recognizer,
            recognizerVersion: extraction.recognizerVersion, parser: extraction.parser, parserVersion: extraction.parserVersion,
            rawOCR: lines(extraction.rawOCR), rawParserOutput: extraction.rawParserOutput, fields: extraction.fields,
            issues: extraction.issues, readingEvidence: evidence)
    }
}
