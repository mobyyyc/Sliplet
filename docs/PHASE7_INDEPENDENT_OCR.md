# P7-01 — Independent OCR deployment gate

2026-10-18. Approved PP-OCRv5_mobile benchmark attempted. **Deployment gate failed; receipt comparison was not run.** This is neither an accuracy failure nor an accuracy success. Sliplet production code and installed wallets remain unchanged.

## What happened

Pinned the official PaddleOCR sample at `dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf`, PP-OCRv5_mobile, ONNX Runtime 1.24.3, OpenCV 4.3.0 and Yams 5.0.6. Installed CocoaPods 1.17.0 and its Homebrew Ruby/build dependencies on the Mac for the approved local setup. Only the upstream lockfile's CocoaPods version metadata changed; actual dependency versions and checksums stayed fixed. Model downloads were public downloads, never receipt uploads.

Two routine setup issues were resolved: older dependency deployment targets were overridden to the sample's iOS 16 minimum, and an empty Models folder allowed compile/link diagnosis while assets downloaded. The resulting default Simulator build succeeded **only for Intel x86_64**. That compile success did not load a model or establish runnable OCR.

The pinned OpenCV binary excludes arm64 Simulator builds. The isolated iPhone 15 Pro / iOS 27.0 destination on this Mac supports arm64 and rejects the default sample build. A diagnostic forced-arm64 build confirms that OpenCV's arm64 object targets physical iOS, not iOS Simulator. These platform slices are not interchangeable. Removing the exclusion is insufficient.

The approved protocol says to stop on a deployment failure rather than silently change the model. No engine/model sweep, dependency upgrade, private scoring, phone installation or production integration occurred. The remaining model download was stopped and its partial archive marked `.partial` so it cannot be mistaken for a complete asset. Model/dictionary hashes are not yet frozen for inference because the complete bundle was not obtained. The unused dedicated Simulator was removed; downloaded public setup files remain in `/tmp/sliplet-p701-paddle` for a separately approved repair. Homebrew dependencies remain installed.

## Evidence and limits

[Public build diagnostics](evidence/p7-01/deployment.txt), [versions and validation](evidence/p7-01/validation.json), [fixed benchmark protocol](../evaluation/receipt-independent-ocr/README.md).

The upstream repository/Clipper/ONNX licenses and generated dependency notices are present locally. Full model-asset licensing and final notice packaging remain pending alongside complete model acquisition. No redistributable candidate was produced.

Private images processed: **0**. Fictional model inferences: **0**. Raw/final accuracy, load time, inference latency, memory and complete package size: **unmeasured**. Existing Sliplet scores remain historical 3/5 totals and 43/66 strict item pairs; they are not a PaddleOCR comparison. No accuracy gate passed or failed. Production-source comparison against `d6b871d` is empty, and the preexisting local signing change is preserved.

## Concrete next task proposed: P7-01A compatibility repair

Requires separate approval. Keep the same PP-OCRv5_mobile preset, ONNX Runtime and frozen recognition policy. First attempt to build **the same OpenCV 4.3.0 source** for arm64 iOS Simulator in the isolated harness, retaining physical-device support separately if needed later. This changes packaging/build compatibility rather than selecting a different OCR model. Preserve required licenses and record source/build hashes. If that source cannot build with this toolchain without substantive changes, stop and propose an explicit dependency revision; do not hide a version change.

After a compatible build exists, finish model downloads and pin hashes, then run fictional offline recognition and coordinate/sign checks. Only after those pass, resume the already approved five-receipt protocol with separate raw-text and unchanged-parser scoring. No user relabeling is needed. No production integration or phone update is part of this repair. Success at deployment is still not evidence of better accuracy.
