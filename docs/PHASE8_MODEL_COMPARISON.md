# P8-02E — fixed-fixture vision model comparison

Approved 2026-10-26; six-attempt plain-JSON evaluation completed 2026-10-27 with five exact responses and one service failure. Historical diagnostic failures are retained below. Fictional receipts only. No app changes or real-receipt upload path.

## Candidate selection

A read-only Groq model listing with the user's existing account returned Qwen 3.8 27B but not the other documented vision candidate. Groq documents Muse Spark Open as limited preview requiring contact; free access was not assumed. Google documents Gemini 3.8 Flash with image inputs, structured output and free input/output allowance. Select `gemini-3.8-flash` as the single comparison candidate, subject to this user's account access and quota.

Official sources checked 2026-10-26:

- [Groq vision models](https://console.groq.com/docs/vision)
- [Gemini 3.8 Flash capabilities](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash)
- [Gemini pricing and free allowance](https://ai.google.dev/gemini-api/docs/pricing)
- [Gemini compatible chat API and structured output](https://ai.google.dev/gemini-api/docs/openai)
- [Gemini unpaid-service terms](https://ai.google.dev/gemini-api/terms)

The unpaid Gemini service permits product-improvement use and human review. It remains fictional-only, including if it performs better. This does not approve real redacted receipts for Gemini, change the privacy decision, or establish consumer BYOK eligibility. Provider terms and future model availability can change.

## Controlled comparison

Use the exact six P8-02D fixture images, system prompt, field descriptions/schema, 3,500-token completion cap, requested temperature zero and scorer. The chat request differs only in the `model` value; the fixed endpoint and credential change to Gemini. Whole-image preparation is unchanged. The runner compares each request against the retained P8-02D request before transmission, after replacing only the model identifier. There is no OCR, crop, source coordinate, prompt tuning, answer leakage or altered label.

Reasoning uses each provider's default. Equal token caps do not imply equal tokenization, reasoning compute or image encoding. This is a comparison of these concrete API configurations, not an isolated model-weight benchmark. P8-02D's six retained Qwen responses form the baseline (4/6 fully exact); this task does not replay them or silently replace failures. Each model has only one response per case, so repeated-run stability and unseen receipt accuracy remain unmeasured.

## Budget and credentials

Initially capped at six fictional inference attempts, zero real attempts, spaced 95 seconds apart. Following the first HTTP 503, Main announced and performed one bounded recovery attempt, retaining the original failure; the supplemental cap was seven total attempts. There is no automatic retry loop, fallback provider/model, account upgrade or paid path. A provider error stops the run; incomplete output is not repaired or scored as complete. This harness accepts no arbitrary input file and has no real-receipt command. The transport refuses redirects and implicit proxies, bounds request/response size, and emits only safe error categories.

The user confirmed a Gemini Free-tier project with billing disabled in a hidden Terminal prompt. The replacement/new provider key is saved in the separate macOS Keychain service `com.sliplet.development.gemini`, never in source, a plaintext credential file, logs, arguments or chat. The existing Groq key is untouched. This is user-confirmed billing state, not an API billing audit; no billing configuration is changed. Request success separately establishes inference access.

## Acceptance

Report exact cases, per-field/row failures, changes versus the identical baseline cases, provider failures and latency/usage. All six planned cases remain visible. Preserve raw candidates and canonical results privately and publish only fictional/aggregate evidence. A better synthetic score is evidence for a next experiment, not permission to send private receipts or integrate into the app. Require explicit next-task approval.

## Observed connection result — not an accuracy result

The first fictional inference request returned HTTP 503 after 44.816 seconds. A separate read-only model metadata request succeeded and confirmed `models/gemini-3.8-flash` supports `generateContent`. That validates model metadata access, not inference or billing state. Main checked the official troubleshooting guidance and announced one bounded recovery after backoff. The identical recovery request timed out after 60.077 seconds. Both attempts are retained; zero model completions were received. No further requests were made in that initial run.

Google recommends bounded backoff for transient 503 errors. Its troubleshooting page also says Gemini 3.6+ ignores custom temperature values; therefore the identical requested zero temperature is not an assertion of identical sampling behavior across providers. Provider-default thinking can affect latency. A timeout alone does not establish whether the server completed the request. We cannot infer whether capacity, the compatibility endpoint or inference latency caused these failures from the available safe diagnostics.

Source: [Google troubleshooting and retry guidance](https://ai.google.dev/gemini-api/docs/troubleshooting).

**P8-02E is not complete.** Only the first of six distinct cases was attempted (twice); five cases were not attempted. Gemini has no measurable accuracy result. Do not describe it as scoring zero percent or as worse than Qwen. Qwen's retained 4/6 exact cases remain the comparison baseline, not a winner against an unavailable model. No real images were uploaded and no app recognition changed.

## Verified preparation and continuation

The Gemini Keychain entry is present and separate from Groq. The user confirmed Free tier/billing disabled; no independent billing API verification was performed. Seven local tests pass. Offline verification reproduces both exact image-only payloads, confirms the only body difference versus the retained baseline is the model ID, checks the frozen source/configuration and fixture hashes, and verifies no original failure was overwritten. Raw output and credentials are absent from committed evidence; the public result records safe failure categories and incomplete status.

Continue this same milestone when inference is available; do not dispatch a new app-integration task. The saved key need not be entered again. Before another inference attempt, explicitly review the stopped-run budget and preserve these attempts. A longer timeout or native stateless endpoint may merit a separate diagnostic configuration; both were subsequently tested in the continuation below. No recurring polling or scheduled retry was created.

## Approved continuation — native endpoint (2026-10-26)

User approved resuming the unfinished milestone. Preserve both compatibility failures. The new `native.py` configuration permits at most six fictional attempts, no real attempts and no automatic retries, under a separate private `native/` directory. The dense fixture is the first diagnostic; continue with the other five only after a usable response. A provider error or truncated response stops this run.

Use Google's documented stateless `generateContent` endpoint and `responseFormat.text` JSON schema. Preserve exactly the same JPEG bytes, system prompt, field descriptions, local normalization and scorer. Omit deprecated temperature, use explicit low thinking to reduce reasoning latency, and increase the client timeout from 60 to 180 seconds. The output cap remains 3,500 tokens, which includes Gemini reasoning. These are intentional configuration changes; results are not an isolated comparison of model weights, nor proof that a particular transport setting caused any improvement. The previous failures remain in the operational record.

Sources: [native structured-output request](https://ai.google.dev/gemini-api/docs/generate-content/structured-output), [thinking levels and output limits](https://ai.google.dev/gemini-api/docs/generate-content/thinking), [Gemini 3.8 migration changes](https://ai.google.dev/gemini-api/docs/whats-new-gemini-3.8).

Twelve offline tests pass, including exact preservation of image/prompt/schema across API formats, no tools or unsupported sampling parameters, rejecting incomplete responses, and excluding thought parts from candidate text. The native endpoint uses the saved Gemini key only in the HTTPS header; no file upload service, server-side conversation, search tool, proxy, redirect or credential URL parameter is used.

## Continuation outcome — comparison remains incomplete

The native Gemini 3.8 image request timed out after 180.102 seconds. A tiny text-only diagnostic also returned 503, so the failure was not limited to receipt images. This does not establish a global outage. A model listing advertised Gemini 3.6 Flash, whose documented Standard free tier was checked; its tiny text-only diagnostic succeeded in 2.185 seconds. Main explicitly selected 3.6 for a separate diagnostic configuration, without a paid fallback or any real upload.

Three separate 3.6 image configurations (native responseFormat, native responseJsonSchema, and compatible chat schema) each returned 400 INVALID_ARGUMENT. Two text-only checks using the full schema also returned the same generic error. Removing only the provider-side rows.maxItems bound yielded a successful text-only response in 1.625 seconds. This isolates a schema compatibility problem in that diagnostic; it does not prove all image requests will work. The exact original schema, including the 150-row cap, remains enforced by the local validator.

The new native36_bounded_local.py adapter preserves image bytes, prompt, field descriptions, local schema, normalizer and scorer. It omits only rows.maxItems from the provider schema. The first full receipt request then returned 503 UNAVAILABLE after 7.452 seconds, so the runner stopped without retrying or attempting the remaining five fixtures. No complete Gemini receipt candidate was received; there is no measurable Gemini receipt accuracy or model winner.

This continuation made ten inference POST attempts: five image attempts and five text-only diagnostics. Together with the two initial compatibility attempts, twelve POST attempts are accounted for. Read-only model metadata/list requests are separate. These were explicit diagnostic configurations, not an automatic fallback chain. Failed attempts are retained in separate private directories; one repeated generic text-error inspection is recorded here rather than as a separate saved response. No original results or labels were overwritten. The latest selection and request hashes reproduce offline.

Fourteen offline tests pass (run in separate processes to isolate adapter configuration), including preservation of the prompt/schema contract and rejecting 151 rows locally. No app code changed. Keychain storage works; inference availability remains unresolved. The free-tier/billing-disabled state remains user-confirmed.

Sources: [Gemini 3.6 capabilities](https://ai.google.dev/gemini-api/docs/models/gemini-3.6-flash), [Standard free-tier pricing](https://ai.google.dev/gemini-api/docs/pricing), [native API schema](https://ai.google.dev/api/generate-content).

Next: resume P8-02E with a bounded, explicitly approved inference check when service is available; do not proceed to app integration or real Gemini receipt uploads based on these diagnostics.

## Approved resumption 01 — stopped after one request

The user approved another bounded resumption. The separate resume36.py runner retained all earlier attempts and sent the same Gemini 3.6 adapted image request once. It returned HTTP 503 UNAVAILABLE after 3.035 seconds. The remaining five images were not sent. Offline verification reproduced the request and canonical evaluation setup; no model receipt output exists to score. Two additional offline tests verify frozen attempt limits and refusal to retry a recorded failure.

Total inference POST attempts across the initial run, diagnostics and this resumption: thirteen (eight image attempts and five text-only diagnostics). All were fictional. No key re-entry, billing change, app change or real upload occurred. P8-02E remains incomplete, with zero completed Gemini receipt cases.

Do not keep requesting approval for identical retries as the default next step. Before another paid-provider inference attempt (including its free tier), diagnose the image-request failure with a separately bounded plan, or explicitly choose another candidate. Text generation succeeding is not proof that image inference is available, and repeated 503 responses do not establish receipt complexity as the cause.

## Approved image-input diagnosis 01

Three predeclared, sequential requests to Gemini 3.6 used the same instruction (Reply with OK), 128 output tokens, low thinking, no receipt system prompt and no output schema. Requests were spaced 95 seconds apart with a 30-second client timeout and no retries. Only the image part changed.

| Control | Outcome | Seconds |
| --- | --- | --- |
| Text only | STOP completion, OK acknowledgment | 1.316 |
| Valid 64 × 64 JPEG, 693 bytes | STOP completion, OK acknowledgment | 11.366 |
| Exact fictional receipt JPEG, 1000 × 950, 171319 bytes | Network/timeout category, no response | 30.087 |

Both JPEGs decode and verify locally. The native inlineData/mimeType format matches Google's JavaScript API example. Total payload is comfortably below the documented 20 MB inline limit. This excludes an oversized request and shows the credential/endpoint can accept at least one image; it does not prove visual understanding from an OK acknowledgment. Google documents inline images and bounded handling of transient failures: [image input](https://ai.google.dev/gemini-api/docs/generate-content/image-understanding), [troubleshooting](https://ai.google.dev/gemini-api/docs/troubleshooting).

The full receipt failed without the extraction prompt or schema, so those are not necessary for this failure. This was a single non-simultaneous sample per condition: image workload, changing service availability and client timeout remain confounded. Do not claim the schema is the sole cause, a global outage, or a proven free-tier restriction. No extraction accuracy was tested in this diagnostic.

All three exact requests, original responses and source hashes reproduce offline. Two new offline tests cover paired-request isolation and no retry after failure. Three diagnostic POSTs bring the experiment-wide total to sixteen: ten image attempts and six text-only attempts. All inputs are fictional; no app changes or billing changes.

Recommended next bounded experiment, pending approval: use the same fictional receipt at reduced resolution, compare it with the original at an equal timeout, and request a short image-specific answer. If that establishes a working image path, attempt plain JSON extraction without provider-enforced schema, retain strict local validation, and score against the unchanged reference. Reduced resolution can damage text recognition; success must be measured, not assumed. Do not restart the six-case benchmark until the first actual extraction works.

## Approved resolution diagnosis — first complete extraction content

Three image requests were reserved in advance, with 95-second spacing, a 60-second timeout, no retries, and zero real inputs. The two reading controls used the same merchant-only prompt and output settings; only the image changed. The reduced image was 640 × 608; the original remained the exact 1000 × 950 fixture JPEG.

| Request | Outcome | Seconds |
| --- | --- | --- |
| Reduced image, merchant-only | HTTP 503 UNAVAILABLE | 2.364 |
| Original image, merchant-only | Correct merchant | 2.018 |
| Original image, full extraction without server schema | Complete STOP response; exact outer Markdown JSON fence caused strict invalid_json | 27.100 |

The run was interrupted while waiting before the extraction call. On continuation, Main verified that only the two controls had been sent, then resumed the third request without replaying either control.

The extraction request uses the existing field instructions and exact schema as text in the user prompt, without provider-enforced formatting. It keeps strict local schema validation. This changes prompt placement and schema presentation as well as provider formatting; success is not proof that removal of provider schema alone caused the improvement. The failed reduced image and successful original do not establish a benefit from downscaling.

Offline inspection removed only one exact outer Markdown JSON fence. The original invalid_json result and raw output remain unchanged. No fields, signs, numbers or labels were repaired. The enclosed JSON passes the unchanged local schema and canonical normalizer. Against the existing dense-coupons reference, all five scored summary fields and all 15 accounting rows (12 purchases, two discounts, one tax) are exact. Payment is excluded by the existing canonical accounting rules. Qwen's retained response missed the tax on this same case. This is one exposed fictional case, not an overall accuracy percentage, reliability result or completed six-case comparison.

Six new offline tests pass: resolution/request isolation, selection gate, no reference-answer leakage, exact fence handling, rejection of prose/multiple fences, and rejection of malformed or duplicate-key JSON. Offline verification reproduces all requests and the scored content. The experiment-wide total is nineteen POST attempts: thirteen image attempts and six text-only diagnostics. No real receipt, billing or app changes.

Next proposed task: freeze a new six-fixture configuration using the successful original-resolution plain-JSON request, with narrowly bounded outer-fence handling before unchanged local validation. Preserve this pilot separately; score every case, retain failures, and do not claim a model winner until the comparison is complete. This needs the next explicit task approval; private Gemini uploads remain unapproved.

## Six-fixture plain-JSON evaluation — 2026-10-27

The approved run made one new request per fixture, including the dense pilot case. It used the successful original-resolution prompt/configuration, with 60-second timeouts, 95-second spacing, no automatic retries, strict local validation and narrowly bounded outer-fence handling. The pilot was not substituted for a failed response. All six requests were attempted; five returned valid candidates and one returned HTTP 503.

| Fixture | New Gemini result | Seconds |
| --- | --- | --- |
| Dense coupons | 503 UNAVAILABLE; no candidate | 6.004 |
| Weighted purchase | Exact, including quantity/unit/unit price | 1.960 |
| Repeated purchases | Exact, including separate occurrences and coupon | 2.235 |
| Ambiguous date/unreadable total | Exact; retains missing/ambiguous fields | 18.733 |
| Printed prompt injection | Exact; no invented subtotal | 13.589 |
| Multilingual/zero tax | Exact | 2.860 |

All five returned candidates match the unchanged reference on every scored field and row: 25 summary-field checks and nine accounting rows. None needed outer-fence removal in this run. Successful request latency ranges from 1.960 to 18.733 seconds, median 2.860 seconds; spacing is excluded. This is not phone performance or stable service latency.

Operational exact completion is 5/6 (83.3%) versus the retained Qwen configuration's 4/6. Among returned Gemini candidates, 5/5 are exact, but that is conditional on receiving a response. Do not call this 100% overall accuracy or use the separate successful dense pilot to claim 6/6 for this run. The two configurations differ in prompt placement, schema enforcement, thinking and transport; this is not an isolated model-weight comparison. References were exposed during development; there are no held-out real purchases in this evaluation.

The six-attempt evaluation task is complete. A comparison containing six Gemini candidates remains unavailable (the private report's comparison_complete flag therefore stays false). This is a promising limited result, with service reliability still unresolved, not an unconditional integration acceptance. The prior pilot was exact on dense coupons, but the repeat failed before extraction; that demonstrates why availability must remain visible.

Offline verification reconstructs all six requests and five canonical candidates from retained raw outputs. Four additional tests pass: pilot-equivalent request, rejection of incomplete output, no repeat calls on resume, and stopping on a rate limit. All calls used the saved personal Gemini key. No real receipts, app changes, billing changes or paid fallback. Cumulative diagnostic/experiment POST count is 25 (19 image requests, six text-only), with all prior failures retained.

Recommended next task: explicitly accept this limited result for a fictional-only Simulator prototype under P8-03. Integrate the provider-neutral draft adapter, strict validation, cancellation and honest recoverable error handling; retain local recognition. Do not enable real Gemini receipt imports or claim privacy approval from this synthetic result. The provider-specific privacy decision and broader reliability validation remain separate gates.
