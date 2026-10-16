# P4-06 — Real-receipt development evaluation

2026-10-16. Candidate frozen at P4-05 commit `97827ee`; evaluation-only additions do not change production recognition. The user explicitly chose the five previous checked receipts. Zero held-out purchases. The accuracy acceptance gate is **not met**.

## Automatic recognition

Ten actual-app Files imports (five originals twice) succeeded. All five repeat pairs are stable; five encrypted draft saves/reloads preserve fields, review input, original bytes and OCR. Independently comparing full semantic captures against accepted P4-04 found identical raw observations, parser output, structured fields, review drafts and source-row membership on all five purchases. No automatic recognition improvement or regression was observed.

| Measure | Result |
|---|---:|
| Legacy parser exact purchase recovery | 53/66 (80.3%) |
| Strict structured description/amount purchase pairs | 43/66 (65.2%) |
| Merchant / date | 5/5 each |
| Printed subtotal / total | 4/4 and 3/5 |
| Fully correct receipts | 0/5 |
| First-import median | 765 ms |
| Repeat-import median / maximum | 767 / 829 ms |

Legacy matching and strict structured pairing are different measurements, not interchangeable accuracy claims. The strict scorer leaves repeated/ambiguous identities unresolved; it never uses matching amounts to disambiguate. Expanded attributes retain incomplete labels (including 55 populated SKUs and six tax markers), so complete field accuracy is not established. The draft's visible CAD default is user context in three receipts, not OCR evidence of printed currency.

| Store | Purchases | Legacy exact purchases | Correct totals |
|---|---:|---:|---:|
| Costco | 2 | 33/37 | 0/2 |
| No Frills | 2 | 18/26 | 2/2 |
| T&T | 1 | 2/3 | 1/1 |

Across all line kinds, the legacy scorer reports 15 omission proxies and seven unmatched-output proxies. These include interpretation/name problems and are not all proven OCR omissions or fabricated purchases. The stricter inventory reports 47 missing field outcomes, one wrong field outcome, 293 unscorable field outcomes and 80 ambiguous-identity field outcomes; these are field counts, not receipt or item counts. All five receipts fail completeness. The two previously user-checked Costco transcripts still recover 33/37 purchases and only one of two totals, supporting interpretation as a continuing bottleneck even with corrected text.

## Targeted rereading

The real-photo probe made **61 suggested-region reads**, one for every existing purchase line. All returned successfully. Median region duration was **361 ms**, maximum **808 ms**. No candidate was applied or treated as human-reviewed.

Of 66 reference purchases, 44 could be paired confidently for amount comparison; 22 were unpaired/ambiguous and cannot support a recovery claim. Correct amounts were available for 43 of those 44. Those 43 already had correct amounts. The one paired missing/incorrect amount was not recovered: **zero additional amount recoveries in this probe**. Thirty-nine paired cases also offered other amounts, reinforcing the need for explicit selection and source comparison.

| Store | Region attempts | Paired purchases | Correct candidate available | Additional recovery |
|---|---:|---:|---:|---:|
| Costco | 37 | 24 | 23 | 0 |
| No Frills | 22 | 18 | 18 | 0 |
| T&T | 2 | 2 | 2 | 0 |

This is a suggested-region existing-amount probe. It does not establish the result of a user drawing a different region, correcting descriptions, adding omitted purchases or completing the whole receipt. Human choices, review seconds and complete-after-assistance counts remain unmeasured. Previous reference annotation is not counted as everyday review effort.

## Verification and limits

Actual-app recognition and native regional Vision ran on Xcode 27.1 / iOS 27.0, iPhone 15 Pro Simulator. Handler-to-review timings include polling in a hosted Debug process; first imports are not controlled cold-cache measurements. Peak memory and phone latency were not measured. Sources, original images and references were frozen and verified; semantic labels never entered recognition. Every region attempt and both imports per purchase remain in the private run.

The initial combined test command scheduled the dependent probe before baseline captures and failed that setup step. The baseline and checked-transcript tests passed; a separate subsequent probe passed after inputs existed. No failed receipt recognition attempt is omitted. Public evidence contains aggregates only. All five focused fictional UI checks pass: Files backup export/duplicate restore preview, two reread flows, split assignment/finalize/share/restart/edit, and import/review/save/split/share/search/original/restart. The last flow initially used a removed custom Back identifier; the test was updated to the existing native Back button and reran successfully. All 18 scorer regressions pass. Three private hosted methods pass after the ordering correction. All 4,211 preexisting private/signing files remain byte-identical. See [validation](evidence/p4-06/validation.json).

## Decision and next work

Keep automatic imports single-pass. P4-05 remains optional explicit correction assistance; this evaluation does not prove it improves these receipts. The 95% purchase-recovery target, fully correct receipt goal and independent-validation gate remain unmet. Do not label this an accuracy-approved v0.4 release or a completed human usability evaluation.

The next proposed work should focus on source-backed interpretation and review effort: diagnose the remaining Costco totals and missing/fragmented purchase rows, preserve ambiguous values, and improve candidate presentation without guessing from totals. Any changes need a separately approved task and a fresh frozen evaluation. Existing five receipts remain sufficient for development; no new-photo requirement is imposed by this result. Unseen-purchase claims remain unavailable until a separately reserved set exists.

[Reproduction procedure](../evaluation/receipt-acceptance/README.md) · [Safe results](evidence/p4-06/aggregate.json)
