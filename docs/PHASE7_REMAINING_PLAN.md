# Phase 7 remaining agenda — general receipt interpretation

Revised 2026-10-22 after the focused human review. This is a design update, not authorization to implement every remaining task. P7-01 through P7-04 remain completed; P7-05 through P7-09 are complete; P7-07 failed its promotion gate. Phase 7 is closed with partial results: its accuracy and total gates were not met. See PHASE7_ACCEPTANCE.md. Main requests approval before any next phase.

## Evidence and scope

The export contains 23 cases, all with source markings, amounts and notes. Optional following lines were absent in twenty cases; the review tool incorrectly blocked their checkboxes. Preserve the raw export and the user's explicit completion statement separately. No repeat of the whole review is required.

Source anchors resolve ten repeated-name identities: both retained app-import passes measure 55/66 exact purchase-description/amount pairs (83.3%), compared with 45/66 historically. This is a measurement correction, not an algorithm gain or a new OCR run. Remaining diagnostic cases are seven description mismatches, one wrong amount, two missing weight/rate purchases, and one reference purchase identified by the user as a discount. One description amendment also needs incorporation. Merchant/date remain 5/5, checked subtotals 4/4, totals 3/5 in retained evidence. Unreviewed metadata must not be credited as correct.

Recognition remains on-device. Use the five existing receipts first. No new model installation, cloud service, phone deployment or new-photo requirement is included. The target is at least 90% exact purchase pairs on the frozen corrected reference set, not a claim of 90% accuracy across every field or future receipts.

## General rules to investigate

| Human finding | General mechanism | Guard against |
|---|---|---|
| A name appears on separate purchase lines | Preserve each spatial occurrence and source identity; aggregate only as an optional display operation | Deduplicating identical names/prices, or copying the number of repeated lines into every line's quantity |
| An item has quantity/weight, unit price and a printed extension | Assemble an item group from compatible text roles, reading order, columns and units; retain distinct quantity, unit price and line amount | Using the unit price as the line amount, borrowing another item's extension, or calculating a missing printed amount |
| A discount follows an item | Recognize adjustment role from label/sign/layout, then link only with sufficient item evidence; retain unassigned discounts when ambiguous | Turning every negative line into a discount, assuming every following line belongs to the previous item, or treating a discount as a purchase |
| Department headers sit beside purchases | Identify section boundaries and prevent headers entering descriptions or crossing item associations | Removing genuine product words that resemble department names |
| Product codes and trailing letters are printed | Preserve source-backed description text; separate SKU/tax markers only when positional and syntactic evidence supports that role | Dropping suffixes to match expected names, or correcting unfamiliar names from a merchant dictionary |
| Some lines have explicit tax markers | Store printed markers and their evidence; use a documented receipt legend when available | Assuming all items at a merchant/department are taxable, assuming no marker means tax-free, or assigning a discount's tax solely from proximity |
| Subtotal, tax, total and payment rows differ | Classify summary roles using label tokens, layout and section context; distinguish subtotal from total and payment/change from purchase totals | Substring-only total detection, mistaking product names for summaries, or substituting payment amounts |
| Text is missing or misread | Retain bounded OCR alternatives and source coordinates; retry only objectively detected uncertain regions | Selecting candidates from checked answers, removing a sign to balance totals, or guessing a missing price |

These are hypotheses to prove, not universal assumptions derived from five receipts. Merchant-specific rules may describe a demonstrable format convention, never exact item names, amounts, dates, image identities or fixed photo coordinates. Unknown formats retain the generic path and explicit uncertainty. Runtime extraction must not access evaluation labels or human-marked regions; those may be used only in separately reported assisted diagnostics.

## P7-05 — Finalize evidence and freeze the measurement contract

Finish the already approved task. Reconcile the discount's reference kind and parent association, incorporate the explicit description amendment and preserve verified repeated-item anchors. Retain old references and record every amendment. Freeze references before tuning candidates.

Trace each remaining failure through OCR, grouping, semantic role assignment, association, draft conversion and scoring. Use supplied literal transcripts for scoped correct-text replays only; mark missing transcripts unavailable. Do not manufacture a complete-text oracle from expected answers. Ask one focused clarification only if a real unresolved source fact blocks a decision.

Deliver: versioned references, unchanged production baseline on those references, case-level private error ledger, aggregate public report, and a hypothesis/test matrix. Keep historical 45/66 and anchor-only 55/66 visible. If one purchase becomes a discount, report the revised denominator and separate discount accuracy rather than claiming a recognition gain.

## P7-06 — Generalize structural interpretation and item association

Within this approved milestone, evaluate bounded candidates independently before combining them:

1. Classify line roles: item descriptions, quantity/rate, printed extensions, adjustments, section headers and financial summaries. Preserve raw text and source geometry.
2. Associate item groups using relative geometry, reading order, compatible roles and boundaries. An amount cannot be consumed by two independent purchases. Ambiguous associations stay unresolved. Arithmetic corroborates an already printed extension; it does not create one.
3. Preserve repeated purchase occurrences; distinguish them from duplicate OCR observations using source overlap and reading provenance, not name equality.
4. Classify and conservatively link discounts. Separate description content from surrounding metadata while retaining printed suffixes. Trace and fix the wrong-amount case only after establishing its cause; if it is OCR, route it to P7-07.

Start with the two missed weight/rate purchases and demonstrated description boundaries, then test the adjustment and summary guards. Do not redesign unrelated app architecture. Require a measurable current-corpus improvement with no lost correct fields, false additions or source reuse. Reject neutral or regressive candidates. Record each candidate's individual contribution.

Deliver: tested generic parsing candidates, synthetic positive/negative fixtures, frozen-OCR before/after results and a remaining OCR-only error list. No automatic application of manual edits as reusable facts about other receipts.

## P7-07 — Recover text using evidence-driven local OCR

For failures that persist with missing/incorrect source text, evaluate a small predeclared set of alternatives: retained text candidates and narrowly targeted rereads located from OCR/layout uncertainty. Establish whether the correct reading is available, then independently test how the app could safely select it without labels.

Prioritize incorrect descriptions and the two missing totals. Preserve signs, printed extensions and observation provenance. Support Unicode/spacing variation only with explicit normalization rules; do not replace product text with known answers. Separate automatically located regions from human-marked diagnostic crops. If correct text cannot be selected safely, retain uncertainty and offer a focused assisted correction, scored separately.

Do not repeat failed broad crop/inversion or unchanged Paddle experiments. A new model or adapter needs a distinct hypothesis and approval. Deliver per-case availability versus selection results, actual accuracy gain, retry cost and a clear stopping decision.

## P7-08 — Integrate winners and verify everyday behavior

Integrate only passing candidates. Exercise actual Files imports, focused review, Apply/Cancel, draft save/reopen, and Finish using current originals. Preserve raw OCR, originals, source coordinates and user edits. Show targeted review requests for ambiguous associations instead of asking users to recheck every field unnecessarily; retain the independent source-review gate for finalization.

Measure import latency and retry frequency against the baseline on the same Simulator. No OCR on the UI thread or unbounded retries. Report Simulator timing separately from phone performance. Verify corrections never silently overwrite an existing saved edit, including after recognition retries.

Deliver: usable Simulator build, repeated import results, regression results and separate automatic/assisted accuracy. Phone installation remains separately requested.

## P7-09 — Final accuracy and generalization audit

Run repeated fresh imports on all five originals with frozen references and build. Primary target: ceil(0.90 × verified purchase count) exact description/printed-amount pairs. For 66 purchases that is 60; if corrected to 65 it is 59. Report the denominator change, reference-only gains and algorithm-only gains separately.

Financial gates: all five checked totals and all four checked subtotals correct, no loss of previously correct fields, no fabricated monetary values, and no duplicated or dropped source-backed purchases/adjustments. Report discount detection/linking separately and keep unverified metadata outside accuracy claims. If a gate is missed, report partial results rather than call Phase 7 accepted.

Generalization checks for each structural rule:

- Fictional fixtures with different names, prices, units, counts and merchant labels; no dependency on the five receipts' literal values.
- Geometry variation: translated/scaled boxes, different spacing, wrapped names and column shifts that preserve the underlying layout.
- Negative cases: ambiguous neighboring prices, missing extensions, returns versus discounts, multiple adjustments, repeated identical purchases, summary words within product names and section boundaries.
- Source-order/provenance checks and unchanged handling of unrelated receipts; isolate rules to show which one caused each gain or regression.
- Existing originals re-imported independently; transformed copies remain the same purchases and are not held-out data.

Five exposed receipts and synthetic tests cannot establish accuracy on unseen purchases. No generalization claim beyond this evidence. Defer collection of unseen receipts until the user approves it; do not delay this phase on new photos. Stop after reporting the actual gain and residual ceiling rather than extend Phase 7 with unproductive experiments.

## Workflow and next action

P7-05 completed with a frozen 56/65 baseline (86.2%). The next acceptance threshold is 59/65, requiring three actual recoveries; totals remain a separate gate. P7-06 now measures 57/65 (87.7%) with two weighted purchases recovered and one additional exact pair. P7-07 produced no safe accuracy gain; P7-08 verified ten actual import/save/reopen cycles and 28 passing native/UI methods; P7-09 has completed the final acceptance assessment without meeting the purchase or total gates. The remaining order is P7-05 → P7-06 → P7-07 → P7-08 → P7-09. Main owns review, commit/push and the next-task approval. No new chats or subagents are needed. This agenda changes the implementation strategy, not production recognition code.

P7-05 completion details and limitations are recorded in `PHASE7_FOCUSED_REVIEW.md`; its final results supersede the intermediate 55/66 measurement above.

P7-06 completion: `PHASE7_WEIGHT_ASSOCIATION.md` records the bounded production rule, 31 fictional checks, ten frozen-OCR replays and 46 native regression tests. P7-07 should include the wrong-amount OCR case alongside remaining description and total failures. Suffix deletion and speculative discount linkage were not promoted.

P7-07 completion: `PHASE7_OCR_ALTERNATIVES.md` records two fresh native passes at 57/65, no additional text candidates, 80 row rereads with zero recoveries and 14 regressive substitutions. Only three of eight failed purchase-row regions were covered. Production OCR is unchanged. P7-08 verifies the P7-06 improvement; it is not expected to close the 90% gap. P7-09 must report partial results if the acceptance gates remain unmet.

P7-08 completion: `PHASE7_WORKFLOW_VERIFICATION.md` confirms repeated actual imports at 57/65, unchanged source evidence, preserved draft/review gates and 28 passing native/UI methods. P7-09 may reuse these fresh captures if build/source/reference hashes remain unchanged; do not repeat identical imports without a new concern. The 59/65 and all-total acceptance gates are still unmet.

P7-09 completion: `PHASE7_ACCEPTANCE.md` records verified repeated 57/65 exact purchases, 3/5 totals, 4/4 checked subtotals and 4/8 exact adjustments. No new production changes. The final audit reused hash-verified P7-08 imports; Phase 7 work is complete but recognition acceptance failed. Further accuracy work requires a separately approved plan.

Next-phase planning completed: `PHASE8_PLAN.md` defines six gated tasks, with P8-01 evidence triage awaiting approval. No Phase 8 implementation has started.
