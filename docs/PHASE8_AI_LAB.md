# P8-01 — vision AI contract and safe lab

Date: 2026-10-23. Status: local preparation verified; live connectivity verified; fictional extraction diagnosis and real-upload approval pending. No P8-02 recognition experiment or app integration is authorized by this status.

## Verified preparation

- Re-ran `evaluation/receipt-phase7-acceptance/check.py`: retained ten import/save/reopen captures, originals, evidence and frozen annotations verified. Repeated baseline remains 57/65 purchases, 3/5 totals, 4/4 checked subtotals, 4/8 adjustments and merchant/date 5/5. No new OCR or private cloud upload.
- Added isolated `evaluation/receipt-vision-ai`: schema, literal-extraction prompt, fictional fixtures, bounded smoke transport, hidden credential entry and status-only reporting.
- Offline contract check and 33 negative/positive harness tests pass. No production files changed. Visually inspected the fictional smoke image.
- Eleven fictional images prepared. Their challenge coverage is not a model test result. Only the small smoke fixture has a complete structured expected response at this stage; P8-02 expands exact challenge scoring before any real-corpus configuration selection.
- User confirmed the old exposed credential was revoked, a replacement is ready, and the account is on the Free plan. No credential is stored in this document, repository or harness output. The replacement is entered only by the user into Terminal. The user subsequently requested persistent storage; the lab now stores it in macOS Keychain, with a one-time save prompt and no plaintext copy.

## Live smoke status

The first fictional request returned HTTP 403/access denied. A later manual request succeeded: credential accepted, image/schema response received in 3.58 seconds, 1,157 prompt tokens and 556 completion tokens (1,713 total). The fictional exact-match check failed and validation flagged a total conflict. The earlier response was intentionally discarded, so the exact extraction error cannot be reconstructed from that status alone. Do not claim the application User-Agent definitively caused the recovery.

The diagnostic live run succeeded in 1.59 seconds and identified the exact omissions: merchant/date/currency/subtotal/total and both purchase rows matched; tax and payment rows were absent. Reconstructing those omissions locally reproduced every recorded mismatch diagnostic. The complete fixture passes reconciliation, while the omitted-tax fixture correctly raises total_conflict. Thus the observed failure is incomplete extraction, not a connection or arithmetic-validator failure. Its deeper cause is not proven by one run.

User approved a bounded prompt correction. The original wording about separating payments could be interpreted as excluding them from the lines array. Prompt v2 explicitly defines lines to include all supported monetary row kinds, separates recording a payment from counting it in accounting, and adds a full-image/footer completeness check. No fixture answers, prices, expected row counts or merchant identifiers were added. The schema, image and exact scoring remain unchanged. Original instructions are retained in prompt-v1.txt; the prior sanitized result is archived privately. The revised live comparison passed in 2.17 seconds: all five summary fields and all four expected rows matched, with no missing/extra rows or reconciliation issues. The saved prompt hash matches prompt v2. This is one successful fictional example, not evidence of real-receipt accuracy or broad generalization.

The user confirmed Zero Data Retention is enabled for inference. This is manual account confirmation, not API verification, and does not authorize real uploads by itself. The account's Free plan was also user-confirmed. Real payload preview and transfer approval remain separate.

## Provider feasibility findings

The official model page lists `qwen/qwen3.8-27b` as preview, text/image input, and JSON schema support. The structured-output page lists strict mode for this model. The vision endpoint accepts inline base64 images, up to three per request. These are documented capabilities; a live combined image/schema request has succeeded, with extraction correctness still under investigation.

Sources: [model](https://console.groq.com/docs/model/qwen/qwen3.8-27b), [structured output](https://console.groq.com/docs/structured-outputs), [vision](https://console.groq.com/docs/vision).

Free-tier status is user-confirmed; model access and request execution succeeded; exact account quota settings remain unverified. The harness never upgrades plans or follows retries. A successful request does not verify billing configuration. Groq documents a payment method requirement for upgrading to the paid Developer tier.

Source: [billing](https://console.groq.com/docs/billing-faqs).

**Direct consumer-app BYOK is not yet cleared.** Groq's services agreement allows API integration into customer applications and availability to end users, but also describes the services as not for consumer use. Its security guide recommends a trusted backend for client-side usage. Those texts do not explicitly resolve native, user-owned Keychain credentials. Developer laboratory testing and eventual ordinary-user account eligibility are separate decisions. Do not present the direct iPhone architecture as provider-approved or add a shared proxy to bypass the question. Before P8-04, establish support for the intended native BYOK use or propose a different provider/architecture for approval. Contacting provider support requires separate user authorization; none has been sent.

Sources: [services agreement](https://console.groq.com/docs/legal/services-agreement), [security guidance](https://console.groq.com/docs/production-readiness/security-onboarding).

## Privacy approval packet — proposed, not yet accepted

Recipient: Groq. Endpoint: `https://api.groq.com/openai/v1/chat/completions`. Model: `qwen/qwen3.8-27b`. No files API, batch, persistent conversations, hosted tools, remote images or provider cascade.

Proposed real-data transfer: user-previewed flattened receipt crop/tiles, with unnecessary member/payment/transaction identifiers, personal contact details and barcodes removed; optional OCR hints must come from the same redacted pixels. Merchant, date, purchases and money remain visible and sensitive. Original images, checked answers, saved wallet content and manual reference notes are not uploaded. Redaction does not make the remaining purchase record anonymous.

Before real receipts: confirm Zero Data Retention for this inference endpoint in the account's Data Controls, avoid persistence features, confirm the account remains free, preview the exact payload, and obtain specific user approval. Groq says ZDR disables content retention for reliability/abuse monitoring; usage metadata remains. An API success does not prove these controls. Record manual confirmation honestly rather than label it API-verified. Do not infer Canadian-only processing or a deletion guarantee beyond the applicable terms.

Source: [Groq data controls](https://console.groq.com/docs/your-data).

This packet permits no real upload until accepted. The present executable accepts only its bundled fictional image. P8-02 must separately implement a reviewed-payload-only runner after approval.

## Extraction contract p801-v1

Canonical result: merchant, date, printed currency, subtotal, total, ordered lines and warnings. Each top-level field has nullable value plus claimed evidence. Lines have unique local IDs; kind (purchase/return/discount/tax/fee/payment/change/other); literal description; nullable quantity, unit, unit price, printed amount and parent ID; claimed evidence. Unknown currency remains null; the app's separate visible CAD default is not inference output.

All money/numeric readings are decimal strings, parsed with exact decimal arithmetic. Do not synthesize a printed amount from quantity, unit price or total. Do not silently strip signs. Preserve codes/suffixes and repeated rows. Discount parent references may be absent and are not guessed from adjacency alone. Payment/change never contributes to purchase reconciliation. Subtotal and total are not item rows.

Evidence quotes and optional normalized boxes reference supplied image IDs, with origin top-left and [left, top, right, bottom]. Validate bounds/identity, retain transforms back to the original, and distinguish claimed from verified evidence. No source-reviewed boolean is accepted from the model. Model confidence is not calibrated and is not an acceptance gate.

Transport/shape failures: invalid credentials, permissions/model access, rate or quota limit, timeout, redirect, oversized response, duplicate JSON keys, malformed schema, refusal, incomplete output, invalid decimals or source IDs/boxes. These fail without applying partial fields. Semantically incomplete but structurally valid candidates retain missing values and review warnings. Correct JSON and balanced arithmetic do not certify image truth.

## Frozen P8-02 experiment proposal

Before first real score, record source/prompt/schema/model/configuration hashes privately; hold labels out of requests. Preserve the existing frozen-reference score. Do not alter descriptions or label boundaries just to meet the target. If a genuine annotation issue needs adjudication, report that separately with both baseline and candidate rescored against the same reference version.

Candidates: one approved Groq configuration first; one local Qwen3-VL 8B configuration only after download/runtime approval. No local runtime is currently installed or downloaded by P8-01. A free reserve provider requires an explicit revised proposal. Start with fictional challenges to select image-only versus image-plus-redacted-raw-OCR; keep selection separate from confirming on the exposed real corpus. Retain source-scope and unknown-field tests, not just arithmetic checks.

Image geometry policy to implement before scoring: orient using local metadata, apply a user-approved document crop, then flatten redactions. Scale down to at most 1,200 pixels wide (never upscale). For a height up to 1,600 pixels, use one image. Otherwise use 1,600-pixel-high vertical tiles with 160-pixel overlap, preserving normalized original coordinates. A maximum of four tiles is allowed; use at most two requests with two tiles each. Include a scaled full overview only when the measured free token budget permits; omit it by a fixed policy rather than per-receipt score. If four tiles cannot cover the receipt or printed characters become unreadable, stop and request a narrower crop/local review. Never truncate the tail silently. Overlap deduplication uses original occurrence, not name/price equality.

Budget: P8-01 at most three fictional smoke attempts/day, one per manual launch, no automatic retries. P8-02 proposal: at most twelve fictional calls per candidate across the two input variants before configuration freeze, then two independent passes over five real receipts with at most two requests each (20 real calls/candidate maximum). No private calls are included in P8-01. Respect account token limits as well as request counts; schedule conservatively and stop on 429/billing errors. Cap output at 3,000 tokens for smoke and preflight a documented larger bound only if long-receipt experiments need it. Truncation is failure, not a silent retry.

Scoring: use original-occurrence anchors and the frozen labels; independently report unresolved source association rather than selecting matches from expected text/amounts. Maintain the full denominator. Report raw output, canonical validated output and assisted corrections separately. Account for all rows, wrong signs, unsupported amounts, omitted totals, discount roles, model refusals and schema failures. Never count payment substitution or inferred totals as recovery.

Confirmation gates: at least 59/65 exact purchases, 5/5 totals, 4/4 checked subtotals, 8/8 checked adjustments and preserved merchant/date, with no lost previously correct field or unsupported money. A reproducible safe partial improvement needs explicit limited-integration approval, not a claim of complete acceptance. Two passes over five exposed receipts still provide zero held-out evidence. Record latency, request counts, input/output usage where available and human effort only when actually measured.

## Current next step

The diagnostic fictional run and bounded prompt correction are complete. Keychain storage was added at the user's request and native save/read/replace/delete tests passed with a temporary fictional credential. The user must enter their key once to populate the persistent entry; do not claim it was saved before verifying its presence. Account data controls are user-confirmed; present the packet above for real-upload approval when the experiment is ready. Record any model/API incompatibility before proposing P8-02. If account setup is delayed, retain the tested harness and mark the task awaiting that step rather than completed.
