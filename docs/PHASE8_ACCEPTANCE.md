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
