# P8-02B — literal extraction and supplied source anchors

Approved 2026-10-24. Experiment stopped on a provider limit; candidate not promoted. Production app unchanged. Budget: six fictional requests followed, only after calibration passes, by ten real requests (two passes over the same five approved redacted receipts). No automatic retries, account upgrades or provider changes.

## Confirmed causes and corrective design

The retained P8-02 outputs contain three source quotes with trailing minus signs whose normalized amounts were positive. This is a confirmed transformation error, not merely a hypothesis about weak OCR. Source identifiers and boxes were also generated incorrectly, and some source quotes retained codes that descriptions dropped.

The new request uses a compact literal ledger. `image_id` is constrained to the supplied image; entry sources must be indexes in fresh Vision OCR fragments from the same prepared redacted JPEG. Model coordinates are removed. The OCR text provides locations and literal spelling; the model still reads the image and decides receipt structure. Neither original unredacted OCR nor checked references enter requests.

Printed monetary tokens stay literal until local exact parsing handles prefix/trailing minus and parentheses. No missing amount is calculated. Product codes and suffixes remain part of literal descriptions. The existing full-header merchant-brand policy is reused for supported brand spellings, never arbitrary substring matches. Ambiguous dates remain unknown; No Frills short dates use the existing clock-qualified date rule. None of these changes edit reference answers or the old scores.

## Calibration before private inference

Six fictional cases cover dense coded products/trailing-minus coupons; weighted multiline purchases; repeated products and a coupon; ambiguous date/unreadable total; receipt-embedded instructions; and mixed-language text including a product named TOTAL CEREAL. Expected fields were fixed before inference. Every raw response and pre-calibration result is retained.

Initial results exposed two additional failures despite valid source references:

- Every expected dense-case product/coupon matched, but CARD below the total was classified as tax. The selected local correction requires an exact printed payment label in the selected OCR source AND its physical location below the total. Product names such as GIFT CARD, omitted SKU prefixes and CARD above the total are negative tests.
- The weighted case selected the correct fragments but omitted amount/quantity/unit/unit price. The selected recovery copies only a unique standalone price or explicitly printed measurement expression among those selected fragments. Multiple prices remain unresolved; unit-price formulas never generate a missing extension; quantity is never defaulted to one. Nonmissing model values are not overwritten.

These are calibration changes selected from fictional failures before private scoring, not hidden post-hoc edits to real results. The initial contract/score remains archived and the final normalizer was frozen before any P8-02B private request. The model's source selections still require validation; valid indexes do not prove the claimed association is correct.

## Frozen real comparison

Use the same approved redacted images, geometry and five checked references. Use the original comparator and full 65-purchase denominator. Fresh redacted-image OCR anchors are mapped directly to normalized original coordinates; no model-generated box or amount-assisted matching is used. Report summary fields, purchases, adjustments, missing/extra rows, previously correct losses, semantic warnings, repeated-run stability and actual API usage. Quantities/units/unit prices remain outside verified real-label coverage.

Only one revision proceeds to private scoring after all six fictional cases meet the calibration gate. Preserve the existing local OCR baseline (57/65 purchases, 3/5 totals, 4/4 checked subtotals, 4/8 adjustments). A failure does not justify replacing the app's current recognizer or declaring 90% accuracy. Five exposed receipts, zero held-out receipts.

## Quota and privacy

Compact output cap is 3,500 tokens; requests are spaced 95 seconds apart. The runner logs only allowlisted quota headers and numeric diagnostics, never error-body text or credentials. Earlier 429 diagnostics disagreed with headers, so header values alone are not treated as proof of available capacity. Fictional calls establish feasibility before any further private upload. No automatic retry or paid fallback.

The existing Keychain key is reused in memory. Exact payloads, OCR fragments, source anchors, responses and hashes remain ignored and owner-only. The approved flattened image is verified before preparation; OCR is run only on those redacted pixels. The app is unchanged.

## Result and disposition

Six fictional requests completed. Raw extraction passed 3/6; the calibrated hybrid passed 6/6, without extra requests. The third calibration fix recovers an explicitly printed ISO currency token only from selected header/date fragments. All calibration cases are exposed, not held out. None of these calibration corrections fired on the two completed real receipts.

The five approved real images and six fictional images were re-OCRed using isolated temporary files; all 11 anchor arrays matched exactly before private inference. This also rules out contamination from the old shared OCR temporary filename. The selected prompt, normalizer, reference and comparator were frozen before real calls.

Three real attempts were made: two structured responses, then HTTP 429. Seven planned attempts were not run; there was no retry. Completed-subset purchases: **33/36 exact, versus 33/36 for the local baseline on the same subset**. This is 91.7% of a selected subset, NOT a 90% pass over the five-receipt benchmark. Only 33 exact purchases are demonstrated against its full first-pass denominator of 65; repeatability was not measured.

Both completed receipts had correct merchant, subtotal and total. Dates were missing once and wrong once. Only 3/8 adjustments were exact; both receipts had accounting conflicts. One previously exact row and two previously correct summary fields were lost. Four reference rows lacked a match and six output rows were unmatched proxies; these counts do not by themselves prove invention. The first receipt also had three non-exact purchases. Discount omissions/misclassification/description mismatches remain a substantive extraction problem, beyond response formatting. Valid source indexes do not establish correct source association.

The rate error reported tokens-per-minute limit 1,000 and requested 1,570, despite headers reporting 8,000 available. No raw provider error text or credentials were retained. A request larger than its stated limit cannot be fixed solely by slower pacing; the account/model limit needs clarification or a materially smaller request. Do not promise that another wait will resolve it.

**Decision:** do not integrate or replace local recognition. This repairs the earlier invalid-source failure and improves the earlier LLM result, but does not beat the existing local recognizer on the completed subset. No app changes. Exact approved payloads, responses and original candidates remain private; public evidence is aggregate only.

## Proposed next gate — P8-02C, approval required

1. Resolve the account/model quota discrepancy using account limits and a fictional request; never probe limits by repeatedly sending real receipts. Keep Free plan and no automatic paid fallback.
2. Compare a bounded fictional region-reading approach against this retained full-image result. Supply merchant/date, item/coupon and summary regions with original coordinates; use overlapping boundaries and explicit duplicate-occurrence checks. Keep literal text/amounts and local sign parsing. The point is to test whether denser image detail and a smaller semantic scope improve coupon handling, not merely add more prompts.
3. Require exact coupon signs/roles, complete repeated items, date abstention, and no payment-as-tax errors on fictional cases not used to tune the prompt. If the current model fails, propose a model comparison before spending more real uploads. A different provider still needs privacy approval.
4. Only after that gate, propose a new capped real comparison on all five frozen references. No automatic app integration, label changes, or replacement of correct fields with unverified LLM values. Quantity/weight/unit price remain outside verified real-label coverage.

This is a proposal, not an approved additional network budget. P8-03 remains gated.

## Reproduction

Run the correction directory's `test_*.py` suite, `verify.py` for offline payload/configuration/canonical-result verification, and `partial.py` for the interrupted-run aggregate. `score.py real` intentionally refuses to publish a complete benchmark while responses are missing. Private evidence is required for reproduction and is not committed. The 27 correction tests pass; offline verification covers six fictional and three real attempts.
