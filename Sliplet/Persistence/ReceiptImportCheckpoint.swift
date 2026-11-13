import Foundation

/// An encrypted local checkpoint. Prepared upload bytes and consent are session-only.
struct ReceiptImportCheckpoint: Codable, Equatable, Sendable {
    struct Review: Codable, Equatable, Sendable {
        let extraction: ReceiptExtraction
        let draft: ReceiptReviewDraft
    }

    let id: UUID
    let fromCamera: Bool
    let adjustment: ReceiptPhotoAdjustment
    let step: Int
    let useAI: Bool
    let covers: [CGRect]
    let review: Review?

    func validate() throws {
        func isNormalized(_ rect: CGRect) -> Bool {
            rect.width > 0 && rect.height > 0 && rect.minX >= 0 && rect.minY >= 0
                && rect.maxX <= 1 && rect.maxY <= 1
        }
        guard (0...2).contains(step), step != 2 || useAI,
              (0...3).contains(adjustment.turns), isNormalized(adjustment.crop),
              adjustment.crop.width >= 0.02, adjustment.crop.height >= 0.02,
              covers.allSatisfy(isNormalized) else { throw ReceiptStoreError.corruptStore }
        try review?.extraction.validate()
    }
}
