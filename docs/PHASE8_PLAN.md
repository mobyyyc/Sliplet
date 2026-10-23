# Phase 8 — targeted accuracy recovery

Designed 2026-10-23. **Planning approved; no implementation milestone started.** Main requests approval for each task. No new chats, agents, downloads, phone installation or production changes are included in this planning approval.

## Objective and starting point

Improve actual automatic receipt fields while reducing the manual effort for failures that cannot be recovered safely. Automatic and assisted results are separate. Keep recognition on-device and usable without Apple Intelligence. Use the five existing checked receipts first; no whole-corpus manual review or new-photo prerequisite.

P7-09 verified two passes at 57/65 exact purchase pairs, merchant/date 5/5 each, checked subtotals 4/4 and totals 3/5. Four of eight checked adjustments are exact: two discounts and two tax rows; four discounts are unresolved. Seven purchase descriptions and one purchase amount mismatch. One unmatched-output proxy remains. Currency and other unreviewed metadata do not support an all-fields score. These are exposed development receipts, with zero held-out data.

Success target remains at least 59/65 exact purchase pairs, all five checked totals and all four checked subtotals, and complete checked adjustment accounting with no unsupported money or regression. A purchase-score pass alone does not mean financial accuracy passed. No promise that this phase will meet those targets.

## What changes in the approach

1. Distinguish reference conventions, OCR characters, grouping/association and adjustment semantics before choosing code changes. Seven description mismatches are not seven proven OCR failures.
2. Reuse retained observations before buying another round of expensive inference. Inspect what each engine actually read separately from what the parser accepted.
3. Test discounts separately from OCR. Correct numeric text can still be assigned the wrong role; a new reader cannot repair that automatically.
4. If a text experiment is justified, separate recognition of a known region from full-image detection. The earlier fixed Paddle-plus-parser configuration failed; this is not permission to rerun it unchanged or choose models by private scores.
5. Ship only an independently useful candidate. If automatic recovery fails, report the limit and seek approval for a narrowly assisted fallback, rather than disguise human corrections as recognition gains.

## P8-01 — Resolve the remaining causal questions

**Scope:** an offline evidence audit of the existing residuals, not a fresh OCR sweep or another full annotation tool.

Use P7-09's eight purchase mismatches, two total failures, four unresolved discounts and unmatched-output proxy as the case list. Trace original pixels, retained Vision observations, retained Paddle observations where available, grouping, parsing and persisted draft values. Preserve original-coordinate/source identity. Record the earliest demonstrated divergence and mark uncertain causes explicitly.

For each case answer:

- Does the exact checked text/amount exist as a literal observation or a defensible sequence of source fragments?
- Is the difference a printed suffix or description-boundary convention, a missed/misread character/sign, or a field/association error?
- For discounts, is the sign and adjustment role printed, what context establishes it, and is parent identity actually known?
- Did the prior automatic reread cover the relevant region? Was alternative-engine text correct but rejected or misgrouped?

Existing human transcripts/notes remain authoritative within their checked scope. Do not manufacture a complete transcript or assume omitted follow-up text was absent. Ask one small batch of focused questions only when a specific unresolved source fact affects the experiment. The user need not identify every receipt again.

**Deliverable:** private case matrix; aggregate cause counts; one predeclared protocol for P8-02 and one eligibility decision for P8-03. No recognition code change. Keep this bounded to the existing residual list.

**Reference policy:** retain the original frozen v3 benchmark and 57/65 baseline. If a source check proves an annotation correction, create a separate version with a recorded reason; rerun both old and candidate parsers on that same version. Report reference-only movement separately, never as algorithm improvement. Keep old-benchmark results alongside it. Unresolved convention differences remain visible.

**Exit:** if no defensible candidate exists for a workstream, mark it blocked by evidence and propose skipping it. Do not create generic cleanup tasks as substitutes.

## P8-02 — Prove discount role recognition independently

**Hypothesis:** at least one unresolved adjustment has usable source text but fails because role classification relies on an incomplete row/context interpretation.

Use P8-01's source-backed cases to define a conservative adjustment group: explicit promotion/discount indicators, printed sign or established layout semantics, relative geometry, section boundaries and source ownership. Detect an unassigned discount separately from linking it to a purchase. Parent identity may remain unknown; no inferred tax allocation or forced parent link. A generic negative number is insufficient evidence to distinguish a discount from a return. Do not change an unsigned amount's sign merely to balance a receipt.

Run a test-only candidate against frozen OCR first. Include fictional explicit discounts, unsigned promotion displays with genuinely supported semantics, returns, negative totals, product names containing discount-like words, repeated amounts, multiple adjacent adjustments, wrapped labels, missing/ambiguous signs and competing parent items. Vary values and geometry; never match exact private item names, prices or image coordinates.

**Promotion gate:** at least one additional exact checked adjustment from the 4/8 baseline in both passes; no loss of correct purchases or summaries; no duplicate source consumption, unsupported sign changes or extra adjustment on negative fixtures. Report classification and parent-link accuracy separately. A passing subset may proceed; four recoveries are not assumed.

**Stop:** a failed candidate stays outside production. One bounded candidate, with no post-hoc threshold sweep. A second mechanism requires a revised proposal and approval.

## P8-03 — One distinct local text-recovery proof, conditional

Start only if P8-01 identifies either useful retained alternative text or a credible detection-versus-recognition failure. Do not repeat P6 inversion/anchor-agreement policies or P7's unchanged full-image Paddle and tight Vision row-reread configurations.

Choose exactly one branch before scoring:

- **A: observation adapter.** If retained alternative-engine text already contains a missing correct field, test a geometry/source-preserving adapter that accommodates that engine's segmentation. Keep literal characters and signs; do not repair strings from labels. Prove automatic association/selection using image evidence only. No new inference is needed for the initial proof.
- **B: recognition-only regions.** If full-image detection/segmentation is the demonstrated obstacle and no useful retained reading exists, propose feeding original-image regions into the existing pinned local recognizer's recognition stage, bypassing its full-image detector. Confirm the retained model/runtime supports that interface before implementation; otherwise stop and request a revised protocol. No new model or runtime download is implicitly authorized.

For B, define regions using only runtime observations and layout: total-label anchors with full sign margins, purchase-column geometry and parser structural gaps. State how confidently wrong text would be found; low OCR confidence alone failed to cover most residuals before. Freeze region policy, padding, orientation, runtime/model and candidate-selection rules on fictional fixtures before private inference. Limit to four regions per receipt, one alternate read per region, no recursive retries. Log uncovered failures explicitly.

Human-marked regions may be used in a separate diagnostic to measure candidate availability, but never credited as automatic localization or automatic recovery. No user text or checked values enter runtime selection. If coverage is poor, report it rather than expand crops after seeing expected answers.

Selection must define when to retain the original, accept source-backed new text, or abstain. Preserve an existing correct field in controls; do not simply prefer whichever engine matches the answer. Conflicting signs remain unresolved without sufficient new evidence; repeated same-engine reads are not independent proof. No decimal insertion, trailing-minus stripping, payment substitution or balancing-based amount choice.

**Promotion gate:** at least one new exact purchase pair or checked total in both passes, with no lost previously correct field or new unsupported money. State separately whether purchase accuracy reached 59/65 and totals improved. Candidate availability without a safe automatic selector fails promotion. Include genuine negative/refund and competing-number controls. Report end-to-end Simulator cost and coverage, not just crop speed.

**Stop:** no automatic engine/model sweep. If both branches lack justification, skip this task and explain why. A model change would need its own explicit approval.

## P8-04 — Minimal assisted recovery, only if needed and approved

This is conditional user-facing work, not an automatic accuracy experiment. First check whether existing focused correction and region-reread controls already suffice. If so, retain them and omit this milestone.

For unresolved cases, propose one contextual request at a time: mark the troublesome region, confirm a source-linked candidate, or enter a missing printed value. Do not require a fixed merchant/items/totals crop sequence for every receipt. Keep original-photo context, source provenance, explicit Apply/Cancel and saved manual edits. If a read fails, do not repeatedly ask for the same crop; permit direct correction or Save draft.

Keep the independent full-source review and exact-reconciliation Finish requirements. An assisted value is marked as user-confirmed, never automatic recognition. Ask for a brief optional user trial only after the interaction is reviewable; distinguish real user correction time from scripted taps.

**Gate:** demonstrated reduction in correction actions for a defined difficult case compared with existing controls, with cancellation, reopening, retry/manual-edit preservation and accessibility checks. If there is no practical benefit, do not add another screen or setting. Human timing remains unmeasured unless the user performs the trial.

## P8-05 — Integrate only passing candidates

Depends on successful P8-02/P8-03 or separately approved P8-04 work. If none passes, skip integration and go directly to closure.

Integrate each candidate separately so its effect is attributable. Use an isolated Simulator with existing originals and fictional controls. Verify import → review → explicit correction → draft save/reopen → Finish. Preserve originals, observation transforms, evidence and existing user edits. Cancel in-flight work safely; keep OCR off the main actor. Do not overwrite a user's correction when later recognition completes.

Compare baseline and integrated imports on the same Simulator/build conditions, two passes in alternating order. Record total extra reads, median/max import time and interaction stalls. Default experiment budget: at most four alternate region reads per receipt and no more than 1 second added median / 2 seconds added maximum end-to-end import latency; failure requires an explicit decision to keep it user-triggered or reject it, not silently relax the budget. Simulator findings do not establish iPhone performance.

**Gate:** reproduce the candidate's automatic gain on actual saved/reopened imports; no correctness/evidence regression; relevant native/UI checks pass. No normal wallet or phone update without a separate request. Do not repeat unchanged broad test suites just to fill a milestone.

## P8-06 — Final acceptance and stopping decision

Reuse P8-05 captures if code, references and input hashes still match. Otherwise rerun only invalidated evidence. Publish separately:

- Frozen-benchmark exact purchase score and any separately adjudicated-reference score, with both baseline and candidate using identical references.
- Merchant/date, checked subtotal/total and adjustment outcomes; parent links and unreviewed metadata excluded from claims.
- Actual recoveries, new errors, unresolved fields, source-accounting failures and reference-only changes.
- Automatic results versus explicitly assisted corrections and any measured human effort.
- Simulator timing, read counts and scope limits: five exposed receipts, zero held-out unless separately approved.

Full current-corpus acceptance requires at least 59/65 frozen exact purchases, 5/5 totals, 4/4 checked subtotals, complete checked adjustment accounting and no regression/unsupported money. A reference correction cannot retroactively turn a failed frozen-benchmark target into an algorithm win. If source review proves the old target penalizes faithful output, present both results and ask to agree the future contract explicitly.

Close as partial if any gate remains unmet. No automatic Phase 9 or indefinite extensions. New unseen receipts are optional for this development phase but necessary before making generalization claims; transformed copies are not held-out purchases.

## Approval sequence

**Next proposed task: P8-01 only.** After each task, Main reports what changed, measured result, commit message and next proposed task, then asks approval. P8-02 and P8-03 use separate proofs; one may proceed even if the other fails, but only after its own approval. P8-04 is conditional; P8-05 is conditional on a winner; P8-06 can close early when experiments fail.

This plan adds documentation only. It does not authorize executing all six tasks, installing dependencies or sending work to other chats. Existing private reference files remain stored; no repeated whole-receipt manual check is requested.

Evidence consulted: PHASE7_ACCEPTANCE.md, PHASE7_WEIGHT_ASSOCIATION.md, PHASE7_OCR_ALTERNATIVES.md, PHASE7_COMPATIBILITY_AND_RESULTS.md, PHASE6_TOTAL_PROBE.md and PHASE6_DECISION.md. These are retained local results, not claims about newly released external tools.
