# P6-02B — anchored total recovery

Completed 2026-10-18. **Proof gate failed: totals remain 3/5, with zero recoveries, zero lost correct totals and zero new wrong totals.** Production is unchanged; P6-03 and the normal implementation sequence remain stopped.

## Fixed experiment

Retain the original total label and match crop observations by geometry, rather than requiring reread OCR to reproduce the label. Reuse original/inverted crops and require matching digits across both readings, at least one literal valid money token, and no malformed separator, sign or competing amount. Preserve baseline totals and conflicts. The selector never reads expected answers. See the [frozen policy and reproduction procedure](../evaluation/receipt-anchored-total/README.md).

## What failed

In the first failed receipt, both candidate amount observations pass the anchor location checks. The inverted view contains the correct literal amount. The original view reads the decimal separator as a colon, so it fails the numeric-shape rule and cannot corroborate the inverted view. The broad decision code `ambiguous_or_missing_amount` therefore means malformed corroboration here, not incorrect geometry or absence of all useful OCR. This explanation is post-hoc inspection against checked references; the selector and gate were not loosened after seeing the result.

The second failed receipt retains its original spurious-sign conflict. The experiment does not supply a reliable replacement. Existing correct totals are preserved, including a control whose inverted crop damages its label. Synthetic safety passes show intended abstention behavior, not improved real-receipt accuracy.

## Verification and limits

Three fictional native methods, three private hosted methods and 18 scorer tests pass. Ten fresh baseline imports produce five stable pairs and draft round trips. Twenty crop reads produce five stable proposed-total outcomes. Baseline fields/source memberships match P5-06; no proposed candidate draft is saved. Median crop-read time is approximately 404 ms (maximum 767 ms), measured in the dedicated Simulator, not on the phone.

These are five exposed purchases, zero held-out purchases. Strict exact purchase pairs remain 43/66; all five receipts still have errors. No improvement to general accuracy, human correction time or phone performance is claimed. Original receipts, references, production behavior and local signing settings are preserved. Only allowlisted [aggregate counts](evidence/p6-02b/aggregate.json) and [validation](evidence/p6-02b/validation.json) are published; full captures and evaluation remain private.

## Stop decision

Do not integrate this selector or automatically start P6-02C, item work or correction UI. Retaining the original label solves the location/label obstacle for one candidate, but the fixed corroboration policy still rejects it. This does not establish that all possible on-device methods fail. The proposed next task is the agenda's early P6-07 decision report: compare the failed hypotheses, remaining evidence and materially different approaches before approving further implementation. That task requires separate user approval.
