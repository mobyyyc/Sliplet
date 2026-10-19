# P7-01A — Same-version compatibility repair and completed comparison

2026-10-18. **Deployment repaired; PP-OCRv5_mobile accuracy gate failed. Do not integrate this candidate.** The approved task completed the Simulator comparison. Production Sliplet and the user's phone remain unchanged.

## What changed in the isolated harness

Built OpenCV **4.3.0**, revision `01b2c5a77ca6dbef3baef24ebc0a5984579231d9`, for arm64 iOS Simulator without editing its source. Only core and imgproc are required by the sample. The bundled old zlib failed against the new SDK; use the SDK's system libz and exclude unused image-codec modules. Core/image-processing algorithms remain at the pinned revision. Combined the two static libraries into the sample's OpenCV framework; removed generated Simulator arm64 exclusions. The sample test target uses iOS 17 minimum to match XCTest support; deployment remains in the iOS 27 Simulator.

PP-OCRv5_mobile, its dictionary/configuration, ONNX Runtime 1.24.3 CPU execution, Yams 5.0.6 and PaddleOCR revision `dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf` stayed fixed. Upstream preprocessing uses `noOverrides`. Model archive downloads completed and all model/config hashes were frozen before private inference. Model README metadata identifies Apache-2.0; repository and dependency notices remain retained. No cloud inference, account, Foundation Models or Apple Intelligence dependency was added. Public model/build assets were downloaded; private images were staged locally only.

## Measured results

Five exposed purchases, zero held out. Full-image OCR passed through the **same unchanged Sliplet parser**, compiled separately; visible CAD fallback was applied only during field conversion as in the app. This is an isolated parser comparison, not native production import/save/review integration.

| Final-field measure | Fresh Vision | PP-OCRv5_mobile |
|---|---:|---:|
| Merchant | 5/5 | 2/5 |
| Date | 5/5 | 4/5 |
| Checked subtotal | 4/4 | 4/4 |
| Total | 3/5 | 3/5 |
| Strict exact description/amount purchase pairs | 42/66 | 25/66 |
| Fully correct receipts | 0/5 | 0/5 |

Paddle recovers **zero additional totals**. Relative to the fresh Vision result it loses four correct summary fields and 59 correct line-field outcomes; those 59 are field outcomes, not 59 receipts or purchases. It adds 24 unrelated unmatched-output proxies. These proxies can include formatting/description or association differences and are not automatically invented items. Zero newly wrong matched summary values does not cancel missing fields or unmatched outputs. Candidate promotion is rejected.

The same automatically derived, full-width total strip was also read separately. Both engines produce 3/5 parsed totals there. Strip item/merchant scores are not meaningful whole-receipt scores, and no strip result was fused into a full draft. Correct tokens appearing elsewhere remain candidate availability, not recovered totals. No decimal repair, sign removal, expected-answer selection or manual crop was applied.

## Baseline caveat and interpretation

The historical app baseline remains **43/66**, not 42/66. This harness freshly renders an upright raster through Core Image before giving the identical pixels to both engines. Three receipts have changed Vision text compared with frozen P6-02B; one changes the strict pair score. The lost correct amount row has changed linked source text. Thus this comparison does not reproduce the historical baseline exactly. The cause could include input rendering or runtime variation; no controlled intervention isolates it. Do not describe a one-item difference as a production regression, or treat historical/fresh timings as directly comparable.

The fair within-harness comparison is 42 versus 25 under identical input preparation and parser. It rejects this fixed model-plus-parser configuration. It does not establish that every PaddleOCR model or a redesigned adapter would be worse. It also cannot isolate all losses into OCR versus parser: changed formatting and geometry reach a parser designed around Vision evidence. A future adaptation would be new work, not a reason to waive this failed gate.

## Timing and memory

Two passes reverse engine order for each full image and strip. Forty reads and 20/20 stable output pairs completed. Full-image median/max: Vision approximately **710/1,075 ms**, Paddle **4,087/5,539 ms**. Strip median/max: Vision **315/367 ms**, Paddle **178/241 ms**. Model loading took approximately 124 ms. Repeated reads share one process and cache state; these are descriptive Simulator numbers, not iPhone latency or an optimized deployment benchmark.

Bundled model/config assets are approximately 21.5 MB; the evaluated app bundle is approximately 65.2 MB, including test/build contents rather than an App Store download estimate. Maximum sampled process resident memory was approximately **12.46 GB** across the combined harness. It is not engine-specific, peak allocation or phone memory; both engines and the image pipeline share the process. This high reading needs separate investigation before any device feasibility claim. No memory optimization was attempted after the accuracy failure.

## Verification and retained problems

- Final native tests: two fictional tests pass, covering literal positive/negative amounts, top/bottom geometry, crop mapping and all eight EXIF orientations. Earlier single fictional run also passed. One private native method passed for all 40 readings.
- Eighteen existing scorer tests and four fictional unchanged-parser checks pass, including a genuine refund, payment after total, a product containing TOTAL, and conflicting totals.
- Independent replay: 40/40 parser responses reproduce, all 1,584 observation texts/IDs are preserved, and all five original image hashes remain unchanged.
- The first collector failed because two raw Vision boxes per pass exceeded normalized bounds. The corrected collector mirrors production's existing boundary clamping and maps confidence to engineConfidence; four boxes were normalized in total. Raw outputs, original manifest and original collector are retained privately. The change was recorded before scoring, without changing OCR, text, money or the candidate policy.
- Retained setup failures: old bundled-zlib compiler error; destination rejection until the generated conditional architecture exclusions were removed; initial staging while the test device was shut down. Automatic approval review also hit a usage limit before the final fictional test launch; after the user continued, that launch succeeded. None is reported as a receipt-accuracy failure.
- Frozen private evidence: `private-receipts/evaluation/p7-01a-final-v2`. The earlier incomplete staging folder is not an evaluated run. Source/model/reference hash verification passes. No normal wallet, production Swift or local signing change is included.

[Aggregate](evidence/p7-01a/aggregate.json), [validation](evidence/p7-01a/validation.json), [public dependency pins](evidence/p7-01a/public-dependencies.json), [reproduction](PHASE7_REPRODUCTION.md).

## Decision and next scope

The repair succeeded, but this benchmark provides no basis to replace Vision or add Paddle as an automatic fallback. Keep Paddle out of production. Do not begin a preset sweep, combine contradictory monetary readings, or declare all-field recognition solved.

Recommended next decision: stop this Paddle configuration. If the user wants to continue accuracy work, propose **P7-02: one-item interpretation proof**, using a single existing source-verified item failure to establish whether correct text is lost by grouping/interpretation, then test a bounded change outside production. This is a separate proposal, not an approved continuation or a claim that parser work will help. It must name its first divergent step, exceed the unchanged 43/66 historical reference score in an actual-app baseline comparison without losing correct fields, and stop if no gain. No additional UI phase or wholesale relabeling is needed. Further work requires Main approval.
