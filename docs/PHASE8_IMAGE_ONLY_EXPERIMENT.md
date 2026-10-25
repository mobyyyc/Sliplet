# P8-02C — full receipt image, no OCR

Approved 2026-10-25. Fictional experiment complete; acceptance gate not met. This supersedes the proposed region-reading experiment for this milestone. The production app is unchanged.

## Selected design

Send one complete approved redacted receipt image directly to the existing Groq vision model. No OCR text, source IDs, bounding boxes, reference answers, earlier responses or region crops are sent. All six fictional fixtures and all five approved real derivatives fit one image; the harness refuses a split image. The existing preparation uses width at most 1,200 pixels, JPEG quality 95, no upscaling and no image metadata. The original approved mask geometry and bytes are verified before preparing real derivatives.

The concise prompt asks for merchant, unambiguous ISO date, printed currency, subtotal, total and ordered rows with kind, full literal description, amount, quantity, unit and unit price. It preserves repeated items and printed negative signs. Local code validates structure and dates, parses printed decimal signs exactly, applies the existing full-header brand aliases, separates payment/change from accounting rows and flags mismatched totals. It does not run OCR, fill omitted fields from OCR, calculate missing amounts or force reconciliation. Model interpretation of an otherwise valid date remains subject to evaluation and human review.

## Bounded procedure

At most six fictional requests, one per existing fixture, then at most ten real requests (two passes over five approved redacted receipts) only if every fictional case passes its existing checked fields. No automatic retry or provider switch. Keep the Free account, Keychain credential and previously confirmed inference ZDR. Requests are 95 seconds apart; a provider error stops the run. A failure is retained, never removed from scoring. No changes to the prompt, schema or normalization after inference starts.

The fixtures include coupons and dense product codes, weighted quantities, repeated purchases, ambiguous/unreadable information, printed instructions and multilingual product text. Their expected answers are kept out of requests. These are existing exposed development fixtures, not newly held-out examples. Real evidence remains five exposed receipts with zero held-out purchases. Real quantities/unit prices lack complete human labels and cannot support an accuracy claim.

## Fair comparison without generated coordinates

The previous comparator uses verified geometry for some rows. An image-only response cannot supply trustworthy geometry, so this experiment scores both candidate and baseline using unique kind/description matching without coordinates or amount-assisted matching. Geometry is removed only from an evaluation copy; the reference file is unchanged. Duplicates without unique identity remain ambiguous, with cardinality mismatches reported. This metric must not be conflated with previous geometry-assisted 57/65 scores. The full 65-purchase denominator remains visible; missing, failed and unattempted receipts do not disappear from reporting.

## Privacy and acceptance

Private requests, images, responses and hashes remain ignored and owner-only. Public evidence contains only fictional results and aggregate counters. Keys never appear in files, arguments, logs or chat. No personal original is uploaded. Cloud inference is not being added to the app in this task; user-owned API keys and optional opt-in remain the planned app design.

Before promotion require demonstrated improvement, correct totals/subtotals/adjustments and no previously correct-field regressions. No inference from success on fictional fixtures to real-world accuracy. No paid fallback or new real uploads if the fictional gate fails.

## Results

All six fictional requests returned model responses, with no provider rate-limit errors. Five passed structural/numeric validation; the weighted response was retained as `unreadable_printed_number`. No real receipt requests were made, because the fictional gate did not pass. No prompt or normalization change was made after inference began.

| Case | Result |
| --- | --- |
| Dense products and coupons | All 15 accounting rows, merchant, date, subtotal and total correct; invented an unprinted currency. |
| Weighted product | Correct product description, extension and total; quantity contained a unit and the unit field contained a unit-price expression. Rejected rather than silently repaired. |
| Repeated purchases | All checked fields correct; occurrences preserved. |
| Ambiguous date/unreadable total | Product and unknown total correct; guessed an ambiguous date. |
| Printed instructions | All checked fields correct; did not obey the printed instruction. |
| Multilingual/TOTAL product | Both products and all summary fields correct; omitted the printed zero tax row. |

**Strict result: 2/6 fully exact cases.** On the five numerically valid responses, 22/23 expected accounting rows match, with the missing row being zero tax. This is a conditional diagnostic on fictional cases, not full-corpus accuracy; the weighted case remains failed in the primary result. No comparison to real-receipt local OCR or claim of 90% real accuracy is supported. The simpler contract is promising for reading literal purchase/coupon rows, but unsupported metadata and completeness still require correction.

The initial unit test imported a same-named correction harness accidentally; the test import was fixed and all 13 tests passed. The actual request payloads were verified independently against the frozen image-only builder. After the weighted local validation failure stopped the main runner, `finish_fictional.py` explicitly completed only the unattempted fictional cases. It cannot retry or continue past a provider error. This was within the original six-request cap, with the selected request and extraction code unchanged.

## Next proposed task: image-only field-contract refinement

Keep the full image and no OCR. Add explicit field definitions and short generic examples: quantity is a decimal string only, unit is a unit label only, unit price excludes its unit suffix; ambiguous dates and absent currency are null; individually printed zero-value tax/adjustment rows must be retained. Preserve a literal date string separately if needed to avoid silently presenting a guessed ISO date as verified. Keep source coordinates out of model output. Never infer currency from a language, location, dollar symbol alone or merchant.

Use a separately frozen revision, preserve these raw failures and scores, and test fictional variations not included in the prompt. Only a passing gate authorizes proceeding to the already-planned real comparison. No extra network calls have been made for this proposal. This task needs Main approval; no app integration yet.

## Verification

`python3 -m unittest discover -s evaluation/receipt-vision-ai/image-only -p 'test_*.py'` passes 13 tests using the bundled Python runtime. `score.py fictional` reproduces the retained failures. `verify.py` confirms all six exact request payloads, immutable configuration, fixture hashes, no OCR/coordinates in requests, canonical output or numeric rejection, and zero real uploads. Private response values stay ignored; committed evidence contains fictional outcomes and aggregate verification only.
