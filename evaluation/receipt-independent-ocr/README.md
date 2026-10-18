# P7-01 isolated independent OCR benchmark

Approved 2026-10-18. No production integration or phone update.

Fixed before private scoring: PP-OCRv5_mobile detection and recognition, official PaddleOCR demo revision dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf, upstream locked dependencies (ONNX Runtime 1.24.3, OpenCV 4.3.0, Yams 5.0.6), CPU execution. Retain upstream model/preprocessing defaults; record asset hashes before inference. Do not silently switch presets or tune parameters against reference answers.

Deployment gate precedes private inputs: resolve locked dependencies, build isolated iOS Simulator app, run fictional OCR offline, validate coordinates/orientation/sign margins. If deployment fails, preserve exact public error evidence and stop with a deployment result, not an accuracy claim. No private receipt is copied into tracked sample fixtures.

If deployment passes: compare full original image and the existing automatic total strip with native Vision, two passes in alternating order. Separate literal OCR evidence from unchanged-parser final fields. No fused outputs, decimal repairs, sign arbitration or reference-driven selection. Preserve original coordinates and observation provenance. Score all five stored checked receipts, report losses as well as gains and candidate-only outcomes separately. Existing references remain immutable and evaluator-only.

Promotion requires at least 4/5 final totals with no lost checked success or unsupported money. Item-only or raw-candidate-only gains do not pass the total gate. Report Simulator latency/memory and measured package sizes separately from phone performance. No held-out accuracy claim. All future integration requires separate approval.
