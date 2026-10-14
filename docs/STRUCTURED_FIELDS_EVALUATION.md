# P4-04 — Structured fields and currency context

Accepted as a bounded implementation on 2026-10-14. The fully automatic accuracy goal remains unmet. Five exposed development purchases, zero held-out purchases; no generalization or phone-performance claim.

## Changes

New imports with no printed currency use the user's visible, editable CAD default. Conflicting printed currencies remain unresolved. Default/user-selected context is recorded only in the editable draft, never in immutable OCR or parser evidence. Existing drafts are not silently changed. Currency edits reinterpret the entered amounts without exchange conversion; incompatible precision blocks saving rather than rounding or losing unit prices.

The parser retains explicit product codes, tax markers, supported weight units and unit prices, and explicit tax percentages (including zero). Quantity/rate association still requires exact printed extension evidence. Optional fields survive edits, encrypted save/reopen and portable backup/restore. Decimal commas with exactly two fractional digits are supported; missing separators, unclear promotion codes and ambiguous summary signs remain unresolved. A verified text total can improve without changing a bad OCR reading from the original image.

## Measured results

| Measure | Before | After |
|---|---:|---:|
| Actual Simulator imports | 10/10 | 10/10 |
| Stable repeat pairs / draft round trips | 5/5 each | 5/5 each |
| Parser exact purchases | 53/66 | 53/66 |
| Parser exact lines, all kinds | 57/73 | 57/73 |
| Merchant / date | 5/5 each | 5/5 each |
| Subtotal / total | 4/4 and 3/5 | 4/4 and 3/5 |
| Structured draft exact purchase pairs | 18/66 | 43/66 |
| Checked-text purchases, two Costco receipts | 33/37 | 33/37 |
| Checked-text totals | 0/2 | 1/2 |
| Fully correct receipts | 0/5 | 0/5 |

Structured draft improvement is mainly the approved currency context making recognized decimal amounts usable. It is not improved image OCR. Its duplicate-identity scoring is stricter than the legacy parser counter, so 43/66 and 53/66 are different measures. Three imports use the default; two retain recognized currency. No loss of previously correct lines, summaries or recognized currency, and no new unmatched lines or wrong summaries. Fifteen omissions, seven unmatched extras and one matched amount discrepancy remain.

The drafts populate 55 product codes and six tax markers. These attributes lack checked real-photo references and are explicitly unscored; population is not proof of correctness. All receipts still require full source review and exact reconciliation before Finish or a finalized split.

Final Simulator import-to-review medians: 773 ms first pass, 777 ms repeat. These are local Simulator measurements, not iPhone timings or human correction effort.

## Verification and rejected attempts

The signed regression run passed 107 tests with one hardware-only skip, covering parser, draft context, correction/review gates, persistence and backup. After the final parser adjustment, 36 parser/context tests and both native private-import/replay tests passed (38 total). No UI walkthrough or physical-phone run was performed for this task.

An initial unsigned test host failed Keychain entitlement checks; the same regression suite passed with ad-hoc signing. A numeric promotion-code discount heuristic created four unmatched entries and was removed. Two intermediate private runs exposed loss of currency on grouped payment rows; the final parser retains self-contained currency observations and the evaluator now counts currency loss explicitly. Rejected runs remain private historical evidence, not acceptance results.

Final private run: `private-receipts/evaluation/p4-04-accepted`. Verification recomputes aggregates and checks frozen production sources, references, original image bytes, OCR membership, repeat stability and encrypted draft round trips. Independently checked 4,071 preexisting private/signing files remained byte-identical. The normal Simulator wallet and phone were not updated. [Safe aggregates](evidence/p4-04/aggregate.json), [verification](evidence/p4-04/validation.json), [reproduction](../evaluation/receipt-fields/README.md).

## Next proposed task

P4-03: bounded adaptive reading integration. Evaluate the promising correction-on read in the actual import path, with an original read fallback, explicit provenance, cancellation and a strict work budget. Do not promote broad automatic crops: P4-02 measured regressions. This next task requires separate approval; P4-05 targeted user assistance follows only after a safe retry mechanism exists.
