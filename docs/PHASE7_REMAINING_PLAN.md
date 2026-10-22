# Phase 7 remaining agenda — accuracy on the current receipts

2026-10-22. Planning and analysis only. Supersedes the P7-04 proposal to test unseen receipts next. No recognition changes or reference edits are authorized by this document; Main requests approval for each implementation milestone.

## What the current evidence establishes

Rebuilt the expired temporary parser tools from retained sources and reran the P7-04 offline verifier. The current parser reproduces the retained frozen and fresh-import results. This task did not take new photos or rerun Vision. The retained two fresh import passes, ten save/reopen checks and 88 passing tests remain the P7-04 evidence.

Exact purchase-name/price pairs are **45/66 (68.2%)**. The 21 uncredited purchases partition as follows:

| Category | Count | Meaning |
|---|---:|---|
| Duplicate descriptions with unresolved identity | 10 | Five duplicate groups have matching output counts and amount multisets, but no verified row anchors. The scorer deliberately does not use prices to choose identity. These are not ten demonstrated recognition errors. |
| Names not exactly contained in interpreted rows | 5 | OCR alteration, fragmentation or reference convention differences remain unresolved. Do not label all five as OCR failures without source inspection. |
| Name present but no parsed purchase | 3 | Two are followed by weight × rate and a printed extension. The remaining association needs its own trace. |
| Name present in an output with a different description | 2 | Investigate grouping and description boundaries against the original; do not strip codes to match labels. |
| Matched description, wrong amount | 1 | Trace the linked amount observation; distinguish misread digits from wrong association. |

There are also eight unrelated unmatched-output proxies across purchases/adjustments. They require source reconciliation and are not automatically invented items. The error partition above counts purchases only.

Merchant and date are correct on 5/5; checked subtotals are correct on 4/4, with one unscorable; totals are correct on 3/5. The two totals have established OCR-level failure causes: an omitted amount and a spurious trailing sign. The earlier checked transcript for the omitted amount does not contain that observation, so it cannot serve as complete-text parser evidence for that total.

Current labels leave 343 field outcomes unreviewed, including quantity, unit, SKU, unit price, tax marker, tax rate and currency. Consequently, this data cannot establish a 90% claim across every receipt field. Keep automatic recognition and user-assisted correction results separate.

## Target and measurement rules

Primary target: **at least 60/66 exact item description plus printed amount pairs (90.9%)**, using fixed, source-verified row identities. The numerator must not be inflated by correctly recognizing easy merchant/date fields or by accepting fuzzy product names.

Separate financial gates: keep every previously correct field; aim for all five totals and all four checked subtotals correct; account for each purchase, tax and discount without duplicates, dropped rows or invented amounts. Report unmatched output and false additions explicitly. Five receipts are too few for a general accuracy claim, even if the target is met.

If the ten duplicate rows are confirmed individually, the baseline could reach 55/66 (83.3%) without any algorithm change. This is only a conditional measurement correction. Under that scenario, five additional true recoveries are needed to reach 60/66. Do not report the extra duplicate credits as ten recognition improvements.

Freeze revised references once, then run the unchanged `c716c18` parser and every candidate against those same references. Also retain the original 45/66 historical metric. Revisions must record the exact human clarification; do not alter expected answers after inspecting a candidate to make it pass.

No honest guarantee of 90% can be made before the experiments. If raw evidence remains inadequate, record the ceiling and propose a targeted user-assisted region read, reporting it separately from fully automatic performance.

## Manual review needed

No whole-corpus reannotation. Preserve all five checked receipts, both checked Costco transcripts and the two confirmed trailing-code amendments.

Prepare one local focused review covering:

- The ten duplicate-name occurrences: confirm which original row each reference describes, without using expected prices as the matching shortcut.
- The eleven remaining failed items: show original row(s), existing checked values and current recognition side by side; request only unresolved transcription or boundary corrections. Some will need no new typing.
- The two total regions: reuse checked amounts and prior source findings, confirm locations, and add the entirely missing observation to a separately versioned complete-text diagnostic transcript. Do not replace the user's old transcript.

These are at most 23 focused checks before consolidating overlapping regions, not 23 full receipts. Optional quantity/tax/SKU verification is needed only if making broader field-accuracy claims; otherwise mark those fields unverified rather than treating them as correct.

## Revised tasks

### P7-05 — Finish the error map and focused reference refresh

Build the local review for the cases above. Record verified source anchors and a versioned reference amendment. Establish a fixed automatic baseline and a separate complete-correct-text replay for failed regions. For each case, identify the earliest divergence: image reading, grouping, interpretation, draft conversion or scoring/reference ambiguity. Stop treating a partially checked transcript as a complete oracle.

Deliverable: a fixed case ledger, old/new-reference baseline scores, human review coverage and ranked repair opportunities. No parser tuning while the references are being clarified. Requires approval to start.

### P7-06 — Recover source-backed item associations and boundaries

Prioritize the two weighted-item layouts plus the other unparsed item and two boundary mismatches where P7-05 proves the text is available. Extend the proven P7-04 approach only for explicitly supported layouts. Separate quantity/rate metadata from descriptions while retaining printed product codes and trailing letters. Copy printed extensions; arithmetic may corroborate a printed price but may not create one. Enforce unique geometric association, source conservation and source order.

Test each hypothesis on fictional ambiguous/negative examples, then the fixed five-receipt replay. Integrate only measured improvements without any lost correct fields or false additions. A candidate with zero gain does not become a production change. Do not assume all five cases are recoverable.

### P7-07 — Target the remaining OCR failures, including totals

Use P7-05's complete-text replay to identify cases where the parser succeeds with correct text. The current full-image and region readers retain only `topCandidates(1)`. Evaluate a bounded local experiment retaining alternate text candidates with their original observation geometry and reading provenance, plus a source-defined tight region that separates text from the dark-bar border where appropriate. Predeclare a small set of variants before evaluating; do not select variants or strings using checked answers.

Distinguish candidate availability from a safe automatic selection rule. Agreement between readings can support a candidate but is not independent ground truth. Preserve monetary signs; never substitute a payment amount, remove a minus or choose an amount because the receipt balances. If a safe selection rule cannot be established, keep the value unresolved and offer a separately measured assisted region read/correction.

Do not repeat the already-failed broad crop/inversion or unchanged Paddle benchmark. Paddle's tested configuration was worse under the existing parser; a new model/adapter would need a distinct hypothesis and approval.

### P7-08 — Integrate winners and verify the full app flow

Integrate only the P7-06/P7-07 candidates that passed their gates. Test the actual Files import, review, focused Apply/Cancel, draft save/reopen and Finish flow on the current originals. Preserve raw OCR, source coordinates, originals, typed fields and manual edits. Surface genuinely unresolved fields without confirming review automatically. Keep automatic versus assisted outcomes and latency separate.

Deliverable: a usable Simulator build and paired before/after results; no phone installation unless requested.

### P7-09 — Final Phase 7 acceptance and decision

Freeze the integrated build and score all five current receipts in repeated fresh imports against the same final references. Report exact item pairs, summary fields, false/missing rows, manual corrections needed and validation coverage separately. Keep the historical-reference score beside the clarified-reference score.

Pass only if the primary 60/66 target and agreed financial/no-regression gates are met. If not, report the achieved score, remaining cases and whether the limit is OCR evidence or interpretation. Do not extend Phase 7 indefinitely with neutral work. Testing unseen receipts is deferred until the user is satisfied with this current-receipt result and approves it separately.

## Workflow

P7-01 through P7-04 remain completed. P7-05 is no longer the final task or an unseen-receipt test: the remaining sequence is P7-05 → P7-06 → P7-07 → P7-08 → P7-09. Main reports evidence, commit, next task and asks for approval after each milestone. No new subagents or chats are required for this plan.
