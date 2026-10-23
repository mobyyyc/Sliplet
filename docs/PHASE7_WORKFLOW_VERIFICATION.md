# P7-08 — current-build import and correction verification

## Real receipt evidence

Ten fresh actual app imports (five originals, two passes) preserve the P7-06 weighted-item improvement: **56/65 before versus 57/65 after** on the same new OCR for each pass. No production code changed in P7-08. P7-07 retries remain disabled, with no adaptive reading evidence attached to imports.

All ten imports reached review, could save a draft and remained blocked from Finish without independent review. Draft fields, review input, original image bytes, raw OCR, raw parser output and reading evidence survived save, store close/reopen and detail loading. Existing correct fields were not lost. Totals remain 3/5 and checked subtotals 4/4; one subtotal is unscorable. This is integration verification, not another accuracy gain.

The same production workspace entry point used by the Files picker was invoked in the hosted lab. These are real image imports and encrypted draft round trips, not taps through the native Files picker. No real receipts are used in UI screenshots.

Observed Simulator import-to-review median: about 1.13 seconds; maximum about 1.97 seconds. Maximum main-actor polling gap: about 24 ms. Polling gaps are diagnostic observations, not frame-time measurements or a guarantee of no lag. No paired previous-build end-to-end timing or physical-phone timing was measured.

## Verification scope

25 native tests passed with zero skips/failures, covering the ten private import round trips plus focused correction, guidance and currency context. Offline replay reproduced the captures and confirmed comparator source/binary provenance. The before parser is frozen at `abf4c2a`; the current parser is `p7-06-weight-extensions-0.7.1`.

UI verification is run separately using fictional receipts and the T05Workflow scheme. Initial attempts were retained: one targeted the wrong scheme; an unsigned UI build could not access its fictional Keychain-backed wallet. The corrected run uses ad-hoc Simulator signing without modifying personal project signing settings. These setup failures are distinct from the passing private import/storage checks.

Final UI result: **3/3 passed**, zero failures/skips. The difficult-source workflow passed in light/dark mode (invalid Apply rejection, Cancel discard, explicit Apply, draft save/reopen); the long dark receipt passed original comparison, independent source confirmation and Finish; nested region reread Cancel/Apply also passed. In total, 28 native/UI methods passed, with ten real import round trips inside the hosted private method. P7-08 is complete.

## Limits and next task

Five exposed receipts and zero held-out purchases. Normal Simulator wallets and the physical phone are not updated. Existing source corrections stay intact; this task neither relabels receipts nor strips printed suffixes. The 90% exact-pair and all-total acceptance gates remain unmet.

P7-09 should freeze and audit this fresh repeated workflow evidence, report final Phase 7 gains and unresolved errors, and state partial acceptance honestly. Reuse these verified captures when source/reference hashes are unchanged; do not rerun identical imports merely to repeat a milestone. Any further accuracy experiment needs a distinct hypothesis and explicit approval.

Reproduction: `evaluation/receipt-workflow-integration/README.md`. Full private evidence: `private-receipts/evaluation/p7-08-final`. Only aggregate counters are published.
