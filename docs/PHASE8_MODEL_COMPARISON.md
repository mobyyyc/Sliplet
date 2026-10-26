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

The first fictional inference request returned HTTP 503 after 44.816 seconds. A separate read-only model metadata request succeeded and confirmed `models/gemini-3.8-flash` supports `generateContent`. That validates model metadata access, not inference or billing state. Main checked the official troubleshooting guidance and announced one bounded recovery after backoff. The identical recovery request timed out after 60.077 seconds. Both attempts are retained; zero model completions were received. No further requests were made.

Google recommends bounded backoff for transient 503 errors. Its troubleshooting page also says Gemini 3.6+ ignores custom temperature values; therefore the identical requested zero temperature is not an assertion of identical sampling behavior across providers. Provider-default thinking can affect latency. A timeout alone does not establish whether the server completed the request. We cannot infer whether capacity, the compatibility endpoint or inference latency caused these failures from the available safe diagnostics.

Source: [Google troubleshooting and retry guidance](https://ai.google.dev/gemini-api/docs/troubleshooting).

**P8-02E is not complete.** Only the first of six distinct cases was attempted (twice); five cases were not attempted. Gemini has no measurable accuracy result. Do not describe it as scoring zero percent or as worse than Qwen. Qwen's retained 4/6 exact cases remain the comparison baseline, not a winner against an unavailable model. No real images were uploaded and no app recognition changed.

## Verified preparation and continuation

The Gemini Keychain entry is present and separate from Groq. The user confirmed Free tier/billing disabled; no independent billing API verification was performed. Seven local tests pass. Offline verification reproduces both exact image-only payloads, confirms the only body difference versus the retained baseline is the model ID, checks the frozen source/configuration and fixture hashes, and verifies no original failure was overwritten. Raw output and credentials are absent from committed evidence; the public result records safe failure categories and incomplete status.

Continue this same milestone when inference is available; do not dispatch a new app-integration task. The saved key need not be entered again. Before another inference attempt, explicitly review the stopped-run budget and preserve these attempts. A longer timeout or native stateless endpoint may merit a separate diagnostic configuration; neither has been tested here. No recurring polling or scheduled retry was created.
