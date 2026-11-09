# P11-04 · Review and utility clarity

November 8, 2026. Approved in Main. Scope: audit U09, U10, U11, U12, U15 and remaining U13 rereading toolbar organization. Bulk splitting remains P11-05.

## Changes

- AI connection status appears before provider/model. Once a key exists, privacy acknowledgment and enablement appear before optional retesting. Retest controls are disclosed on demand, but active checks and replacement setup remain visible. Essential provider data-use and per-image consent information remains visible beside enablement. Key replacement/disconnection semantics are unchanged.
- The settings entry reports Not connected, Checking, Needs attention, Off or Ready from connection state, instead of treating every stored key as usable Gemini access. Ready remains last-checked readiness, not a guarantee of current allowance.
- Backup export shows inline short-password, oversized-password and mismatch feedback after entry. Existing length/byte-count/match gates stay authoritative; no password is saved. Restore summary values use the shared wrapping labeled-value style.
- Failed import has a concise status, secondary alternatives in content and one primary bottom action: choose a photo, enter manually or read on device as appropriate. Native soft scroll edges preserve long/error-text access. Another AI attempt still goes through review and fresh consent; the original remains available.
- Rereading separates area selection from the zoom row. Candidate values emphasize the exact printed token and numbered source row so, for example, printed `1` and `1.00` remain distinguishable even when both interpret as 1.00. No candidate is merged or automatically selected, and no parsing or provenance rule changes.

## Verification

Sixteen connection-state unit tests passed. The initial five UI journeys passed: connection/consent/disconnect, backup export/cancel, nested reread Apply/Cancel, preserved-original manual recovery and offline retry requiring fresh consent. Updated mismatch-feedback assertions and restore merge preview also passed (six distinct UI journeys overall).

The added retest-disclosure check exposed an inherited accessibility identifier that masked the nested verification button. The identifier was removed; the expanded connect/enable/retest/disconnect rerun passed in `/tmp/sliplet-p1104-retest-final.xcresult`. An initial combined test command selected unit tests under the UI-only scheme and ran no tests; it was corrected by using the app scheme for unit tests. These harness/setup outcomes are not app-behavior passes.

Inspected [fictional screenshots](evidence/p11-04/README.md) show connected settings in dark mode, explicit printed-token distinctions and the light recovery screen with a primary bottom action. These scoped Simulator results do not certify every accessibility size or physical-phone behavior. All test data is fictional; no live AI request or phone install is part of this task. Preserve the unrelated existing Xcode launch-scheme edit.
