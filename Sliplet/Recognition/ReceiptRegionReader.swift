import Foundation
import Vision
import ImageIO

/// One explicit user-requested reread. Coordinates are always relative to the
/// original oriented image; the original image is never cropped or re-encoded.
final class ReceiptRegionReadingJob: @unchecked Sendable {
    enum Failure: Error { case invalidRegion, invalidResult, timedOut, busy }
    static let maximumSeconds: TimeInterval = 3
    private let lock = NSLock()
    private var request: VNRecognizeTextRequest?
    private var cancelled = false
    private var running = false

    func cancel() {
        lock.lock(); cancelled = true; let request = request; lock.unlock()
        request?.cancel()
    }
    private func checkCancellation() throws {
        lock.lock(); let stopped = cancelled; lock.unlock()
        if stopped || Task.isCancelled { throw CancellationError() }
    }
    /// Reject near-empty gestures rather than silently expanding the user's selection.
    static func validate(region: ReceiptOCRBox, image: ReceiptImage) throws {
        let swapped = [5, 6, 7, 8].contains(image.orientation.rawValue)
        let width = Double(swapped ? image.pixelHeight : image.pixelWidth)
        let height = Double(swapped ? image.pixelWidth : image.pixelHeight)
        guard region.width >= 0.02, region.height >= 0.01, region.width * region.height >= 0.001,
              region.width * width >= 16, region.height * height >= 16 else { throw Failure.invalidRegion }
    }
    /// This runtime's ROI observations use ROI-local normalized coordinates. P4-02
    /// and the eight-orientation tests verify applying this transform exactly once.
    static func originalBox(local: CGRect, region: ReceiptOCRBox) throws -> ReceiptOCRBox {
        let epsilon = 0.000001
        guard [local.minX, local.minY, local.width, local.height].allSatisfy(\.isFinite),
              local.width > 0, local.height > 0,
              local.minX >= -epsilon, local.minY >= -epsilon,
              local.maxX <= 1 + epsilon, local.maxY <= 1 + epsilon else { throw Failure.invalidResult }
        let minX = max(0, local.minX), minY = max(0, local.minY)
        let maxX = min(1, local.maxX), maxY = min(1, local.maxY)
        let x = region.x + minX * region.width, y = region.y + minY * region.height
        return try ReceiptOCRBox(x: x, y: y, width: min((maxX - minX) * region.width, 1 - x),
                                 height: min((maxY - minY) * region.height, 1 - y))
    }
    func run(_ image: ReceiptImage, region: ReceiptOCRBox) throws -> OCRResult {
        try checkCancellation()
        try Self.validate(region: region, image: image)
        lock.lock()
        if running { lock.unlock(); throw Failure.busy }
        running = true
        lock.unlock()
        defer { lock.lock(); request = nil; running = false; lock.unlock() }
        let start = ProcessInfo.processInfo.systemUptime
        let request = VNRecognizeTextRequest()
        lock.lock(); self.request = request; let stopped = cancelled; lock.unlock()
        guard !stopped else { throw CancellationError() }
        let deadline = ReceiptRegionDeadline(request: request, seconds: Self.maximumSeconds)
        defer { deadline.finish() }
        do {
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let supported = try request.supportedRecognitionLanguages()
            request.recognitionLanguages = ["en-US", "fr-FR", "zh-Hans", "zh-Hant"].filter(supported.contains)
            request.regionOfInterest = CGRect(x: region.x, y: region.y, width: region.width, height: region.height)
            guard let source = CGImageSourceCreateWithData(image.bytes as CFData, nil),
                  let pixels = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw ImportFailure.unsupportedImage }
            try checkCancellation()
            try VNImageRequestHandler(cgImage: pixels, orientation: image.orientation).perform([request])
            try checkCancellation()
            guard !deadline.expired, ProcessInfo.processInfo.systemUptime - start <= Self.maximumSeconds else { throw Failure.timedOut }
            let observations = request.results ?? []
            guard observations.count <= 2_000 else { throw Failure.invalidResult }
            var lines: [ReceiptOCRLine] = [], bytes = 0
            for observation in observations {
                try checkCancellation()
                guard let candidate = observation.topCandidates(1).first else { continue }
                bytes += candidate.string.utf8.count
                guard candidate.string.utf8.count <= 8_192, bytes <= 131_072,
                      candidate.confidence.isFinite, (0...1).contains(candidate.confidence) else { throw Failure.invalidResult }
                // Vision can return a boundary-crossing observation when a drawn
                // region cuts through a word. Omit that observation, keeping only
                // fully contained evidence instead of rejecting unrelated valid rows.
                guard let box = try? Self.originalBox(local: observation.boundingBox, region: region) else { continue }
                lines.append(ReceiptOCRLine(id: UUID(), text: candidate.string, engineConfidence: candidate.confidence, boundingBox: box))
            }
            try checkCancellation()
            guard !deadline.expired, ProcessInfo.processInfo.systemUptime - start <= Self.maximumSeconds else { throw Failure.timedOut }
            return OCRResult(lines: lines, revision: request.revision)
        } catch {
            try checkCancellation()
            if deadline.expired || ProcessInfo.processInfo.systemUptime - start > Self.maximumSeconds { throw Failure.timedOut }
            throw error
        }
    }
}

/// A request-specific cooperative timer cannot cancel a subsequent read.
private final class ReceiptRegionDeadline: @unchecked Sendable {
    private let lock = NSLock()
    private let request: VNRecognizeTextRequest
    private var finished = false
    private var timedOut = false
    var expired: Bool { lock.lock(); defer { lock.unlock() }; return timedOut }
    init(request: VNRecognizeTextRequest, seconds: TimeInterval) {
        self.request = request
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self else { return }
            self.lock.lock(); defer { self.lock.unlock() }
            guard !self.finished else { return }
            self.timedOut = true; self.request.cancel()
        }
    }
    func finish() { lock.lock(); finished = true; lock.unlock() }
}
