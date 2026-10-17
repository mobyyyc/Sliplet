# P5-06 — Phase 5 development evaluation

2026-10-17. Candidate frozen at `d6b871d` (P5-05). This task changes evaluation and documentation only. The five previously checked receipts and two checked Costco transcripts are reused; no new manual labeling is required. There are zero held-out purchases.

**Decision: the bounded Phase 5 implementation/evaluation is complete, but the accuracy acceptance goal is not met.** Do not call this an accuracy-approved release. The app still needs manual review for everyday receipt correctness.

## Automatic results

| Measure | Before Phase 5 | Final Phase 5 |
|---|---:|---:|
| Strict exact description/amount purchase pairs | 43/66 | 43/66 |
| Legacy parser exact purchase recovery | 53/66 | 53/66 |
| Merchant / date | 5/5 each | 5/5 each |
| Checked printed subtotals | 4/4 | 4/4 |
| Checked totals | 3/5 | 3/5 |
| Fully correct receipts | 0/5 | 0/5 |
| Existing purchase lines available for rereading | 61 | 62 |

The two exact-purchase metrics use different matching rules; they are not interchangeable. The additional Phase 5 source-backed row still has unresolved description text, so it is not counted as an exact-pair improvement. Four receipts retain the same strict score counts as before Phase 5; the fifth changes its unmatched-output inventory. All five final drafts exactly match P5-05 in values and source membership.

Ten actual-app imports succeeded, five repeat pairs were stable, and five encrypted draft save/reopen checks preserved their evidence. First/repeat import medians were approximately 1,146/1,096 ms in this Debug Simulator run. Earlier P4-06 medians were 765/767 ms, but these uncontrolled separate runs do not isolate a performance regression; device load and cache state were not controlled. No phone-latency claim is made.

Strict scoring retains 47 missing, one wrong, 293 unscorable and 80 ambiguous-identity field outcomes. These are field outcomes, not item counts. There are 18 unmatched-output proxies; these are not all fabricated purchases. Prior quantity/SKU/unit/tax-marker coverage is incomplete, so accuracy for all requested fields is not established. The two corrected Costco text replays still recover 33/37 legacy purchases and one of two totals: interpretation remains a bottleneck even when text is manually corrected.

## Assistance, measured separately

All 62 suggested-region amount rereads succeeded. Of the 66 reference purchases, 44 could be paired confidently, and 22 remained unpaired or ambiguous. Correct candidates were available for 43 of the 44 paired purchases; those 43 already had correct amounts. The one paired missing/incorrect amount was not recovered. **Additional amount recoveries: zero.** Thirty-nine paired cases also offered other amounts, so finding the correct amount somewhere in a menu is not automatic correction.

The median region read was approximately 370 ms and maximum 736 ms. The probe uses the editor's suggested region for each existing purchase; it does not apply candidates, draw a human-selected region, fix descriptions, add missing purchases or confirm review. Human correction time and complete-after-assistance accuracy remain unmeasured. Previously checked annotations are not counted as a human app-review session.

Independent verification confirms 237 candidate literal ranges match retained OCR text and 324 observation boxes remain inside their selected regions. P5-05 already verified all 81 actionable warnings retain their evidence in guidance. That is source coverage, not proof that the warnings are sufficient or the suggested corrections are correct.

## What Phase 5 achieved

- Conservative summary boundaries and label handling, covered by misleading-label fixtures.
- Bounded purchase assembly that retains an extra source-backed candidate without inventing its unresolved description.
- Local merchant aliases and conflicting-header handling while preserving all five prior merchants.
- Focused correction routing with original evidence, line-specific rereading, explicit Apply/Cancel and currency-sensitive check invalidation.

These are safety and coverage improvements. They did not produce a measured exact-purchase or total-accuracy gain on this development set.

## Verification and reproducibility

87 focused native tests and 18 scorer tests pass. Three private hosted methods pass for imports, checked text and dependent region reads. Five fictional UI methods pass: dark summary correction, nested reread Cancel/Apply, unassigned-row selection/Cancel, full import/review/split/share/search/original/relaunch flow, and Files backup export/duplicate restore preview. All recognition remains on-device, without Foundation Models or cloud services. The source/reference manifest and saved captures verify successfully. Normal Simulator wallets, physical-phone installations and personal signing settings are not changed.

Frozen private run: `private-receipts/evaluation/p5-06-final`. [Reproduction](../evaluation/receipt-phase5/README.md) · [Aggregate](evidence/p5-06/aggregate.json) · [Validation](evidence/p5-06/validation.json). Raw receipts, OCR, identifiers, labels and source coordinates remain private.

## Recommended next decision

Do not spend another phase broadly expanding parser rules without a demonstrated failure and a measurable target. The next proposal should select a small number of unresolved cases from the existing failure ledger, trace exact source-to-field decisions, and prototype a better correction path or narrowly justified interpretation fix. Prioritize the two missing/wrong totals and ambiguous purchase descriptions. A different crop or richer document model is an experiment, not an assumed solution; promote it only if paired evaluation improves correctness without new unsupported values.

A human review trial would measure real correction effort separately. If a specific original cannot be adjudicated from existing checked references, ask only about that unresolved field. New receipts are optional for continued development, but separately held-out purchases are necessary before claiming general accuracy. Further implementation requires a new approved task.
