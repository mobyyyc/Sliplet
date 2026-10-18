# P6-07 — Early decision: change the experiment, keep the app

2026-10-18. Approved assessment completed. **Phase 6 closes with its automatic-accuracy goal unmet.** P6-01, P6-02, P6-02B and this early P6-07 are complete. P6-03 through P6-06 were not executed. No recognizer, parser, UI, model dependency, receipt label or installed app changes in this task.

## What we can say now

| Measure | P5-06 baseline | End of Phase 6 |
|---|---:|---:|
| Strict exact description/amount purchase pairs | 43/66 | 43/66 |
| Legacy purchase recovery (different matching rule) | 53/66 | 53/66 |
| Merchant / date | 5/5 each | 5/5 each |
| Checked subtotal / total | 4/4 / 3/5 | 4/4 / 3/5 |
| Fully correct receipts | 0/5 | 0/5 |
| Held-out purchases | 0 | 0 |

The unchanged production source matches P5-05 candidate `d6b871d`. Both isolated total probes made 20 region reads each and recovered zero totals, without losing existing correct totals or adding wrong totals. Ten baseline imports per probe verified five stable repeat pairs and draft round trips. No candidate was integrated or saved as a new production draft. These are retained development results, not fresh P6-07 imports or a release acceptance test.

P6-02 crop reads had median/max approximately 436/860 ms; P6-02B 404/767 ms. These separate Simulator measurements do not establish a speed improvement and are not phone timings. Human correction time remains unmeasured. Tax, quantity, units and other incomplete annotations still prevent an all-field accuracy claim.

## Failure analysis and limits of the experiments

1. **Missing total:** the original full-image OCR omits the amount. Inversion exposes the correct literal amount but damages its label. Retaining the original label fixes that association obstacle. The corroborating original crop then has a colon instead of a decimal separator, so the fixed policy rejects it. Geometry is not the remaining failure. This is useful candidate evidence, not accepted automatic recovery.
2. **Spurious sign:** the original OCR adds an unprinted trailing minus. The existing checked transcript removes it and the current parser recovers the total. Both experiments preserve baseline sign conflicts by design; neither could accept a replacement for this case through its selection rule. Crop readings also failed to supply the correct digits. Thus the experiments tested only a limited recovery policy, not whether a different recognizer could resolve the sign.
3. **Items:** checked Costco text still leaves item interpretation errors. New OCR alone cannot be assumed to fix these. Duplicate identities and incomplete annotations also limit measurement; 43/66 is a final-field metric, not an OCR character score.
4. **Experiment design:** two transformations or repeated runs of the same engine are correlated. Requiring agreement with the very reading known to be malformed can prevent a valid improvement. Conversely, accepting whichever result looks plausible can introduce unsupported money. Neither majority voting nor reconciliation establishes truth. Any future conflict policy needs an explicit source-evidence hierarchy, genuine-negative fixtures and separate approval; do not silently strip signs or replace colons.

Phase 6 establishes that these two fixed policies do not help. It does not establish that all on-device OCR is inadequate, nor that the dark bar is the only cause. Repeating small threshold/filter changes against five exposed receipts risks fitting the test examples without improving everyday use.

## Alternatives considered

| Approach | What it could address | Decision |
|---|---|---|
| More total keywords / merchant aliases | Misclassified labels or unknown merchants | Not the cause of these two total failures; merchants already 5/5. Do not prioritize. |
| More Vision candidates or preprocessing | Alternative characters or improved pixels | Technically available, but same-engine correlation and post-hoc selection remain. No further incremental probe now. |
| Apple document/table recognition | Structural grouping | Earlier P2-02 document variants regressed purchase recovery on these images. Historical evidence uses older code/toolchain; it is not proof every future version fails, but no new reason justifies repeating it now. |
| A different compact OCR engine | Different character errors and detection | Recommended next isolated comparison; no accuracy promise. Keep interpretation frozen so causes remain visible. |
| Targeted parser work | Correct text reaching wrong/missing fields | Still relevant, but requires a named verified failure and separate approval. Not authorized as a substitute for the failed total gate. |
| User-confirmed region / amount | Resolve a specific remaining ambiguity | Useful assisted fallback; reuse current controls. Measure separately, never count a human choice as automatic recovery. |
| Generative document model / cloud | Broader semantic extraction | Outside the agreed local scope; no evidence here justifies size, deployment and unsupported-output risks. |

Apple exposes ranked text candidates through [topCandidates](https://developer.apple.com/documentation/vision/vnrecognizedtextobservation/topcandidates(_:)); current Sliplet retains only the first. Availability alone says nothing about whether a lower-ranked answer is correct.

**Preferred candidate: PP-OCRv5_mobile, pinned before testing.** PaddleOCR documents an iOS SwiftUI sample using exported ONNX models with ONNX Runtime, including this preset and Simulator benchmarking. CPU execution can avoid assuming Neural Engine availability in Simulator. This is a documented route, not a locally verified build or iPhone performance result. The repository uses Apache-2.0; exact model assets, runtime dependencies and notices still need checking. Choose one documented compact preset, not a sweep of models chosen by private scores. [Official iOS deployment](https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/main/docs/version3.x/inference_deployment/cross_platform/ios_deployment.en.md), [repository license](https://github.com/PaddlePaddle/PaddleOCR/blob/main/LICENSE).

ML Kit is another native option: its iOS SDK bundles models and exposes text geometry, with about 38 MB per script SDK. Google says input/output processing stays local, but SDK performance/utilization metrics are transmitted. That is a meaningful privacy/dependency difference for Sliplet, so it is not the default recommendation. [iOS guide](https://developers.google.com/ml-kit/vision/text-recognition/v2/ios), [terms and privacy](https://developers.google.com/ml-kit/terms).

## Concrete next task proposed: P7-01, one-engine offline benchmark

This proposal is **not started**. Approval would authorize downloading pinned public model/runtime dependencies into an isolated evaluation setup and running local tests, not adding them to Sliplet or updating any phone/normal wallet. No receipt upload or hosted inference. No new chat or subagent required.

1. Pin model, dictionary, preprocessing, runtime and licenses before private scoring. Build an isolated iOS Simulator harness; verify a fictional fixture offline, original-coordinate mapping, orientation, full sign margins and model inputs. If deployment fails, report the concrete failure; do not switch models silently. Keep private images outside tracked sample fixtures.
2. Freeze two input conditions: original full image and the existing automatically derived total strip, without new manual crops or parameter search. Run baseline Vision and the new engine with the same inputs, twice in alternating order. Score all five existing originals. Ground truth stays solely in the evaluator.
3. Separate raw literal character/sign evidence, detection/grouping, and final fields from the unchanged parser. Retain observation provenance and transforms. Report any exact correct candidate as candidate availability only; report final automatic fields separately. Do not fuse outputs, arbitrate signs or change parser rules in this first comparison.
4. Report losses as well as gains across all previously correct fields. Include real negative/refund, multiple amount and misleading-label fictional cases. Measure Simulator load/inference time and memory plus actual model/package sizes. No phone or generalization claim.
5. **Promotion gate:** at least one newly correct final total (at least 4/5) with no loss of prior checked successes and no new unsupported amounts. A better raw transcription without a final-field gain is a diagnostic result only, requiring a separate interpretation proposal. An item-only gain is reported honestly but does not retroactively pass the total gate. If no gain, stop; no automatic engine sweep or integration.

This task asks whether a different reader changes the evidence, not whether enough parser exceptions can make five examples pass. If it succeeds, design a separately approved integration and conflict-resolution protocol. If it fails, retain the current app and choose explicitly between an assisted workflow and further research. No complete Phase 7 implementation sequence is approved by this recommendation.

## User contribution and verification

No repeated manual identification is needed. The five checked references and two checked Costco transcripts remain stored. One transcript omits an entire total observation; treat that omission as coverage missing, not evidence that the printed amount is absent. Ask only for narrow adjudication if a new result depends on unresolved identity or an unannotated field. More receipts are optional for development; a reserved unseen set is needed before general accuracy claims.

This assessment reverified frozen P5-06, P6-02 and P6-02B evidence. Independent P5-06 provenance checks still report five identical field/source sets, 237 literal source choices and 324 contained region observations. Production-source comparison is empty. No fresh OCR/test suite/device run was needed for this documentation-only decision. Current research was checked against primary sources on 2026-10-18; upstream main documentation can change, so a future experiment must pin actual revisions. Personal signing changes remain uncommitted.

Related: [P5-06](PHASE5_ACCEPTANCE.md), [P6-01](PHASE6_TOTAL_DIAGNOSIS.md), [P6-02](PHASE6_TOTAL_PROBE.md), [P6-02B](PHASE6_ANCHORED_TOTAL_PROBE.md), [earlier document-layout experiment](CAPTURE_LAYOUT_EVALUATION.md).
