# P11-05 · Color-first bulk splitting

November 10, 2026. Approved in Main; implementation and scoped Simulator verification complete.

## Interaction

Add person creates and selects a numbered color participant immediately, without a keyboard. The pinned person strip remains accessible as purchases scroll, with Add outside the horizontal list. Optional Edit person uses an explicit Apply/Cancel sheet for name and color. Number badges, names and selection marks supplement color.

While assigning, the receipt overview yields space to items. Tap multiple rows, select all currently unassigned items, or clear only this person's selection. All/Unassigned filters do not discard hidden selections. At standard text sizes, the pinned summary shows selection/shared counts and the full selected item total explicitly before sharing and adjustments. Apply changes one person's memberships; Cancel discards the batch. Existing co-owners are never replaced. Undo restores the plan before the last assignment batch, including review state. Any intervening plan edit or save clears that Undo snapshot.

Switching people, adding a person or closing with a changed selection requires Apply/Discard/Keep editing. Unsaved split choices still have the existing discard confirmation and explicit Save choices/Finalize. Interactive dismissal is disabled for a dirty batch, even when the underlying plan is saved. Background/privacy covering cancels pending selections and optional person editing. Receipt revision changes dismiss this editor rather than apply old choices to a new revision.

The existing per-item owner editor remains available when no person is in assignment mode. Shared rows show multiple numbered badges, a shared label and all owner names/numbers to accessibility. Removing a person confirms its effect; only their memberships are removed. Newly ownerless items block finalization.

At accessibility text sizes, a compact people menu replaces the horizontal chips and the detailed selection summary scrolls with the form. This keeps the pinned area bounded without shrinking text. Selection controls stack vertically and all content remains scrollable.

## Storage and money

Version-1 plans add optional number/color metadata and an optional next-number counter. Legacy named people and IDs decode unchanged; appearance is materialized only on an actual edit, so simply opening an old plan does not dirty it. Removed numbers are not reused, including after save/reopen. A six-color palette repeats with stable numbers for larger groups. No contact permission or account is introduced.

The integer split engine is unchanged. Assignment edits and participant membership changes invalidate adjustment acceptance, since the allocation recipients or weights may change. Adding a person never expands existing item owner sets. Rename/recolor leaves memberships and monetary calculations unchanged. Existing source-tax scope confirmation, reconciliation, signed/zero rows, odd-cent balancing, stale-write protection and incomplete-draft gates remain authoritative.

## Verification

29 unit tests passed in `/tmp/sliplet-p1105-data-verified.xcresult`: six bulk/compatibility tests, 15 split engine tests, seven split persistence tests and one cross-key encrypted backup round trip. The money engine itself is unchanged.

Eight distinct UI journeys passed across scoped runs:
- Bulk selection, Cancel, Undo, shared ownership, color save and restart: `sliplet-p1105-layout-final.xcresult`.
- Dark appearance and same-ID save/return/immediate edit: `sliplet-p1105-ui-final.xcresult`.
- Existing named three-person assignment, finalization, copy/share, restart and receipt edit: `sliplet-p1105-ui.xcresult`.
- Pending selection on switch/close and structure accessibility audit: `sliplet-p1105-guards.xcresult`.
- Fictional image import, bulk split, share, search, source inspection and restart: `sliplet-p1105-resume.xcresult`.
- Fourteen-item accessibility5/Reduce Motion assignment, removal and stable person numbering: `sliplet-p1105-accessible-final.xcresult` (November 10, successful final run).

Earlier mixed runs were not all green: test setup needed to reopen the receipt after restart; a native confirmation exposed duplicate accessibility nodes; and the generic scrolling helper scrolled away from the summary above the current viewport. Those test assumptions were corrected. Screenshot inspection also found an oversized pinned accessibility summary; production now uses a compact menu and a scrolling summary. Final large-text checks verify reachable actions rather than fitting all enlarged content in one viewport.

Selected [fictional screenshots](evidence/p11-05/README.md) are retained. The final focused test rebuilt current source successfully; `git diff --check` passes. These are scoped Simulator checks, not a full-suite run, manual VoiceOver acceptance or physical-device performance measurement. Phone acceptance remains P11-08; no installation, private receipt use or cloud call was included. P11-06 requires separate Main approval.
