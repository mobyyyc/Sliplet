# Phase 6 — Verified recovery and less correction work

2026-10-17. **Planning approved; implementation not started.** Main coordinates one separately approved task at a time. This plan follows the negative accuracy result of [P5-06](PHASE5_ACCEPTANCE.md). It does not authorize new models, cloud processing, broad parser rewrites or phone installation.

## Starting point and goal

Frozen baseline: P5-05 production candidate `d6b871d`, evaluated in `private-receipts/evaluation/p5-06-final`. Five exposed receipts, two checked Costco transcripts, zero held-out purchases. Strict exact purchase pairs 43/66; legacy recovery 53/66; merchant/date 5/5 each; checked subtotal 4/4; total 3/5; fully correct receipts 0/5. Suggested-region amount rereading made 62 successful reads and recovered zero additional paired amounts.

The goal is a demonstrated recovery on existing receipts or a demonstrated reduction in correction effort. Passing fixtures alone is not an accuracy improvement. Phase 6 may conclude with a rejected experiment; do not ship a neutral or regressing recognizer merely to complete a milestone.

The summary audit found one missing total without an exact amount in saved OCR and one unresolved signed value. These are different hypotheses requiring source inspection. Corrected Costco text still leaves interpretation failures. Repeated descriptions and incomplete attribute annotations also limit the score; they are not automatically recognition errors.

## Proposed user experience

Import the full image once. Show the draft, original evidence and a short list of unresolved fields. For an uncertain field, open its relevant source region and offer editing or an explicit reread. A missing total should open the summary region; an item description should retain access to its entire printed row and neighboring context. Never require everyone to perform merchant/items/total crops in sequence.

If source information is truly absent or unreadable, say so and offer manual entry or a better photo. Do not fill a missing amount from arithmetic or silently remove a sign. Existing independent original review, exact reconciliation, drafts, and Apply/Cancel remain unchanged. This is a proposed direction; P6-04 determines whether any additional UI change is justified.

## Tasks and decision gates

| Task | Work | Deliverable and acceptance |
|---|---|---|
| **P6-01 — Resolve the specific failure evidence** | Reuse the P5-01 ledger and refresh only changed entries against P5-06. Inspect the two unresolved totals, the one paired amount discrepancy, the extra assembled description and existing unmatched-name groups. Trace original pixels, raw text, grouping, parsed value and draft. | Private case records with a suspected failure stage, supporting evidence, confidence and one falsifiable next experiment. Separate definite failures from ambiguous identity/reference coverage. No app change or new full-corpus audit. Ask only for a specific field/region if its interpretation cannot be resolved from prior checks. |
| **P6-02 — Recover summary fields** | Run only the experiments justified by P6-01. For missing OCR evidence, compare the original summary-region reading with a tightly bounded alternative region/preprocessing hypothesis; for signed output, inspect sign provenance and local label association. Compare baseline and candidate on identical source inputs. | Target at least one independently verified total recovery (3/5 to at least 4/5 on unchanged labels), preserving every previously correct checked field. Candidate must retain exact printed digits/sign and source links. If no safe recovery, retain production behavior and report a negative experiment; do not broaden rules to force success. |
| **P6-03 — Recover item descriptions and associations** | Address the source-backed extra candidate and P6-01-confirmed description/grouping failures. Separate product code from description only when source evidence supports it. Preserve duplicates and quantities; distinguish unit price from line amount. | Target at least one new strict exact description/amount pair above 43/66 on the original reference set, without losing prior correct fields or silently merging purchases. No stripping arbitrary tokens to match labels, price-based identity tie-breaks, or unsupported money. If the evidence supports only a user choice, keep it explicit rather than auto-accepting. |
| **P6-04 — Measure and simplify focused correction** | First walk through a small, named set of unresolved fields using existing controls. If a concrete obstacle is demonstrated, prototype the smallest correction-flow change. Compare old/new flows on the same fields, with Cancel/Apply and persistence tests. | Report applied field correctness, unresolved fields, deliberate selections and manual edits. A user's optional paired Simulator trial can measure active review time and actions; report learning/order effects. Automated action counts are only proxies. No claim of reduced human effort without human evidence. UI changes need a demonstrated obstacle and must not weaken final review. |
| **P6-05 — Final evaluation and decision** | Freeze the selected candidate. Repeat actual-app imports, save/reopen and the relevant targeted correction tests on the existing five receipts; compare automatic and assisted outcomes separately. | Publish baseline/candidate deltas, correct-to-wrong transitions, unresolved cases, provenance checks and limitations. Accept an automatic change only with a verified gain and no new unsupported values or lost checked successes. Declare unmet goals explicitly. Any normal Simulator/phone update is a separate user decision. |

P6-01 is the next proposed task and is **not yet approved**. P6-02 and P6-03 are conditional experiments, not promises that a field can be recovered. If P6-01 shows a planned experiment lacks evidence, revise its brief before requesting approval. An experiment that fails is complete as an experiment but does not satisfy the accuracy goal. Main reports result, commit, next task and approval request after every task.

## Evidence and scoring rules

Reuse all existing images, checked labels and transcripts. Do not ask the user to identify every receipt again. Request narrow adjudication only when a specific decision or score depends on unreadable text, disputed signs, duplicate identity or missing annotations. Keep old references immutable; save any additional human checks as a versioned supplement with an audit trail. Report original-reference scores alongside supplemented scores so improved annotation cannot masquerade as better recognition.

Keep labels out of the recognizer and crop-selection logic. Experiments may target the failed region for diagnosis, but any automatic region rule must generalize from source layout without seeing the expected answer. Distinguish human-drawn crops, automatic crops, candidate availability, explicit selections and final correctness. A matching sum does not verify a receipt. A correct candidate among several is not a recovered field.

Summaries and exact description/amount pairs are the initial scored scope. Quantities, units, SKUs, tax markers/rates and printed currency remain separately reported with coverage limits. Do not claim all-field accuracy from the existing incomplete labels. Preserve the visible CAD default as editable user context, not recognized currency.

Use fictional regression fixtures for misleading total labels, real negative/refund values, conflicting signs, multiple neighboring amounts, wrapped descriptions, SKU fragments, duplicates, missing geometry and subtotal-before-more-items. Add only tests relevant to the diagnosed change. Private images, OCR, prices, dates, coordinates and labels remain local and excluded from Git.

## Performance and stop rules

No wholesale reread of every correct item: the previous 62-read probe found no additional paired recovery. Any added pass must have a bounded trigger, cancellation and measurable benefit. Measure paired baseline/candidate runtime on the same Simulator/toolchain, alternate run order and report median and tail. Separate experiment duration from the normal import path. Default performance budget: no additional work on unaffected imports; if a proposed change adds a general import pass, return with evidence and a revised approval scope before integration.

Keep iPhone 15 Pro compatibility without Apple Intelligence. No Foundation Models, cloud inference, accounts, TestFlight or external model dependency in this plan. A new model would require a separate proposal covering demonstrated need, on-device compatibility and evaluation cost.

The original five receipts remain enough for development. They cannot establish general accuracy. A separately reserved purchase set would be needed for independent claims, and is optional rather than a prerequisite to these tasks. Phone camera quality, physical-device latency, human review time and broad accessibility certification remain separate evidence requirements.

## Phase exit

A successful accuracy outcome requires a verified gain on the unchanged references, retained prior successes and preserved provenance/review safeguards. A successful correction-effort outcome requires a measured paired human workflow, reported separately from automatic accuracy. If neither is achieved, report Phase 6's experiments completed with goals unmet and recommend a deliberate next decision; do not expand the phase indefinitely.
