# P5-02 — Safer summary labels and boundaries

2026-10-17. Approved in Main. Parser version `p5-02-summary-0.5.0`. This is bounded recognition hardening, not an accuracy-approved release or completion of Phase 5.

## Behavior

- Complete labels distinguish totals from products such as fictional `TOTAL CEREAL`. Added `TOTAL DUE`, `AMOUNT DUE`, `TOTAL À PAYER`/`TOTAL A PAYER`, `TOTAL TTC`, and limited leading decoration; existing subtotal/French variants remain supported.
- Words before an amount can identify a product; suspicious text after an otherwise complete total label keeps the summary unresolved instead of making it a purchase. Bars, parentheses, separated signs, competing amounts and stray digits do not manufacture money.
- A subtotal no longer automatically ends purchases: another department may follow. A complete final-total label with an amount token still establishes the footer boundary even when its amount needs review. Recognized payment rows also protect the footer. Final-total label recognition is separate from amount acceptance.
- Explicit summary labels can pair with a unique nearby standalone amount, including an explicit currency, without requiring a known merchant. The summary-only vertical window is bounded at 1.75 smaller text heights, with rightward placement, no intervening row and mutual-nearest uniqueness. Ordinary product pairing retains its previous distance and retailer requirements. Unknown-store product labels compete for a price even though they are not automatically paired, preventing summaries from stealing their evidence.
- Preserve source IDs, original OCR, printed signs, currency uncertainty and independent review/Finish gates. No cloud, new model, OCR option change, UI change, or broader purchase assembly work.

## Evidence and limits

The new fictional cases exposed failures in the old parser. The first real-receipt candidate introduced one unmatched footer output after an unresolved final total; that candidate was rejected. The boundary was corrected and checked again. A final code review added the unknown-store competing-product safeguard.

The final real-receipt run uses the same five checked purchases and two saved Costco transcripts. All ten imports succeeded, five repeat pairs were stable, and five draft saves/reopens preserved fields and source membership. Final draft fields independently equal P4-06 on all five receipts. Legacy exact purchases remain 53/66; strict pairs remain 43/66; subtotals remain 4/4 and totals 3/5. No lost correct line, new unmatched output or new wrong summary is measured. 91 focused native tests (including 13 new summary cases), 18 scorer tests and both private hosted methods passed. Final first/repeat import medians were 764/762 ms. Results and validation are recorded in the accompanying aggregate evidence. These are five exposed purchases with zero held-out purchases. Repeated raw readings remain stable; this task does not recover the two missing automatic totals: one lacks an exact total amount in the saved OCR and the other has an unresolved signed value. No signs are removed or values inferred to make totals balance. Checked-text totals remain one of two; purchase assembly remains P5-03 work.

Do not describe unchanged scores as an accuracy gain. The demonstrated gain is correct handling of the fictional label/boundary cases and preservation of existing real-receipt results. The phase goal of improved complete automatic recognition is still unmet. Existing manual checks are retained; no new user labeling or human assistance was measured. Simulator timings are hosted Debug handler-to-review timings, not phone latency or controlled cold-cache measurements.

The initial staging attempt encountered a shut-down dedicated Simulator before receipt testing. It was retained separately; subsequent runs used an explicitly booted device and new run folders. Earlier candidates remain archived privately. Personal signing changes are excluded from the commit.

[Aggregate evidence](evidence/p5-02/aggregate.json) · [Validation](evidence/p5-02/validation.json) · [Reproduction](../evaluation/receipt-summary/README.md)
