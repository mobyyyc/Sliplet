# P6-01 — Two-total diagnosis

2026-10-17. Approved in Main; completed as a read-only investigation. No recognition, parser, UI, reference, or installed-app changes. P6-02 is proposed and requires separate approval.

## What is now established

Both original images visibly print their total amount as light digits inside a dark horizontal bar. The labels are ordinary dark text outside the bar. The originals remain legible enough for this inspection; existing user-checked numeric references agree with the visible digits. This is analyst visual inspection, not a new user annotation or a claim that OCR can reliably recover the text.

| Case | Original → saved OCR | Grouping → parser → draft | Finding |
|---|---|---|---|
| A | The total is visibly present in the dark bar, but its amount is absent from saved raw observations. The total label is retained. The expected digit sequence is absent from the entire saved OCR, not merely its total row. | Grouped/interpreted total row contains the label alone. No valid amount reaches the summary parser. Parsed total and draft total stay unresolved; persistence preserves the same fields. | First confirmed failure is OCR omission, before row association or parsing. Broadening total keywords cannot recover absent digits. |
| B | OCR retains the total digits but reads a decimal comma and a trailing minus. Visual inspection shows no printed trailing minus; the existing checked transcript removes exactly that final minus from the total amount fragment. | Grouping correctly links label and amount. The monetary tokenizer accepts the comma and trailing-sign syntax as negative; the explicit negative-comma-summary guard leaves the total unresolved. The checked text with the minus removed yields the correct total with the current parser. | First confirmed failure is incorrect OCR sign evidence. The parser's refusal is a safety response, not evidence that negative signs should be ignored. |

For B, another exact amount appears later in the payment section. It is not a safe generic substitute for the receipt total: tender, split payments, change and refunds can differ. Its presence does not justify copying it or selecting a number by reconciliation.

## Correction to the earlier interpretation

Case A's previously checked text export still omits the total amount. A checked export can correct recognized rows without supplying a completely missing observation. Therefore its failed total replay is **not proof that the parser fails on a complete, correct total transcription**. Keep the export unchanged; its coverage limit is now explicit.

Case B's checked replay already succeeds after the specific sign correction, with unchanged observation geometry. Other transcript edits may exist elsewhere, so this is strong localized evidence plus source-code tracing, not a new one-variable intervention experiment. There is no diagnosed row-association defect in either total case. Other item interpretation problems remain outside P6-01.

The dark bar is a shared, plausible visual cause of OCR difficulty. We have not proved that contrast polarity alone causes either error. Low contrast, texture, scale and the surrounding bar border may also contribute. No crop/preprocessing variant has been run in this task, and no accuracy improvement is claimed.

## Exact code path

`VisionTextRecognizer.recognize` performs the accurate full-image Vision request and retains only the top text candidate for each observation. It does not currently retry a total region with inverted contrast. `ReceiptImage.decode` retains original dimensions/orientation; there is no demonstrated downsampling loss in this import code.

`ReceiptParser.rows` retains/combines the observed fragments. `summaryLabel` recognizes the decorated total label. `printedMoney` accepts decimal-comma amounts and preserves trailing negative signs. In `ReceiptParser.parse`, the `negative_summary_check_source` guard rejects a negative decimal-comma summary instead of stripping its sign. Case A has no token to accept; case B reaches that guard. Draft/save-reopen equality confirms no downstream storage loss.

These facts narrow the next experiment to reading the summary region. A sign-removal rule, arithmetic reconstruction, footer-amount substitution or larger merchant directory is not justified by these cases.

## P6-02 experiment brief — not implemented

Hypothesis: a source-derived summary region, optionally with contrast inversion, can recover the missing total or remove the erroneous sign by producing better OCR evidence without altering financial characters in text.

1. Freeze the current parser and references. Compare the current full-image read with a native original-pixel summary-region read, then the same region with deterministic luminance inversion. Keep the original as authoritative evidence. Do not repeatedly tune many variants against the expected answer.
2. Derive the region from the detected total label and source layout, extending to the amount side with enough margin to preserve genuine leading/trailing signs. Do not use checked amounts or manually measured per-receipt coordinates to choose the automatic crop. A manual crop, if used diagnostically, must be reported separately and cannot pass the automatic recovery gate.
3. Retain every candidate, its transform, original-image mapping, timing and conflict state. Any selection rule must be specified from source evidence and tested without access to answer labels. If readings disagree about a sign, preserve ambiguity unless independent source evidence justifies resolution; a positive candidate among several is insufficient.
4. Compare all five receipts, preserving existing merchants, dates, subtotals, totals and checked item values. Include fictional light-on-dark totals with real minus signs/refunds, ordinary totals, missing amounts, bar borders, competing amounts and payment-only values. Never pick the answer because it makes the sum balance.
5. Acceptance: at least one verified automatic total recovery, taking total correctness from 3/5 to at least 4/5 on unchanged references, with no loss of prior checked fields or unsupported financial values. An isolated candidate menu or human-selected answer does not pass. If the result is neutral/ambiguous, stop the normal implementation sequence and report the failed hypothesis.

A success remains five-receipt development evidence, not broad retailer accuracy. New models/cloud services and production changes are outside P6-02's isolated experiment scope. P6-03 integration would require another approval after proof.

## Evidence and verification

- Original images inspected locally via temporary decoded viewing copies; original bytes unchanged. Copies are not published or committed.
- Both failed cases traced through frozen P5-06 raw/grouped/interpreted captures, saved draft fields and checked transcripts.
- Reproducible two-case trace generated and verified; original-image, reference, capture and production-source integrity checked.
- P5-06 evidence verifier and independent field/source/candidate-provenance verifier still pass.
- No new OCR runs, Simulator imports, app tests, reference edits or phone tests; this task is diagnosis only.

[Safe boolean findings](evidence/p6-01/aggregate.json) · [Validation](evidence/p6-01/validation.json) · [Reproduction](../evaluation/receipt-total-diagnosis/README.md). Receipt values, original images, observation indices, source IDs and hashes stay in the private ledger.
