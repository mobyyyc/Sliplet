# Phase 8 — optional vision AI with personal API connections

Redesigned 2026-10-23. **P8-01 complete for developer-lab preparation; P8-02 bounded experiment complete with failed acceptance gates; P8-02B corrective experiment stopped on a provider limit, with no measured improvement over local OCR in the completed subset; see PHASE8_CORRECTION_EXPERIMENT.md. Later milestones remain gated.** This replaces the targeted-OCR Phase 8 agenda committed in df8ee7b. Its P8-01–P8-06 definitions are superseded, not completed. Phase 7's results remain unchanged.

## Outcome and scope

Make receipt import substantially more accurate and easier to review by letting a vision-language model read the image and produce structured receipt fields directly. Keep the existing iPhone recognition path available and offline. AI is optional and independent of Apple Intelligence, including on the user's China-market iPhone 15 Pro.

The primary cloud product is bring-your-own-key: each user connects a supported provider in Settings and uses their own account allowance. No developer-funded shared key, Sliplet account requirement, receipt backend or mandatory subscription. Prefer direct HTTPS from the iPhone to the chosen provider, subject to confirming provider support and terms. Do not quietly introduce a proxy if direct access is unsuitable.

Development remains strictly $0 in provider charges: use verified free accounts/quotas and local Mac inference, without paid upgrades, automatic recharge or billing-backed trials. Local inference uses hardware, electricity and storage, rather than an API fee. Free quotas can change and may be exhausted. A user's own paid account could incur charges; the app must explain this and must not promise to enforce a provider-wide spending cap.

Latest privacy decision: redacted real receipts may be tested only after the specific provider, endpoint, settings and disclosure have been checked and approved. This planning permission is not permission to upload originals now or to every provider. Until that gate passes, cloud experiments use fictional receipts and private experiments stay on the Mac. Gemini's unpaid service remains fictional-only in this phase.

Use the five existing checked receipts and stored manual annotations first. No repeated full annotation exercise or new-photo prerequisite. Ask only about a particular unresolved printed fact or boundary convention. Simulator-first development; physical-phone acceptance is a separate scope, and installation requires a request.

## Baseline and acceptance contract

P7-09: 57/65 exact purchase kind/description/printed-amount matches (87.7%), merchant/date 5/5 each, subtotals 4/4 checked, totals 3/5, adjustments 4/8. Seven description mismatches, one wrong purchase amount, two missing totals and four unresolved discounts remain. Description mismatches include reference conventions, not just OCR mistakes. One unmatched-output proxy needs accounting; it is not automatically proof of hallucination.

Targets on the frozen benchmark: at least 59/65 exact purchases (90.8%), 5/5 totals, 4/4 checked subtotals and 8/8 checked adjustments, with no loss of previously correct fields, invented money or duplicate/dropped source occurrences. Preserve merchant/date results. These are separate gates, not a blended percentage. Currency and other unchecked fields remain outside claims. A visible editable CAD default is not recognized printed currency.

Measure raw model output, validated automatic draft and user-corrected result separately. Matching totals is not proof of correctness. Existing labels never enter inference requests. Keep the frozen score; any justified reference amendment needs a separate version and a baseline/candidate rerun against the same version. No deleting printed suffixes to improve the score.

Five exposed receipts and zero held-out receipts cannot establish general accuracy. Fictional cases provide structural stress tests, not unseen-real-receipt validation. New receipts and human correction-time trials remain optional later inputs.

## Model and provider strategy

See PHASE8_MODEL_RESEARCH.md for dated sources and limits. No model has yet demonstrated an improvement on Sliplet's receipts.

- First free-cloud candidate: Groq's image-capable Qwen3.8 27B, contingent on current free access, model capability and verified account data controls. Its preview status makes availability/version changes a real constraint.
- Free-cloud reserve: Cloudflare Workers AI, contingent on eligible model access and account/privacy checks. Test only if the first route is unsuitable; do not upload to several services by default.
- Private Mac candidate: quantized Qwen3-VL 8B through local Ollama. The previously inspected M5 Pro / 24 GB Mac makes a bounded trial plausible; actual memory, latency and accuracy must be measured. No raw Ollama port on the public network, no cloud-tag fallback.
- Gemini free tier: optional fictional-image comparator, not a route for this phase's private receipts.
- Paid APIs are outside the development budget. Provider adapters should be extensible, but Phase 8 does not build an exhaustive model marketplace or arbitrary custom-endpoint interface.

Prove one cloud candidate and one local candidate at most in the initial experiment. Test a reserve only when a documented failure justifies it and Main approves the change. If neither yields a safe improvement, stop before building the full AI interface; report the actual failure rather than schedule generic cleanup.

## Recognition design

1. Capture or import once. Preserve the encrypted original. Locally correct orientation/crop and detect poor quality. Offer a crop adjustment when useful; never require a merchant/items/totals cropping wizard for every receipt.
2. Prepare the selected mode's input. For cloud, produce a flattened, redacted image and any equally redacted OCR hints. Strip metadata and unrelated background. For local Mac, remain on the user's devices.
3. Ask the model for literal structured fields: merchant, date, printed currency, ordered purchases, quantities/units/unit prices when actually printed, line amounts, subtotal, taxes, discounts, fees and total. Separate payments/change/loyalty savings from receipt accounting. Missing values stay unknown; unsupported discount parent links stay unassigned.
4. Validate into a provider-independent candidate. Do not funnel the response through the old OCR row parser. Compare image-only versus image-plus-raw-OCR in the lab; old parser guesses are not truth. Vision remains useful for capture, OCR evidence and independent disagreement checks, not as a veto that makes the LLM repeat its errors.
5. Present one normal receipt draft. Flag unresolved differences and open the relevant original region for correction. Finish still requires independent full-source review and exact reconciliation; draft saving remains available.

Long receipts: preserve readable resolution using an overview and overlapping tiles within the chosen provider's image/token limits. Freeze automatic tiling before scoring. Start with one request; allow at most one additional bounded request for a long receipt or explicit focused retry. If the receipt cannot fit safely, explain the limitation and offer a crop/local review, rather than silently truncate. Deduplicate by original image occurrence/coordinates, not matching names or prices; identical purchases can be real separate rows.

The extraction schema uses exact decimal strings parsed locally, nullable unsupported fields, source image/tile references, literal descriptions and distinct purchase/adjustment/summary types. Model-provided quotations, coordinates and confidence are claims, not verified provenance. Map them to the original where possible and label unverified evidence honestly. Arithmetic detects conflicts; it must never fabricate missing amounts or choose a convenient sign.

Treat receipt text and model output as untrusted data. No tools, browsing, URL fetching or app commands available to the model. Bound payloads, output size, nesting, item counts, timeouts and concurrency. Refusals, invalid schema, truncation and implausible results are recoverable failures, not partially successful final receipts.

## Connection experience

Settings → AI recognition begins with Not connected and Connect a provider. Keep local recognition usable throughout.

Flow: choose provider → read concise data-use/free-allowance information → open official key instructions → paste concealed key → select an approved image-capable model → explicitly run a tiny fictional verification request → confirm privacy settings → enable AI. Explain that the verification consumes a small amount of the user's allowance. Do not read the clipboard automatically or request keys in chat.

Track credential acceptance, image/model capability, last successful check and privacy confirmation separately. Connection states: Not connected, Checking, Ready, Invalid/revoked key, Model unavailable, Rate limited, Allowance exhausted/billing required, Offline and Service unavailable. Show the selected provider/model and last verification time. Ready means the latest check passed, not guaranteed future availability. A successful API call does not prove Zero Data Retention; use account evidence where available, otherwise label the user's confirmation accurately.

Actions: Test connection, Change model, Replace key, Provider usage dashboard, Disable AI and Disconnect. Disable preserves the credential but stops future AI requests; Disconnect removes the stored credential and cancels pending work. Explain provider-side revocation separately. Test a replacement before replacing a working key, unless the user explicitly removes the old one. Never show raw provider errors that could expose a key or receipt.

Use non-synchronizing device-only Keychain storage appropriate to foreground authenticated use; no UserDefaults, app bundle, source control, receipt backup, analytics or logs for keys. Store only nonsecret connection preferences outside Keychain. No silent system-clipboard clearing, which could remove unrelated user content.

Offer Ask each time initially; after setup, the user may choose Use AI by default. Show the active method/provider on import with a switch to local. Initial app version supports the proven cloud provider, not every researched service. Do not show unsupported models as working choices.

## Privacy and simplified import UX

Before a cloud upload, preview exactly the redacted image that will be sent, state the recipient and let the user adjust redactions or cancel. Start with a preview on every upload; evaluate any reduced-friction consent design separately. Retain merchant/item/price evidence needed for recognition. Remove unnecessary membership/card/transaction identifiers, personal contact information and barcodes where possible, without erasing product codes or monetary signs. Redaction is fallible; purchase contents remain sensitive and must not be described as anonymous.

A key's validity is separate from provider privacy approval. Record provider, endpoint, relevant policy/settings confirmation and consent version locally. Changing providers or material data practices requires renewed disclosure. No silent cloud fallback from Mac/offline mode, no provider cascade, and no background scanning of the wallet. Existing receipts are reprocessed only by explicit action, with Apply/Cancel and preserved edits.

Progress: Preparing image → Reading receipt → Checking fields. Avoid fake percentages. Cancel immediately restores user control; explain when an upload has already occurred and cannot be recalled. An error retains the photo and offers Retry or Use local recognition. The user does not have to import again.

No chatbot page or second competing receipt editor. Use existing paper styling, Liquid Glass controls, accessible labels, consistent native control sizing, dark/light modes and reduced-motion behavior. Keep the original accessible. AI status appears during processing or in provenance details; do not clutter saved receipts with technical labels. Never mark source review complete merely because AI or arithmetic passed.

## Data and execution architecture

The iOS client uses a provider-neutral recognition protocol and canonical draft validator. A personal key authenticates directly to an allowlisted provider over HTTPS where supported; prevent cross-host redirects from carrying credentials. Use ephemeral networking without receipt-bearing disk caches, and no provider file-upload/batch/conversation features requiring retained application state. Confirm the selected SDK or transport does not log payloads. Hosted processing is not end-to-end private from the provider.

No shared developer secret or Sliplet receipt server. If a provider requires a backend or disallows the intended personal-key client, omit it or propose a new reviewed architecture rather than ship a secret proxy. Do not deploy a free Worker gateway merely because one is available.

Keep originals, accepted fields and provenance in the existing encrypted receipt store. Record provider/model identifier, available model revision, schema/prompt version, user-versus-model origin, original-coordinate references and relevant consent record. Do not persist full prompts, hidden reasoning or raw responses in production. Temporary request/response data is discarded after use; crash cleanup must cover temporary image files. Explicit debug evidence stays private and locally protected, outside Git. Backup retains accepted receipt data/provenance, never credentials or temporary payloads.

One request at a time initially, bounded retry policy honoring rate limits, and no automatic retry of ambiguous transmitted requests that could charge twice. Avoid polling the account while idle. Show only usage actually reported by the provider; local request counts are not account balances or spend guarantees. Free-only development stops on quota/billing errors and never upgrades or rotates accounts to evade limits.

Cancellation, app lock/backgrounding, provider changes and disconnected keys invalidate the in-flight session. Late responses cannot overwrite edits, save a receipt or unlock the app. Preserve existing Face ID behavior and transactional Apply/Cancel semantics.

Mac inference starts as a private Simulator evaluation tool on loopback with cloud features disabled. Shipping a phone-to-Mac connection is conditional on meaningful local results and user demand: it requires explicit pairing, local-network permission, authenticated encrypted transport and a reachable awake Mac. Do not expose unauthenticated Ollama or add a public tunnel. Without the Mac, local iPhone OCR remains available. This is not an on-iPhone LLM or an Apple Intelligence dependency.

P8-01 implementation findings and current gates: `PHASE8_AI_LAB.md`. In particular, Groq native consumer BYOK eligibility remains unresolved; documentation of an HTTP API does not itself approve this distribution model.

## Ordered milestones

### P8-01 — Freeze the contract and prepare a safe AI lab

Define canonical output schema, literal/source semantics, error taxonomy, fictional challenge set, fixed prompts/tiling, candidate/model limits and a bounded evaluation budget. Confirm the baseline artifacts and reuse existing checked references without exposing them to models. Verify current free access, direct-client eligibility and privacy controls for the first cloud candidate. Present the exact provider/data disclosure for approval before any real cloud receipt request.

Prepare a minimal evaluation harness only, using local models after approved installation and fictional cloud smoke checks after credentials are configured securely. Benchmark setup must not become a full connection UI. Verify image-plus-schema support rather than trusting advertised compatibility. Capture account controls without exposing keys.

Deliver: reproducible protocol, privacy/budget checklist with actual findings, fictional smoke result and precise P8-02 proposal. If no safe free cloud account is available, proceed with a private Mac experiment, not a paid upgrade.

### P8-02 — Prove real accuracy before UI investment

Use all five originals and frozen labels, two independent passes per bounded candidate/configuration. Real cloud use requires P8-01's provider approval and reviewed redacted inputs. Keep labels outside requests. Measure image-only against image-plus-OCR only within the predeclared small comparison; freeze the selected configuration before confirmation. Report redaction/tiling failures as part of the product path, not remove them from the denominator.

Evaluate exact purchases, missing/extra rows, money, totals, adjustments, source claims, refusals, malformed outputs and instability. Include fictional repeated items, product names containing total, coupons, returns, long receipts, Chinese/English text, blurred digits and receipt-embedded instructions. Record cold/warm Mac memory/latency, cloud latency/token usage and correction actions; do not present scripted actions as human time.

Promotion requires a reproducible genuine improvement without previously correct-field loss or new unsupported money. Full acceptance still requires every target above. If only partial improvement passes, Main presents that limited result and asks whether to integrate it; do not call 90% purchases a complete receipt-accuracy pass. If no candidate safely improves results, stop before P8-03–P8-06 and close with evidence in P8-07. A model change requires a bounded revised proposal.

P8-02 result (2026-10-24): the first Groq configuration failed acceptance. See `PHASE8_ACCURACY_EXPERIMENT.md` for measured failures and the proposed P8-02B corrective experiment. Do not start P8-03 without a passing or explicitly accepted limited result.

P8-02B result: two completed real receipts score 33/36 purchases, equal to the same-subset baseline, with date/adjustment regressions. A third request was rate-limited; seven were not run. P8-02C is proposed in `PHASE8_CORRECTION_EXPERIMENT.md` and requires approval. P8-03 remains gated.

### P8-03 — Integrate the winning extraction path

Build the provider-neutral recognition interface, selected adapter, schema/semantic validation and canonical draft integration. Preserve immutable originals/evidence, exact money semantics and existing user edits. Add source/conflict handling without the old OCR parser becoming a bottleneck. Keep local recognition intact; no default mode change yet.

Verify actual Simulator import → draft → save/reopen, invalid/truncated/refused responses, repeated source occurrences, prompt injection, cancellation and late response rejection. The integrated path must reproduce the lab gain; otherwise stop and diagnose before UI expansion.

### P8-04 — Personal API connection and truthful status

Implement the Settings flow and connection states specified above for the proven cloud provider. Securely manage keys and model selection; fictional verification only. Preserve a usable disconnected/local experience. Add privacy confirmation separately from connectivity and a provider usage link rather than invented balances.

Verify revoked/invalid keys, model removal, quota/rate errors, offline mode, account replacement, disconnect during a request, restart, backup exclusion and sanitized diagnostics. Confirm requests use the user's key exclusively, with no developer-account fallback. If only the Mac candidate passed, this cloud UI is deferred and the milestone is explicitly replanned for the proven local mode.

### P8-05 — Private upload preview and one coherent review flow

Implement local metadata removal and flattened redaction, exact-payload preview, provider disclosure, recognition choice, useful progress and recoverable errors. Integrate with the existing camera/Finder/Photos routes and standardized receipt editor. Offer a focused crop only when useful, not mandatory multiple crops.

Verify that both image and optional OCR hints are redacted; private identifiers never reappear through metadata, prompts or logs. Test long receipts, manual redaction corrections, cancellation before/after transmission, preserved photo/edits, CAD-default labeling and review gates. Record whether normal imports require fewer correction actions; measure real human effort only when the user performs the test.

### P8-06 — Reliability, privacy and device readiness

Audit the entire opt-in path: network/session lifecycle, cache/temp cleanup, request bounds, rate limits, key isolation, Face ID lock, restore, model/provider changes, accessibility, dark/light mode and UI responsiveness. Measure waiting and interaction stalls separately; cloud latency is not UI frame lag. No claim of zero lag from a passing test suite.

Validate the direct personal-key route on Simulator, then offer an explicitly approved iPhone test. Mac-to-phone pairing is conditional, not a mandatory companion-app project; ship it only if its benefit and scope are approved. No hosted proxy/account system is needed for the initial personal-key release.

### P8-07 — Acceptance, release decision and next boundary

Reproduce final import/save/reopen accuracy with the same references and selected configuration; reuse evidence only when inputs/build/configuration still match. Report all accuracy gates, regression cases, rejected candidates, schema/error rates, latency/quota use and automatic versus assisted outcomes. List any provider privacy setting confirmed manually rather than by API.

Classify the result honestly: all gates met on the exposed corpus; useful partial optional beta with explicit approval; or not worth integrating. No unseen accuracy claim. Maintain local OCR and rollback path. Offer the next test version and a short test checklist; physical installation is separate. New unseen receipts are a proposed next validation step, not a prerequisite silently added to this phase.

## Workflow and exclusions

Main is the only required coordination chat. One explicitly approved milestone at a time; Main reviews, commits/pushes, reports what finished/current milestone/commit/next task and asks approval. No new task chats or subagents are created by this plan. External privacy approval can be needed inside an approved milestone because it authorizes a specific transfer, not routine implementation choices.

The original redesign changed documentation only. Approved P8-01 now adds an isolated fictional-only lab; see its status report for verification results. No models installed, private receipt uploads, production changes or phone installations are included in this preparation. No Phase 3 visual redesign, new PaddleOCR sweep, paid provider subscription, cloud wallet sync, automatic original-review checks, hosted developer key, or unrestricted custom model endpoint is in scope.
