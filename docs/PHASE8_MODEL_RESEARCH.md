# Phase 8 — model and connection research

Research date: 2026-10-23. This is a shortlist for experiments, not a measured accuracy ranking or a promise of ongoing free availability. Recheck model IDs, account quotas, client-use terms and data controls in P8-01. No provider account or key has been verified by this document.

## Recommended candidates

| Route | Candidate | Cost boundary | Role |
| --- | --- | --- | --- |
| Personal cloud API | Groq `qwen/qwen3.8-27b` | Free plan, subject to account quotas | First cloud proof after privacy approval |
| Private Mac | Ollama `qwen3-vl:8b` | No API fee; hardware/storage/energy required | Private comparison and fallback |
| Reserve cloud | Cloudflare Workers AI eligible vision model | Free allocation; stop when exhausted | Only if first cloud route is unsuitable |
| Fictional comparison | Gemini free API | Account-dependent free allowance | Fictional receipts only in this phase |

### Groq

The current Qwen model accepts images and advertises JSON schema output; the combined request must still be smoke-tested. It is a preview model, so removal or changes must be handled. The published free table lists 30 requests/minute, 1,000/day, 8,000 tokens/minute and 200,000/day; account limits are authoritative, and token limits mean this is not a promise of 1,000 receipts/day. Vision supports up to three images per request.

Sources: [model capabilities](https://console.groq.com/docs/model/qwen/qwen3.8-27b), [image API](https://console.groq.com/docs/vision), [free/account limits](https://console.groq.com/docs/rate-limits).

Groq describes limited content retention for reliability/abuse investigations, with account controls to opt out; usage metadata remains. Verify the applicable Zero Data Retention controls before approving real receipts and avoid stateful batch/file/fine-tuning features. A successful inference call does not verify these settings. Redaction and ZDR do not mean the provider cannot process the submitted image.

Source: [data handling and controls](https://console.groq.com/docs/your-data).

Use the supported HTTPS inference API with the user's personal credential. Direct iOS compatibility and intended client distribution terms remain P8-01 checks. No shared developer token or routing gateway is assumed.

### Local Mac

Ollama lists `qwen3-vl:8b` as a text/image model with an approximately 6.2 GB download. Download size is not peak memory usage; the previously inspected M5 Pro / 24 GB machine still needs a bounded-context memory and latency test. Freeze the downloaded artifact/version and use a small context suitable for a receipt, not the maximum advertised context.

Sources: [model variants](https://ollama.com/library/qwen3-vl), [upstream model](https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct).

Disable Ollama cloud features with `OLLAMA_NO_CLOUD=1`, use a local model rather than a cloud tag, and keep the service on loopback for Simulator evaluation. Local structured output is supported through a schema; correctness still needs validation. Do not expose an unauthenticated inference service to the LAN or internet. Optional physical-phone access needs a separately scoped authenticated encrypted pairing layer.

Sources: [local operation and networking](https://docs.ollama.com/faq), [structured output](https://docs.ollama.com/capabilities/structured-outputs).

### Cloudflare reserve

Workers AI documents a free allocation of 10,000 neurons/day, with requests failing after exhaustion on the free tier; paid plans have different charging behavior. Verify the chosen vision model is free-tier eligible before testing. This is a compute allowance, not a fixed receipt count. A potential candidate is `@cf/qwen/qwen3.8-27b`, subject to current model access. Testing the same underlying model on another provider is not independent model evidence.

Sources: [pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/), [model](https://developers.cloudflare.com/workers-ai/models/qwen3.8-27b/).

The documented stateless service does not train on submitted content and describes content deletion after processing, with safety/security/legal exceptions. Optional storage, batch and gateway logging features change the data path. Do not enable them merely for diagnostics. Verify personal API token scope and account identification requirements if selecting this adapter; never ask for an unrestricted account-wide credential when a scoped token suffices.

Source: [data usage](https://developers.cloudflare.com/workers-ai/platform/data-usage/).

### Gemini free comparison

The unpaid API terms permit product-improvement use and human review and warn against submitting sensitive or personal data. For this Canadian development context, reserve it for fictional samples even if ordinary identifiers have been redacted: purchases can still be sensitive. A paid service has different terms but is outside the current $0 budget. Confirm current model availability and free quotas before a fictional comparison; do not build this provider into the private-receipt UI in Phase 8.

Sources: [terms](https://ai.google.dev/gemini-api/terms), [pricing](https://ai.google.dev/gemini-api/docs/pricing), [limits](https://ai.google.dev/gemini-api/docs/rate-limits).

## Selection rules

Choose based on exact extraction on the existing corpus, safe failures, privacy, free access and practical latency. No recommendation here establishes that an LLM will recover the remaining errors. A larger or newer model is not automatically a better receipt reader.

Start with one cloud candidate and one private candidate, not a broad provider sweep. Labels stay outside requests. Compare image-only and image-plus-redacted-raw-OCR within a predeclared budget; evaluate raw output separately from validated drafts. Select a passing configuration and confirm it in actual imports before investing in product UI.

Each user supplies their own credential, pays any charges on their own account, and sees explicit provider/model status. Sliplet has no developer-funded fallback. A free-only development account must not be upgraded or configured for recharge. App-side request limits cannot guarantee a paid account's overall bill, especially when the key is used elsewhere.

Full agenda, user experience, schema, data storage, approval boundaries and acceptance gates: PHASE8_PLAN.md.
