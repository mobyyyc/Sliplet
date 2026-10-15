# P4-03 — Bounded adaptive reading

2026-10-15: engine implementation verified; automatic promotion rejected. Normal imports retain their existing single read. The internal evaluation opt-in is not a user setting, launch flag or automatic production feature.

## Decision

The second full-image language-correction read did not provide a safely additive improvement on the five exposed development purchases. It remains available as tested infrastructure for separately approved, explicit user assistance in P4-05. Do not silently replace an existing item description just because a private answer reference scores it better.

Frozen P4-02 observations replayed through the P4-04 parser explain the earlier apparent +1: four correction-on receipts preserve all interpreted fields but add nothing; the fifth changes an existing description rather than recovering an omitted purchase. Reduced warnings alone are not evidence of a better receipt.

## Implementation

A single job owns both requests and sticky cancellation. At most two full-image reads use the same language list, image orientation and original normalized coordinate system. No region transforms, cropping or cross-pass merging are introduced. The second read is eligible only for unresolved parsing, not the always-present source-review warning or reconciliation mismatch alone. It is skipped when the first read exceeds 1.2 seconds or the image exceeds 20 megapixels.

The retry has a 1.25-second acceptance deadline around its complete setup/work and a request-specific cooperative cancellation timer. Late successful results are discarded. Vision cancellation cannot guarantee wall-clock return by the deadline. User/session cancellation always propagates; ordinary retry failures/timeouts preserve the first result. Existing active-session/job-identity checks prevent obsolete imports from publishing into current state.

Selection requires paired original-space observations, unchanged numeric/sign/currency syntax, preservation of known summary fields, and the complete baseline line multiset including metadata and mapped source IDs. A concrete additional field is required. Explicit currency conflicts cannot disappear automatically; equally priced items cannot swap source positions. Neither private references, confidence, warning counts nor matching totals drive selection.

The selected pass alone supplies raw OCR, parser output, fields and source references. Separate optional evidence retains both complete reads, configuration and outcome inside the encrypted record. Legacy records decode without it. Unique IDs, valid confidence, pass/outcome consistency, per-observation text and per-pass count/byte limits are enforced; the existing total record-size limit also applies. The evidence survives draft reopen and password-protected backup/merge. No new correction UI or edits to saved user receipts occur in this task.

## Actual import results

Dedicated iPhone 15 Pro Simulator, five exposed originals twice; no semantic references enter recognition. Nine attempts completed the second read and retained baseline; one skipped the retry because its first read exceeded budget. All ten imports succeeded. Five selected-output repeat pairs and five encrypted draft round trips passed. Four pairs had candidates on both passes and their candidate text/geometry/confidence were stable. Retained baseline observations match the preceding accepted P4-04 imports.

| Measure | P4-04 | P4-03 opt-in |
|---|---:|---:|
| Parser exact purchases | 53/66 | 53/66 |
| Structured draft exact purchase pairs | 43/66 | 43/66 |
| Correct totals | 3/5 | 3/5 |
| Fully correct receipts | 0/5 | 0/5 |
| Repeat import-to-review median | 777 ms | 1,607 ms |

First-pass median: 1,499 ms; repeat maximum: 1,739 ms. These are separate local Simulator runs, not controlled phone-performance measurements. The extra reading cost exceeds the earlier proposed approximately 1.14-second median budget without a safely selectable gain. Automatic enablement therefore fails both benefit and latency gates. No measured losses of correct fields, source currency or previously correct lines; no new unmatched outputs. Five development purchases, zero held-out purchases; accuracy remains insufficient.

## Verification

Final signed hosted run: 118 methods executed, 117 passed, one hardware-only skip, zero failures. Twenty-one new fictional tests exercise default-off behavior, positive additional-field selection, budgets, failure and timeout fallback, cancellation before/between/during reads, late successful retry rejection, source swaps, signs, currency conflicts, malformed evidence, legacy decoding and encrypted backup/restore. Existing parser, currency, workflow, persistence and backup tests also pass. The hosted private method exercises the real Files import entry point with explicit adaptive opt-in.

An early run used unfinished test fixtures with shared cross-pass IDs and no retry-triggering uncertainty; those fixtures failed and were corrected to model real independent reads. The final suite was rebuilt from finalized sources. No physical-phone run or new UI walkthrough was performed; deterministic cancellation tests validate the engine, while existing workflow tests cover publication/session behavior. Real hardware timing and interrupted device Vision calls remain unmeasured.

All 4,187 preexisting private/signing files remain byte-identical. The normal Simulator wallet and phone were not updated. Accepted private evidence: `private-receipts/evaluation/p4-03-final`. [Safe aggregates](evidence/p4-03/aggregate.json), [validation](evidence/p4-03/validation.json), [reproduction](../evaluation/receipt-adaptive/README.md).

## Next proposed milestone

P4-05: explicit targeted help in review. Let the user choose a difficult region or compare an alternative reading with the original, then Apply or Cancel. Design source linking for newly read evidence before allowing any candidate to become a saved correction. Preserve existing edits and review gates; do not silently replace whole receipts or ship blanket crops. This task requires separate approval.
