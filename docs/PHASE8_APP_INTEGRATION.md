# P8-03 — Model-to-reviewed-draft integration

## Scope and outcome

The approved task adds an optional recognition interface and Gemini response adapter
to the existing image import, review, encrypted save and reopen workflow. Existing
imports still select local Vision by default. `GeminiReceiptReader` requires an
explicitly supplied response operation; there is no embedded developer key, default
network transport, automatic upload, fallback account or new user-facing model menu.
P8-04 supplies the personal-key connection; P8-05 supplies upload preview/consent.

Model work and decoding run outside the main actor. Cancellation propagates to the
worker; a cancelled task, replacement import or changed/locked session cannot apply
a late result. Failure preserves the original image for local/manual recovery.
No model response can overwrite an existing saved receipt's edits.

The adapter validates the bounded native envelope and required structured fields,
rejects unfinished/refused/malformed responses, preserves separate purchase
occurrences, and retains null amounts. It separates non-accounting rows without
throwing their evidence away. Currency defaults to CAD only in the visible editable
draft; original extraction never claims the default was recognized. No money is
balanced, invented or rounded. Sub-cent unit prices survive as editable text and
require review if the existing money field cannot represent them.

The complete native response is retained in encrypted original extraction evidence.
No OCR observations or geometric source links are invented for model readings.
Tax base, literal raw rows, non-accounting rows and unadapted marker proposals remain
in this evidence; this task does not add separate tax-base editing controls. Original
image bytes remain unchanged. Model output starts unreviewed; exact reconciliation
and independent source review are still required to finalize.

## Additional accuracy work

The user also approved trying to exceed 95%. The four residual purchase-name
mismatches were inspected without modifying the checked reference or matching rule.
Three include standalone department headings; one has a single-character disagreement
with the checked name. We do not guess a familiar product name to resolve that last
character.

The new v3 rule separates a heading only for a purchase with exactly two description
lines, a standalone recognized department label, and the identical heading/name
boundary in the model's literal row transcription. Same-line words, unknown headings,
non-purchases and ambiguous multiline names remain unchanged. The heading and raw
response remain evidence and the change requires review. The general department
vocabulary contains no receipt IDs, product substitutions or merchant-specific rules.
It is not independent verification of what the photo says.

Local replay of both saved five-receipt model runs yields:

| Measure | Confirmation responses + v3 | Earlier trial responses + v3 |
| --- | --- | --- |
| Purchases, exact names/kinds/amounts plus exact duplicate groups | 65/66 (98.5%) | 65/66 (98.5%) |
| Tax/discount adjustments | 9/9 | 8/9 |
| Totals | 5/5 | 5/5 |
| Merchants | 5/5 | 5/5 |
| Checked subtotals | 4/4 | 4/4 |
| Dates | 4/5 | 4/5 |

The purchase result consists of 55 strict pairs plus ten purchases confirmed only
as indistinguishable duplicate groups. The unchanged frozen v2 confirmation remains
62/66 (93.9%). This v3 result is **post-hoc local replay**, not a fresh prospective
model run, independent held-out accuracy, or a claim that 98.5% of every receipt
field is correct. Both runs concern the same five exposed receipts. No additional
model requests, uploads, costs or manual relabeling were needed.

Quantity/unit-price/taxability coverage is still insufficient for independent
accuracy claims. One date remains ambiguous; one name differs by one character.
Recovered boundaries and headings still need source review. Fewer name corrections
are supported on this corpus; actual human correction effort has not been timed.

## Verification and reproduction

- 41 structured/protocol Python tests and 6 reference-repair tests pass.
- 10 focused iOS Simulator tests pass with no skips, including the private parity
  test covering all five saved responses through import, draft save and reopen.
- Existing workflow: 21 tests pass. Persistence: 25 pass, one hardware file-protection
  check skips on Simulator, and one Keychain test initially fails with -34018 in an
  unsigned build. That Keychain test passes when rerun with Simulator signing.
- The private parity test uses fictional image bytes with saved actual model
  responses. It verifies adapter/persistence behavior, not new model inference,
  live connectivity, physical-device speed or image preprocessing equivalence.
- Assertions expose only categories/booleans; private fixtures are not bundled or
  committed. Temporary owner-only parity input is removed after verification.

Run `replay_heading.py` in `evaluation/receipt-vision-ai/model-comparison` using the
bundled Python runtime with Pillow to reproduce both saved-result scores. Run
`prepare_native_parity.py`, then the Simulator's
`SlipletTests/ReceiptModelTests/testExplicitPrivateParity`; remove
`/tmp/sliplet-p803-private-parity.json` afterwards. Use Simulator signing for the
real Keychain test. Private source/response files are required and remain ignored.
Aggregate replay evidence is `heading-replay-result.json`.

## Next approval

P8-04: personal API connection and truthful status. Add secure key entry/storage,
fictional verification, actionable connection/model/error states and disconnect;
never use a developer-key fallback. Preserve local-only use. The real-image upload
preview and user consent remain P8-05. No new live real-receipt requests or automatic
uploads are included in this handoff.
