# P8-07 structured-output compatibility check

2026-10-30. The approved task was to add API-enforced output structure, verify a
fictional receipt first, and evaluate the existing five originals only if that
gate passed. **The fictional gate failed; no actual receipts were uploaded.**
Production request behavior was restored, so the proposed change is not shipped.

## Experiment

All three fictional probes used the selected `gemini-3.6-flash` model, a native
rendered fictional receipt, production image preparation, unchanged receipt
prompt, 6,500 output-token limit and low thinking. Each configuration was frozen
before its single call. These were distinct compatibility configurations, not
retries of failed actual receipts. No automatic retry, model substitution or
fallback upload occurred.

| Configuration | Result | Seconds |
| --- | --- | --- |
| `responseFormat.text` with JSON MIME and JSON Schema | HTTP 400 | 14.895 |
| `responseMimeType` + `responseJsonSchema` | HTTP 400 | 6.248 |
| `responseMimeType` + OpenAPI `responseSchema` | HTTP 400 | 29.576 |

The last two error bodies report only `INVALID_ARGUMENT` / “Request contains an
invalid argument.” The first body was not retained, so its exact reason cannot
be claimed. The legacy representation converted nullable type unions to
`nullable: true` and omitted `additionalProperties`, which is outside that
representation; strict local exact-key validation remained unchanged.

The official REST documentation describes `responseFormat.text.schema`; API
reference material also describes the older schema fields. These documents do
not prove this particular model/account accepted our full schema:
- https://ai.google.dev/gemini-api/docs/generate-content/structured-output
- https://ai.google.dev/api/generate-content

All prepared real-image contents and prompt text were checked equal to the prior
native exports; only generation configuration differed. They were not sent.
Private request/response evidence stays in `private-receipts/evaluation/` under
`p8-07-structured-01`, `-02`, and `-03`. Raw error bodies remain private too.

## Validation and rollback

Each candidate passed 26 focused native tests with one optional private parity
skip. Four isolated runner tests passed: failed fictional gate blocks uploads,
failed attempt stops the run, five completed requests cannot resend, and a
duplicate request inventory is rejected. These local results establish request
construction and guard behavior, not live provider compatibility.

The unshipped legacy candidate and its request assertions are retained in
`evaluation/receipt-vision-ai/model-comparison/structured-output-candidate.patch`.
Production transport and upload tests were restored to their pre-experiment
versions. The explicit lab exporter now also produces a fictional native request.
The evaluation runner refuses changed frozen sources; the old snapshots must not
be resumed after rollback. A future experiment needs its own output directory
and configuration.

Final restored-production validation: 25 native checks passed, two optional lab checks skipped (their manifests were absent), zero failures. Log: `/tmp/sliplet-p807-restored-native.log`.

## Conclusion and next proposed task

No new recognition score, schema success, or fresh private save/reopen result is
claimed. P8-07 is still pending. This experiment does not establish that the
selected model has no structured-output support: schema complexity, parameter
compatibility and model/account support are not yet separated.

Next approval: a small fictional-only compatibility matrix, beginning with a
single-field schema on the current model, then adding the receipt schema's
nullable fields, enums and rows in bounded steps. Compare with the full schema
only after minimal support works. Use at most six fictional calls, spaced at least 95 seconds apart;
no actual receipts, automatic retries, model substitution or production switch.
If the current model cannot pass a minimal case, present a separate model-change
proposal with privacy and cost constraints intact. Only a passing configuration
should proceed to the five-receipt accuracy run.
