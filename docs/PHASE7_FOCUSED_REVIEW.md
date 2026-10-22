# P7-05 focused reference review

Status: P7-05 complete as a bounded evidence audit. Frozen references and unchanged-parser replays are verified. Recognition code is unchanged.

The existing five receipts contain 21 unresolved purchase cases and two total cases. The local review page groups these 23 cases by receipt, preserves all earlier references, and starts every confirmation unchecked. Duplicate-name cases hide the expected amount so identity must be established from the original source region.

Private review: `private-receipts/evaluation/p7-05-review/review.html`.
Expected export: `sliplet-p705-checked.json`.

Validation performed: fictional browser checks for confirmation gating, source marking, export, edit invalidation, progress persistence and no network requests; private page load and 23-case count; eight fictional structural validator checks. No private receipt contents are included in this document.

After the checked export arrives, validate its identity and source regions, review amendments, preserve a versioned reference, and rerun the unchanged recognizer baseline. Separate reference/scoring changes from actual recognition gains. Then build the verified-text diagnostic and remaining error map before proposing P7-06. Do not claim P7-05 complete or 90% recognition from this preparation.

## Human review audit

The received export contains 23 unique expected cases, matching the preparation identity and all retained input hashes. There are no additional two cases in this export. All 23 contain valid amounts, source regions and notes; all 21 purchase cases contain descriptions. Three cases have literal text rows and checked boxes; twenty have no extra rows and unchecked boxes. The user explicitly stated that all cases were reviewed and the tool prevented confirmation for items without following lines. Preserve the raw export and checkbox states; do not pretend the original file was a complete checked export.

The preparation tool incorrectly required at least one literal text row. Extra rows are now optional, while any supplied row must still have text and a marked source area. This does not make the three supplied transcripts a complete-text oracle.

Diagnostic source anchors resolve ten duplicate identities with non-overlapping marked regions. Both retained app-import passes score 55/66 exact purchase pairs (83.3%) against otherwise unchanged reference fields, versus historical 45/66. This is a measurement correction, not a recognition improvement and not a fresh OCR run.

Remaining diagnostic cases: seven description mismatches (six differ from the submitted description; one agrees with the amended human description), one wrong amount, two missing weight/rate purchases, and one missing purchase that the user identifies as a discount. There are no submitted amount changes. One description was amended. The two total regions retain their earlier checked amounts.

Do not derive taxability from department names or a general merchant assumption. User comments about tax status must be distinguished from verified printed markers; a discount's tax treatment cannot be finalized from proximity alone.

## Prioritized next work

1. Finalize versioned references: apply the explicit description amendment, reconcile the discount's kind and parent association, preserve each repeated purchase as a separate source occurrence. Report denominator changes separately; the old 66 purchase denominator may contain one discount. Keep original labels available.
2. Build a scoped verified-text diagnostic for the two weight/rate examples and supplied discount context. Mark absent literal transcripts as unavailable rather than fabricate them from expected values. Separate parser failure from text that the recognizer never supplied.
3. P7-06: recover weight/rate items using their printed extensions; fix source-backed description boundaries and amount association; classify and link discounts without inventing purchases or collapsing repeated items. Require measurable gain on identical references and negative fixtures before integration.
4. P7-07: target remaining OCR description and total failures with bounded alternate candidates and region reads. Preserve signs and original text. No amount chosen just to reconcile a receipt.
5. P7-08/P7-09: integrate only winning candidates and rerun actual imports. Require at least 90% exact purchase pairs on the finalized denominator, plus separate totals/subtotals and no-regression gates. Report reference gains separately from automatic-recognition gains; zero held-out receipts.

Private evidence is retained under `private-receipts/evaluation/p7-05-human-audit`. Production changes are not part of this audit. The completion evidence below supersedes this intermediate status.

## Final P7-05 evidence

The frozen private `p7-05-final/reference-v3.json` preserves every original line and amount, adds reviewed source anchors, changes one description as submitted by the user and changes one purchase to a discount. Discount parent identity and tax semantics remain unverified; the user's note is retained without inventing a link. The original reference and raw export remain intact.

Rebuilt the unchanged production parser and replayed all five receipts from each of the two retained native import passes. All ten outputs match retained draft fields after excluding generated item IDs. Both passes score **56/65 exact purchase pairs (86.2%)**. The acceptance threshold is **59/65 (90.8%)**, requiring three actual recoveries. Historical metrics remain 45/66 and source-anchor-only 55/66. None of this milestone's score change is an algorithm improvement.

Merchant/date: 5/5 each. Subtotal: 4/4 verified, one unscorable. Total: 3/5, two missing. One unrelated unmatched output proxy remains; this is not automatically a fabricated item. Nine purchase failures remain: six description errors, one wrong amount and two missing weighted purchases. The discount is evaluated separately.

### Diagnostic matrix

| Failure family | Evidence | Next experiment |
|---|---|---|
| Two missing weighted purchases | Names are present; replacing the supplied follow-up rows still does not produce the purchases | P7-06 role-aware grouping of description, quantity/rate and printed extension; test missing and ambiguous extension negatives |
| Description boundaries | Some original names are present but outputs differ; corrected literal discount context does not fix the affected description | P7-06 inspect grouped source spans and exclude section/adjustment metadata without deleting product suffixes |
| Description text absent from observations | Several remaining names are not exactly available in a single OCR observation; this alone cannot distinguish misreading from fragmentation | Trace fragments first; P7-07 only where absent/incorrect text is demonstrated |
| Wrong amount | Human amount unchanged; description correct | Trace source amount association in P7-06; route to P7-07 if the underlying digits are wrong |
| Discount | Human confirms negative adjustment rather than purchase | P7-06 classify and preserve adjustment; establish parent only with sufficient source evidence |
| Missing totals | Prior evidence identifies omitted amount and spurious sign; reviewed amounts remain unchanged | P7-07 bounded candidate/region experiment; never fill using payment or reconciliation |

The three supplied text rows support **scoped substitution diagnostics only**, not a complete-text oracle. Each substitution replaced two overlapping observations, so lack of improvement does not establish a universal parser ceiling or exclude every OCR contribution. No full-transcript rewrite or new user review is required to start the next experiment. Preserve uncertainty explicitly and request a targeted clarification only if a specific unresolved fact blocks progress.

Verification: ten unchanged-parser replays; repeated 56/65 scoring; input/reference hash checks; exactly two semantic reference amendments; no changed monetary values; optional-row export validation and invalid-export rejection. No fresh Vision run, phone test or production modification in this milestone. Zero held-out receipts.

Reproduce with the unchanged ParseWorker build described in `PHASE7_REPRODUCTION.md`, output `/tmp/sliplet-p705-parse`. `finalize.py` requires a new private output directory and refuses overwrite. `verify-final.py` checks the retained final artifacts. All raw evidence stays private; only aggregate results are committed.

Next: request P7-06 approval for general structural interpretation and source-backed associations, starting with weighted purchases. Commit title: `test: freeze reviewed phase 7 accuracy baseline`.
