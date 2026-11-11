# P11-06 · Search and purchase history

November 10, 2026. Approved in Main; implementation and scoped verification complete.

## Changes

Search starts with a compact Filters disclosure and a readable current scope. Collection, store, month and archive controls remain available inside it. Reset filters resets all four choices without clearing the query. Results retain their month grouping and source-specific item matches. Returning from a receipt restores the opened result into view, rather than always starting at the top; this is an item anchor, not a promise of pixel-identical scroll offset. Filter expansion survives the same journey. Query/filter changes clear the return anchor; wallet suspension clears both new UI state values.

Saved purchase rows open Line details with a read-only purchase summary, history, Edit line and View original. Editing is explicit and retains the existing transactional Save draft/Cancel behavior. Changed values disable history until resolved. Adjustment rows and the import/review correction flow retain their existing direct editors. Source access, revision guards and finalization rules remain unchanged.

History leads with a count and explains newest-first ordering within the existing confirmed/possible/changed/different groups. Longer match/amount guidance is expandable. Rows explicitly label line totals. Match confirmation uses the shared primary button; marking different uses the shared secondary style; Undo is separated as a saved-decision action. No product identity is inferred or automatically merged. Price eligibility/calculation changes are reserved for P11-07.

## Verification

Ten unit checks passed in `/tmp/sliplet-p1106-domain.xcresult`: nine search tests, including encrypted restart, indexing, filter semantics, a 500-receipt fixture and synchronous lock clearing; plus history grouping for archive, draft, changed and rejected purchases. The new return marker and expanded-filter state are explicitly checked for clearing on suspension.

Eight distinct UI journeys passed across focused runs:
- Saved-row summary/history, original inspection, confirm/reject/undo and receipt return position; large-text history/query retention and structural accessibility; existing verified unit-price save/clear: `/tmp/sliplet-p1106-ui.xcresult`.
- 500-receipt Unicode/store/month filtering and source access; edit/archive/include/restore/delete/restart; saved purchase-line Cancel/Save draft and adjustment editor: `/tmp/sliplet-p1106-final-ui.xcresult`.
- Compact filters, active scope, reset without query loss and opened-result restoration: `/tmp/sliplet-p1106-reset-accessibility.xcresult`.
- Dark accessibility5, Reduce Motion, contrast/opaque settings, match details, return and structural accessibility: `/tmp/sliplet-p1106-dark-final.xcresult`.

Earlier mixed runs include failures and are not reported as wholly successful. The nested filter disclosure was replaced by a separately identifiable button and sibling controls after the filter test could not locate its controls. Reset testing now scrolls the button clear of the navigation bar and waits for refreshed results. The older return helper assumed the list restarted at the top; it now explicitly scrolls upward from the restored result when it needs the count. Final focused reruns pass.

[Reviewed fictional screenshots](evidence/p11-06/README.md) cover saved-line overview, history, compact filters and large dark text. Current source built successfully during the final tests; `git diff --check` passes. These are scoped checks, not a full-suite run or a claim of pixel-identical list return, zero lag, complete VoiceOver acceptance or physical-device performance. Phone acceptance remains P11-08. No private receipts, cloud calls or device installation were used.

## Handoff

U05 and U06 are addressed; the decision-action hierarchy portion of U08 is addressed. Unit-price eligibility/explanations remain P11-07, which requires Main approval. Existing exact calculations, source provenance and explicit match decisions are unchanged.
