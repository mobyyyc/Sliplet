# P6-02 — Isolated summary-region reading experiment

2026-10-17. Approved in Main; experiment completed. **Proof gate failed. No production integration.** P6-03 and the normal Phase 6 implementation sequence do not proceed automatically.

## Fixed experiment

The test-only probe locates one total label in the saved baseline observations. It takes a full-width original-image strip centered on that label, with height equal to five label heights or 4% of the image, whichever is larger. This preserves horizontal sign margins without using reference values or hand-measured receipt coordinates. It reads the identical strip in original color and with Core Image RGB color inversion, using accurate native Vision with language correction disabled and the unchanged parser. No OCR text character is repaired.

Each mode is read twice; order reverses on the second pass. The selection rule was fixed before private results: preserve existing totals; abstain on existing sign or summary conflicts; otherwise require both parsed crop totals to agree without summary conflict. This conservative rule does not choose a candidate because it matches a label or balances a sum. The five original images are the same exposed development set; no new labels reach the recognizer. Checked transcripts are staged only for a separate existing diagnostic and are not read by the probe.

## Result

| Measure | Result |
|---|---:|
| Correct baseline totals | 3/5 |
| Correct proposed totals | 3/5 |
| Recovered totals | **0** |
| Lost correct totals / new wrong totals | 0 / 0 |
| Successful private crop reads | 20 |
| Stable proposed results across passes | 5/5 |
| Baseline fields/source memberships preserved | 5/5 |
| Median / maximum individual crop read | approximately 436 / 860 ms |

Ten fresh baseline imports, five repeat pairs and five draft round trips succeeded. Strict item pairs remain 43/66. These saves verify the unchanged baseline, not an integrated candidate: the experiment proposes only total substitution and never modifies or saves candidate drafts. No normal Simulator or phone update occurred.

The gate required at least one total recovery, from 3/5 to at least 4/5, without regressions. It failed. Passing fictional tests or recovering digits somewhere in OCR is not a successful automatic field recovery.

## What the failed experiment revealed

Post-hoc inspection of retained first-pass observations is recorded separately from the frozen selector; it was not used to tune the rule or rerun candidates.

- **Case A, original crop:** the checked digit sequence appears, but not as a valid decimal amount. The total label remains readable; the parser leaves the total missing.
- **Case A, inverted crop:** the exact checked decimal amount appears. However, the reread total label has an unsupported prefix, and the unchanged parser classifies its source-linked row as a purchase instead of the total. This is not a recovered total, and this crop's whole parsed receipt must never replace the baseline. It does provide a specific new hypothesis: retain the trustworthy original total-label anchor instead of requiring the transformed image to reread that label successfully.
- **Case B:** neither crop contains the checked digit sequence. The original-read sign conflict also remains a reason to abstain. No recovery evidence was found for this receipt.
- **Control receipts:** one already-correct receipt loses its total label in the inverted view. Preserving the existing baseline result prevents a regression. Inversion is not a safe blanket replacement for normal recognition.

The shared dark bar remains a plausible reading difficulty, not a sufficient explanation or a proven universal fix. A whole-strip inversion can improve an amount and damage nearby labels simultaneously. The first case's newly visible correct amount is candidate evidence only. The second read/pass agreement cannot be assumed statistically independent.

## Verification

Three new native fictional methods pass: selector safety with preserved negative signs/conflicts; unique-label/full-width geometry; and actual Vision on light-on-dark positive, leading/trailing negative, missing and competing amounts. Three private hosted methods pass (fresh imports, checked-text diagnostic, total probe). All 18 scorer tests pass. Native timing is Simulator timing, not phone performance or human correction effort.

Frozen manifest and private captures verify. The evaluator independently compares all baseline fields/source memberships with P5-06 and checks mapped crop boxes with pixel-rounding tolerance. Code, images and references remain bound to the private run. The initial result-collection permission check timed out; its allowed retry succeeded. No receipt test failed because of that infrastructure timeout.

This task changes only test/evaluation code and documentation. No production source, parser rule, checked label, signing setting or installed wallet was changed. Production accuracy remains unchanged. Five exposed purchases and zero held-out purchases cannot establish general accuracy or all-field correctness.

## Stop decision and proposed next step

Do **not** begin P6-03 integration, item work or UI polish. P6-02 is complete as a failed experiment; Phase 6's automatic-recovery goal is not achieved.

A possible revised isolated experiment, **P6-02B**, would retain the baseline total label as the semantic anchor, test reading only its amount-side evidence with explicit original-image mapping, and evaluate a predetermined association/selection rule. It must preserve full sign margins, reject competing numbers and any unresolved sign conflict, keep baseline-correct fields untouched, and never insert a decimal point or select by the expected answer. The new Case A evidence motivates this experiment; it does not prove it will work. Case B may remain unresolved.

P6-02B requires explicit approval with a fixed protocol and the same 4/5/no-regression gate. If the user declines, retain the current app and close with the accuracy goal unmet. No further experiment is authorized by the failed P6-02 result alone.

[Aggregate results](evidence/p6-02/aggregate.json) · [Post-hoc findings](evidence/p6-02/diagnosis.json) · [Validation](evidence/p6-02/validation.json) · [Reproduction](../evaluation/receipt-total-probe/README.md). Frozen private run: `private-receipts/evaluation/p6-02-final`.
