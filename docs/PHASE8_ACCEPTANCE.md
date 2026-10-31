# P8-07 — Current-app acceptance

2026-10-30. Approved bounded acceptance using the five previously checked actual receipts. Classification: **useful optional beta; fresh current-app accuracy gate pending**. Phase 8 is not an all-gates-passed release.

## Fresh evidence

Exported all five request bodies using the production Swift image preparation and request builder. They contain the image and fixed structured prompt/schema, without OCR or checked labels. JPEG bytes differ from the historical Python encoder; prompt (apart from trailing whitespace), schema and generation settings match. Historical scores therefore cannot be relabeled as fresh app-path results.

Frozen the native sources, runner, adapter, references, originals and exact request bytes before sending. The bounded run permits at most five attempts, 95-second spacing, no automatic retries and stops after any failed attempt. Model: `gemini-3.6-flash`.

The first request timed out after **120.181 seconds**, without a model response. One request was attempted; the remaining four were not sent. Fresh accuracy, schema success, token usage and correction effort are unmeasured. A timeout does not prove poor recognition or that the provider did not process the request.

A subsequent metadata-only authenticated model lookup returned HTTP 200 in 0.166 seconds. The saved key and selected model were available at that moment; this does not establish inference reliability. No replacement model or additional receipt request was attempted.

Private evidence remains under `private-receipts/evaluation/p8-07-current-app-01/`. The frozen-request exporter refuses to overwrite an existing request set. The final hash verification passed.

## Retained evidence, clearly separate

The previous post-processing replay achieved **65/66 core purchases (98.5%)**: 55 strict matches and 10 purchases in checked indistinguishable duplicate groups. The confirmation set had 9/9 adjustments, 5/5 totals, 5/5 merchants, 4/4 checked subtotals and 4/5 dates; the earlier retained set had 8/9 adjustments. This is five exposed receipts and zero held-out receipts, not 98.5% accuracy across every field or new purchases. Quantity, unit-price and taxability labels are incomplete. Ambiguous dates and the remaining description discrepancy are not silently repaired.

Historical confirmation required seven attempts for five responses (one HTTP 503 and one timeout). Successful response times ranged from 4.741 to 19.750 seconds. These historical results do not substitute for the new run's timeout.

Native parity replay used the five original photos and retained responses. Import, draft save, reopen, original-photo preservation, immutable model evidence and expected structured fields passed. Replay involves no fresh inference. Source review and exact reconciliation remain required to Finish; replay does not mark receipts reviewed.

Final native validation: 10 tests passed, one explicit request-export test skipped because its manifest was absent, zero failures. The earlier export/parity run passed all 11 tests. Logs: `/tmp/sliplet-p807-final.log` and `/tmp/sliplet-p807-parity.log`. The exporter overwrite guard compiled in the final run; its existing-file branch was not exercised by that run.

## Privacy and release boundary

The user explicitly authorized these actual images. The Gemini key was read from local Keychain and never included in exported bodies or public artifacts. Free-tier/billing-disabled status was user-confirmed, not independently verified as a current quota or billing guarantee. Groq's previously confirmed retention setting does not apply to Gemini. No new provider-retention guarantee is claimed.

The optional personal-key route and local OCR fallback remain. P8-06's 71 checks and Release build, and the later wallet-return UI checks, remain separate supporting evidence. No physical-phone installation, new human correction timing or unseen-receipt validation occurred here.

## Next proposed boundary

Approve one fresh bounded continuation using the same five originals, exact frozen native payloads and model: at most five new attempts, one per receipt, 95-second spacing, stop on the first failure, no automatic retries or model changes. Keep this failed run intact and use a separate ledger. Score only returned complete results against the unchanged references and replay successful results through native save/reopen. If it fails again, investigate inference reliability before proposing any model or timeout change. Physical-phone updating remains a separate approval.

## Approved continuation — 2026-10-30

Separate private run `p8-07-current-app-02` retained identical request bytes and
verified the original run's frozen hashes before dispatch. One request returned
in **13.013 seconds**, with finish reason STOP, but strict validation failed;
the other four were not sent. No automatic retry or configuration change occurred.
The response used 2,794 input and 2,644 output tokens (5,438 reported total).

Local diagnosis: after the already-supported Markdown fence removal, the response
is valid JSON. It includes all nine expected root fields plus one unexpected
field, causing `schema_keys`. This is a response-contract failure, not malformed
JSON, truncation, or measured recognition inaccuracy. Both the lab validator and
native adapter require the exact root field set. The private raw response and
safe diagnosis are retained; no fields were removed to manufacture a pass.
No fresh five-receipt score or successful fresh native save/reopen is claimed.

The production request currently embeds the schema in prompt text, with only
output-token and thinking options in generationConfig. It does not request
API-enforced structured output. Google's structured-output documentation describes
API-level JSON Schema support including additionalProperties controls:
https://ai.google.dev/gemini-api/docs/generate-content/structured-output
This identifies a concrete next experiment, not a proven accuracy improvement.

Revised next milestone for approval: configure the existing schema through the
provider's structured-output API, retain strict local validation, add fictional
contract regression checks, and run a bounded fictional compatibility probe on
the selected model before sending actual receipts. If the probe passes, freeze
the revised request configuration and evaluate the same five approved originals
once each, stopping on failure. Keep all prior failed runs intact and compare
accuracy against unchanged references. No model change, relaxed money rules or
phone installation is included.

## Fresh acceptance with the schema-echo fix · October 31

All five exact native image payloads produced usable responses on the first attempt. The owner-approved run used the original model, images, request bodies and checked reference. Only the evaluator’s handling of the top-level Boolean schema echo changed to match the shipped reader. Offline checks verified the saved response and six invalid variants before scoring. One fresh response used this exception. The experiment made five generation requests. Reported usage was 25,057 tokens and response times ranged from 17.7 to 45.2 seconds (median 38.2).

The scorer found **65/66 core purchases (98.5%)**. It matched 55 individually and 10 through the checked counts and prices of five indistinguishable duplicate groups. The strict miss had a same-price candidate with a similar description and remained a miss. Merchants and totals matched on 5/5 receipts, checked subtotals on 4/4, discounts on 6/6, tax charges on 3/3 and dates on 4/5. One date remained missing. The local baseline was 59/66 purchases, 4/9 adjustments, 3/5 totals and 5/5 dates. The model exceeded the 95% core-purchase target on these five exposed receipts; date coverage regressed against the local baseline. Quantity, unit price, currency, tax rate and most item tax markers lacked independent labels. Correction time and unseen-receipt accuracy remain unmeasured.

All five fresh responses passed native Simulator import, draft save, reopen, field parity, original-photo and raw-response preservation in the explicit private parity test. This replay used the exported app payloads and stored provider envelopes. It did not measure live iPhone networking. Classification: useful optional personal beta. P8-07's fresh five-receipt evaluation is complete. Full unattended receipt recognition remains outside the verified scope. Human original review and exact reconciliation still govern finalization.

Public counters are in `evaluation/receipt-vision-ai/model-comparison/echo-acceptance-result.json`. Private artifacts are in `private-receipts/evaluation/p8-07-echo-acceptance-01/`. Physical-phone updating requires separate approval.
