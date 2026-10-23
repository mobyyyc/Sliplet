# Phase 7 final acceptance — P7-09

Status: work completed; recognition acceptance **not met**. Do not describe Phase 7 as having solved receipt accuracy. No production change or deployment is included in this closing audit.

## Verified result

Reused P7-08's ten fresh production import captures (two independent passes over the same five originals) after verifying current source/reference hashes, prior/current parser provenance and worker hashes. Replayed both parsers, rescored persisted drafts and checked original/evidence preservation, save/reopen equality and independent review gates. Both passes have identical aggregate outcomes.

| Measure | Result | Acceptance |
|---|---:|---|
| Exact purchase kind, description and printed amount | 57/65 (87.7%) | Failed; requires 59/65 (90.8%) |
| Checked totals | 3/5 | Failed; two missing |
| Checked subtotals | 4/4 | Passed; fifth unscorable |
| Merchant and date | 5/5 each | Passed on this corpus |
| Checked adjustment kind, description and amount | 4/8 | Incomplete; four unresolved discounts |
| Previously correct fields lost against frozen baseline | 0 | No observed regression |
| Import, review and persistence verification | 10 import/save/reopen cycles; 28 passing native/UI methods | Passed in P7-08 |

The four exact adjustments comprise two discounts and two tax rows. Four other checked discounts remain unpaired, and one unrelated unmatched-output proxy remains. A proxy is not proof of fabrication; nevertheless, the stronger complete adjustment/source-accounting gate cannot be marked passed. Adjustment parent links and item tax semantics remain unverified. Currency is unscorable on these references; the app's visible default is not printed-currency recognition.

Only five exposed receipts, zero held-out purchases. No all-fields 90% claim, unseen-receipt accuracy claim, phone performance claim or measured human correction-time claim is supported.

## Actual gain versus measurement changes

Historical 45/66 became 55/66 after human source anchors resolved repeated-name identities. A submitted description amendment and purchase-to-discount reference correction then produced 56/65. Those changes corrected measurement/reference semantics, not recognition.

Against the same frozen corrected references, P7-06/P7-08 measured **56/65 → 57/65**. Two weighted purchases were recovered, but only one added an exact description/amount pair. The other retains printed suffix text absent from its expected description. Earlier Phase 7 count-extension improvements are documented in their original milestones; this audit does not invent a new whole-phase comparison across changing references.

P7-07's bounded OCR alternatives yielded no safe gain and were not shipped. P7-08 verified integration; P7-09 verifies final acceptance. Neither is an additional accuracy improvement.

## Remaining errors and limits

- **Seven purchase description mismatches:** includes printed suffix/reference-boundary differences as well as text-reading differences. Keep the strict frozen score and preserve printed text. Do not delete suffixes or silently relabel answers to reach 90%.
- **One wrong purchase amount:** the checked magnitude was absent from nearby retained OCR. Association changes cannot safely supply missing digits.
- **Two missing totals:** prior diagnostics identified omitted digits and a spurious sign. Payment substitution, sign removal merely to reconcile, or calculating a missing total would hide failure.
- **Four unresolved discounts:** role/sign evidence and association are incomplete. A numeric adjacent row alone does not establish a safe general discount or parent-link rule.

P7-07 requested alternatives but Vision returned only one candidate per observation. Its 80 targeted rereads yielded zero recoveries; 14 hypothetical substitutions regressed correct pairs. Automatically chosen regions covered only three of eight failing purchase anchors. This rules out promoting that specific experiment, not every OCR approach or a universal accuracy ceiling.

No complete manually verified transcript exists; the supplied literal rows support scoped diagnostics only. No further full manual review was needed for this closure. Any future clarification should target a specific unresolved printed-text or label-boundary question.

## Safety, generalization and performance evidence

The promoted weighted-layout rule uses relative geometry, explicit matching units and a source-backed printed extension; arithmetic only corroborates it. It preserves source order, full printed descriptions and unused source identities. It does not calculate a missing amount. The rule remains limited to recognized merchant formats.

P7-06 retained 31 fictional checks and 46 passing native regression tests. These cover changed names/prices/units, repeated purchases, geometry transforms and negative association/summary/footer cases. They support the bounded rule, not every proposed Phase 7 hypothesis or arbitrary receipt layout. P7-08 preserved originals, raw OCR, draft fields and review gates with no previously correct-field loss. Broader financial completeness still fails.

P7-08 observed median import-to-review time about 1.13 seconds, maximum about 1.97 seconds, and maximum main-actor polling gap about 24 ms in its isolated Simulator lab. These are not frame-rate measurements, paired prior-app timing, human review time or phone latency. No claim of zero lag is made.

## Decision and proposed next step

Close Phase 7 with a partial result. Keep the measured weighted-item improvement and reject the unsuccessful additional OCR reads. Do not extend the phase with repeated identical experiments.

If the user approves further planning, design a separate accuracy phase around three explicit workstreams: resolve only demonstrated description/reference-contract ambiguities without rewriting the frozen benchmark; test a distinct local text-recovery hypothesis for missing/wrong digits and names; and evaluate discount role/sign classification with negative examples. Require an isolated measurable gain before integration. Any new model/adapter needs its own hypothesis and approval; reaching 90% is not guaranteed. Report purchase, summary and discount results separately. No implementation, model download, new receipt collection or phone installation is authorized by this proposal.

## Reproduction

Run `python3 evaluation/receipt-phase7-acceptance/check.py` with retained private evidence and the P7-08 before/after workers. It verifies input hashes, recomputes both passes, and checks the public aggregate and private ledger against retained evidence. Initial `write` mode refuses to overwrite the private audit directory. Source text, labels, coordinates, identifiers and hashes stay in ignored private storage. Public output contains aggregate counters only.

Evidence: `docs/evidence/p7-09/aggregate.json`; private details: `private-receipts/evaluation/p7-09-final`. Prior methodology: `PHASE7_FOCUSED_REVIEW.md`, `PHASE7_WEIGHT_ASSOCIATION.md`, `PHASE7_OCR_ALTERNATIVES.md`, `PHASE7_WORKFLOW_VERIFICATION.md`.
