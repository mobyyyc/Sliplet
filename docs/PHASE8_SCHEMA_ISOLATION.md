# P8-07 — Fictional schema isolation

2026-10-30. Approved maximum: six fictional calls, at least 95 seconds apart,
current model only, no actual receipts or production change. The runner and
fictional fixture hash were frozen before the first call. Distinct HTTP 400
cases may advance; network/auth/quota failures stop the experiment. No retries.

## Observed results

| Case | Outcome | Elapsed |
| --- | --- | --- |
| Single required merchant string, OpenAPI responseSchema, JSON MIME, low thinking | Passed exact fictional expectation | 1.345 s |
| Same schema with a required nullable date, prompt explicitly says the fictional date is unknown | Network/timeout, no response | 120.057 s |

Two calls were attempted. The remaining four were not sent. The completed result
reported 22 input tokens and 14 output tokens. Timeout token use is unknown;
no claim is made that a timed-out request was not processed by the provider.
A subsequent runner invocation returned `complete_or_stopped` without a send.

The selected `gemini-3.6-flash` model **does accept a basic API-constrained schema**
on this account. This rules out a blanket claim that structured output is wholly
unsupported. It does not establish full receipt-schema compatibility. The second
case is not an HTTP 400 or a schema rejection: no response was available, so we
cannot attribute the timeout to nullable fields. Schema complexity, lowercase
versus uppercase type encoding, nullable fields, item arrays and image input have
not yet been isolated. The previous full-schema HTTP 400 failures remain real.

The two requests differ in both the nullable date field and the fictional prompt
needed to describe that field; any future comparison must retain that limitation.
No accuracy or real-receipt extraction result was measured. The app's production
request, local validation, OCR fallback, stored receipts and installed phone app
remain unchanged.

## Evidence and verification

Private artifacts: `private-receipts/evaluation/p8-07-schema-isolation-01/`.
Only fixed fictional data is present in request bodies. The API key is read from
Mac Keychain into the header, not saved in requests or printed. Existing
user-confirmed free-tier/billing-disabled status is required; it is not a live
quota or billing check.

Public aggregate: `evaluation/receipt-vision-ai/model-comparison/schema-isolation-result.json`.
Five offline diagnostic tests passed: successful progression, distinct cases and
six-call cap, transport/auth/quota stopping, text-only controls, and strict
fictional-result validation. No production code changed, so Simulator UI tests
were not repeated for this diagnostic-only task.

## Next proposed boundary

Fresh acceptance remains pending. Seek approval for one bounded continuation of
the fictional matrix: at most four additional calls, starting with one explicitly
approved repeat of the nullable case after cooldown. Keep this stopped run
unchanged and record the new attempts separately. If it succeeds, test enum/item
rows, the full text schema and finally the fictional image. Stop on another
transport/auth/quota failure, do not automatically retry or change models, and
upload no actual receipts. Another timeout should lead to a reliability/model
route decision rather than continued prompt tuning or a claimed accuracy fix.
