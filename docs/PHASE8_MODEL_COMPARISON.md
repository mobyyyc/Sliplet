# P8-02E — fixed-fixture vision model comparison

Approved 2026-10-26. Setup verified; comparison incomplete because inference failed. Fictional receipts only. No app changes or real-receipt upload path.

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
