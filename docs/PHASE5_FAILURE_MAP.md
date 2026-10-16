# P5-01 — Recognition failure map

2026-10-16 · Diagnostic work only · Production recognition unchanged from `71d4ded`.

## Scope and evidence

The user approved P5-01 after the Phase 5 proposal. This task reuses frozen P4-06 actual-app captures, checked references for five purchases, and the two user-verified Costco text replays. No fresh OCR, Simulator imports, phone tests, reference edits, or model changes were performed. Five exposed purchases, zero held-out purchases. Existing references are enough to proceed; no wholesale relabeling is required.

The P4-06 evidence verifier passes, including historical source/reference/image checks. The new reproducible map covers every non-correct strict field outcome, plus every unmatched output index, in a local private ledger. Public evidence contains aggregates only. Source-linked text containment is a diagnostic clue, not verified identity; ambiguous cases remain explicitly unresolved.

## Findings

| Category | Evidence | Interpretation / next action |
|---|---|---|
| Merchant and date | Both 5/5 | No demonstrated failure here. Preserve these results; merchant directory work is coverage expansion. |
| Subtotal | 4/4 verified; one unreviewed | Do not score the unreviewed subtotal as missing or correct. |
| Total | 3/5; two missing in parser output | Three total-label rows across those receipts: two lack a two-decimal amount in the interpreted row, one contains a decimal amount. One `negative_summary_check_source` issue is present. Diagnose label/amount association and sign evidence; do not strip signs to force a total. |
| Summary incorrectly made a purchase | Ten keyword-containing interpreted rows, all recognized by the anchored label pattern; zero supply a purchase row | User-reported symptom is not reproduced by these captures. Code still has a risk where a priced, unrecognized summary falls through as a purchase. Add fictional boundary cases before repair; do not claim this is the cause of the two measured missing totals. |
| Unpaired reference lines | 15 lines yield 45 missing kind/description/amount outcomes | These are identity/matching proxies, not 15 proven OCR omissions. Eight names appear within interpreted rows. Seven of those eight have no source-linked parsed line; five link to unpriced-row issues and two to unpaired-amount issues. The remaining one has a linked output with a different description. Seven other names are not found by exact normalized containment: OCR, fragmentation, and reference/description differences remain unresolved. |
| Wrong amount | One uniquely paired field discrepancy | The expected amount is not found by the existing diagnostic money matcher in that parsed line's linked OCR observations. OCR versus incorrect source association remains unresolved; this does not justify changing the amount. |
| Repeated descriptions | Ten ambiguous reference lines; 80 field outcomes | No verified location anchors to distinguish them safely. Duplicate-group counts match. Do not use price as a matching tie-break or report all 80 fields as recognition errors. |
| Incomplete annotations | 293 unscorable outcomes, plus unchecked fields hidden within the ambiguous groups | Full quantity, SKU, unit, unit-price, tax-marker, rate and currency accuracy is not established. The reference inventory contains 343 unreviewed fields overall. Only request narrowly scoped checks when needed for an acceptance claim. |
| Conversion and storage | 43 typed line amounts absent before the explicit CAD default, all 43 restored correctly in the draft; five save/reload captures equal | Currency uncertainty is intentionally preserved. It is not loss of 43 prices in the user-visible draft. No demonstrated storage loss in these captures. |

Do not add the categories as if they were independent erroneous items: field outcomes, row proxies, and unmatched outputs use different units. There are 17 unmatched structured output proxies, of which ten belong to ambiguous duplicate pools and seven are outside those pools. These are not proven invented lines.

Strict totals reproduce P4-06: 43/66 exact purchase pairs, 47 missing field outcomes, one wrong outcome, 80 ambiguous identity outcomes and 293 unscorable outcomes. The legacy amount-preferred duplicate matcher reports 53/66; it remains a separate historical measure. Neither is OCR text accuracy.

## Checked-text evidence

The two previously verified Costco text replays still produce 33/37 exact purchases under legacy scoring and one of two correct totals. This confirms that replacing OCR alone cannot solve all failures. It does not establish that every row-level failure on all stores is parser-only. Geometry and reference identity can still matter after literal text correction.

## Code risks versus observed failures

- `ReceiptParser.rows` joins observations using vertical proximity and then concatenates left-to-right. If any geometry is absent it falls back to input order. Incorrect association can change a label's position or combine unrelated evidence.
- `interpretationRows` joins detached description/price pairs only for a recognized retailer, using strict mutual-nearest geometry. Numeric-leading descriptions are excluded. SKU-leading or fragmented descriptions therefore need careful treatment, not simply looser distance thresholds.
- Summary recognition is anchored to the start of normalized text; normalization strips only a small set of leading decorations. Unrecognized priced text can become a purchase.
- A recognized summary with a money token sets the finished-items flag before validating the summary amount. A false summary can suppress later purchases. Treat `TOTAL CEREAL` as a fictional negative case, not an observed private failure.
- Multiple candidates, unsupported signs and malformed amounts deliberately remain unresolved. Preserve these safety properties while improving source interpretation.
- Merchant matching already canonicalizes the three supported stores and scans only the header before the first money-looking row. Broader aliases may improve coverage but cannot explain the current 5/5 successes away.

## Acceptance fixtures for the next approved task

P5-02 should begin with fictional examples for: separated label and amount; decorative prefixes; `SUB TOTAL`, `GRAND TOTAL` and French labels; `TOTAL ITEMS`, `TOTAL SAVINGS`, balance/tender/change; a product containing the word total; multiple competing totals; decimal commas and legitimate negative/refund evidence; subtotal before additional legitimate sections; missing geometry; and labels sharing a row with unrelated text. Label spelling normalization must never mutate financial digits or signs.

Real-receipt gate: rerun the same five originals and checked transcripts through the actual app after implementation. Compare automatic totals and purchase identities, retain all currently correct fields, introduce no unsupported money, and report unresolved cases rather than forcing completeness. Candidate labels or reference values must never enter the production recognizer. Acceptance is development-set evidence only.

For P5-03, focus on the seven unpaired-name clues without output, the one differently named linked output, and the seven unresolved-name cases. Verify source identity before attributing a specific row to grouping or classification. Only ask the user for specific ambiguous regions if the repair or score depends on them. Stored references remain immutable.

## Verification

- Historical P4-06 verifier: passed.
- New aggregate and private ledger deterministic reproduction: passed.
- Existing scorer regression suite: 18 passed.
- Every missing/wrong/unscorable/ambiguous strict field outcome is represented once in the ledger; unmatched outputs are recorded separately.
- No Swift, project, image, reference, or previous evaluation changes. Personal signing diff preserved. No performance or phone claim from this diagnostic task.

[Aggregate evidence](evidence/p5-01/aggregate.json) · [Reproduction](../evaluation/receipt-diagnosis/README.md) · [Phase 5 plan](PHASE5_RECOGNITION.md)
