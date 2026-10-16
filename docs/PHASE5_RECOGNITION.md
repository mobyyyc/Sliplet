# Phase 5 — Reliable receipt interpretation

2026-10-16. Main coordinates one approved task at a time. P5-01 approved and complete; P5-02 through P5-06 remain proposals awaiting individual approval. No phase-wide implementation authorization.

Goal: improve automatic interpretation and reduce correction work using on-device Vision, source-backed logic and focused assistance. No Apple Intelligence/cloud dependency. Keep existing merchant/date successes, provenance, independent full-source review, exact reconciliation and transactional Apply/Cancel. No guessing financial values from totals. Existing five checked receipts and two checked Costco transcripts are retained; additional manual annotation is scoped to genuinely unresolved evidence.

| Task | Scope | Acceptance |
|---|---|---|
| P5-01 — Failure map | Trace saved OCR, grouping, parsing, conversion and persistence; inventory annotation gaps | Complete reproducible field ledger, honest unresolved causes, no production changes. **Complete:** [report](PHASE5_FAILURE_MAP.md). |
| P5-02 — Sections and summaries | Contextual header/purchase/summary/payment roles; detached summary amounts; label variants and safe boundaries | Demonstrated failures improve without regressions or unsupported amounts; misleading keyword fixtures pass. Actual-app imports required. |
| P5-03 — Purchase assembly | Wrapped descriptions, SKU-prefixed rows, detached prices, quantities/unit prices and duplicates | More complete source-backed purchases without new wrong money, lost correct rows or collapsed duplicates. |
| P5-04 — Merchant resolution | Local alias directory, header-weighted evidence, unknown fallback, conservative retailer-specific routing | Preserve current successes; variants, misleading mentions and unknown stores covered with fictional fixtures. |
| P5-05 — Focused corrections | Connect unresolved reasons to existing targeted selection/reread/edit UI | Minimal scoped changes; evidence visible; Apply/Cancel and review gates intact; assisted results measured separately. |
| P5-06 — Full evaluation | Frozen candidate, actual Simulator imports, repeats, save/reopen, automatic and assisted comparison | Report gains/regressions and remaining limits; preserve accuracy safety gates. Independent claims require separately held-out receipts. |

Normal flow: import complete image, assemble a draft, resolve a short list of uncertainties, review and save. No mandatory multi-crop procedure. Treat OCR experiments as a separately justified response to demonstrated reading failures; do not repeat failed alternatives without a new hypothesis.

P5-01 findings refine subsequent work but do not authorize it. Keep legacy and strict metrics separate, resolve identities without price tie-breaks, and never relabel existing references merely to improve scores. Simulator behavior does not establish physical camera quality, phone latency or human review time.
