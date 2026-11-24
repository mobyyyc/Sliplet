# Phase 18 · Everyday interface refinements

The owner skipped the signed iPhone walkthrough on November 24, 2026 and asked to continue improving the interface. Phase 17 remains closed at its Simulator milestone. The [Phase 17 follow-up measurements](PHASE17_CLOSEOUT.md) and screenshots from fictional receipts inform this plan.

## What the current interface shows

- Purchase history alternates purchase rows with separate **Compare unit prices** rows. In the reviewed example, two previous purchases produce four rows. The line total and printed unit price already appear together on each purchase, and tapping the purchase opens the receipt with that item highlighted. Keep both behaviors and move repeated comparison controls out of the reading path.
- Search puts active filters and **Clear filters** in one horizontally scrolling row at the top of its list. The maximum-text-size screenshot shows a store filter behind the scroll edge of the toolbar. Multiple conditions can place **Clear filters** outside the visible width. The same test passed result and filter restoration, which gives this change a concrete behavior to preserve.
- With a pending import, the ordinary add button gives way to **Continue import** and **Discard**. Resuming works after interruption. This is an opportunity to make an intentionally unfinished import and a mistakenly selected photo easier to distinguish, with clear actions that respect the existing checkpoint.

## Sequence

| Task | Design and acceptance |
| --- | --- |
| P18-01 · Make purchase history easier to scan | Keep the item and its code above a compact purchase list. Each old purchase occupies one row with its store, date, line total and recorded unit price, when available. Keep tapping the row to open the highlighted receipt and restore the same history position on return. Give formal comparison one **Compare prices** entry with a choice of past purchase. Keep saved comparisons discoverable from the relevant purchase. Verify that a user can read two recorded prices without taking any extra action, and that the comparison flow preserves product, pack, unit, currency and tax checks. Include a long item name, a missing rate, incompatible units or currencies, and existing verification on fictional data. |
| P18-02 · Make active search filters readable and easy to clear | Give the current scope a short accessible summary and keep clearing one condition or all conditions reachable without sideways scrolling at maximum text size. Keep the native filter form and its Apply and Cancel behavior. Verify several active conditions, search with the keyboard open, archived-only results, and return from a receipt to the same query, filters and result location. |
| P18-03 · Clarify what to do with an unfinished import | Lead with **Continue import** when saved work can be resumed. Make discarding or switching to another photo explicit secondary choices. Prototype with the existing single checkpoint. Confirm any replacement and preserve the pending import when a user cancels the new selection. Verify relaunch, discarding, and the normal one-tap route to import choices when no work is pending. |
| P18-04 · Verify the combined paths in Simulator | Rerun the affected journeys in light and dark appearance, with the system’s largest text size, Reduce Motion and the keyboard. Check a long receipt and a large wallet for restored reading position and responsive scrolling. Use the same fictional examples for tap and interaction counts. |

**Next approval** · P18-01, purchase history and price comparison presentation.
