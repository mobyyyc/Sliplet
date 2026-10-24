import Foundation
import Vision
import AppKit
// Reads only a prepared input image; prints OCR JSON for private capture by the runner.
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
request.recognitionLanguages = ["en-US", "zh-Hant"]
try VNImageRequestHandler(url: url).perform([request])
let rows = (request.results ?? []).compactMap { observation -> [String: Any]? in
    guard let text = observation.topCandidates(1).first?.string else { return nil }
    let b = observation.boundingBox
    return ["text": text, "box": [b.minX, 1-b.maxY, b.maxX, 1-b.minY]]
}
let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
