# Phase 19 · Finish drafts and recover searches

**Goal** · Help someone finish a receipt they started earlier or find a known purchase when the current filters get in the way. Measure both journeys from the home screen, where the user decides what to do next.

## Why these two journeys

- **Saved drafts take extra steps to find.** The wallet has a one-tap **Continue import** action for an interrupted photo import. Saved incomplete receipts carry **Needs review**. The current ways back are to find the individual receipt or choose **Needs review** through Filters. Verify that distinction with a saved draft and an interrupted import in the same wallet. [Wallet actions](../Sliplet/UI/ReceiptHome.swift) · [Collection filters](../Sliplet/UI/ReceiptBrowseControls.swift)
- **Search handles one common dead end already.** An eligible archived match can be included from the results screen. When store, date or amount filters exclude a known match, the current empty state suggests clearing a filter. Changing those filters requires opening a sheet. Check what a shortcut would reveal and which filters represent deliberate choices worth keeping. [Search results](../Sliplet/UI/ReceiptSearchViews.swift) · [Phase 18 interaction counts](PHASE18_UI_UX.md#interaction-counts)
- Phase 18 already exercised returning from detail, reading long receipts and scrolling wallets of up to 1,000 fictional receipts. Reuse those cases when a Phase 19 change touches their routes. Use the same start and end states for before-and-after action counts. [Phase 18 verification](PHASE18_UI_UX.md#p18-04--combined-simulator-verification)

## Sequence

| Task | Work and acceptance |
| --- | --- |
| **P19-01 · Measure the two journeys** | In Simulator, save an incomplete receipt, relaunch, find it from home and reach the required field. Repeat with several saved drafts and an interrupted import. Search for the same fictional item under each of three states. The current purchase filters hide it, an archived receipt holds the only match, or it is absent from the wallet. Record taps, scrolls, typing, wrong turns encountered and whether the right receipt, query and filters return. Map the existing routes and recommend an exact entry point for each change that would remove a verified obstacle. |
| **P19-02 · Make saved drafts easier to resume** | Evaluate one contextual **Needs review** entry that reuses the current draft collection and has a clear place beside existing wallet controls. Aim to reach the correct review screen in at most two taps from home with one saved draft. With multiple drafts, one tap should bring up the list so the user can choose. Verify Wallet and List, zero drafts, an archived draft, a draft that has just been finished, a relaunch, and a saved draft coexisting with **Continue import**. Returning from a draft should restore the previous view and its position. Reuse the existing review and save rules. |
| **P19-03 · Recover a filtered search in place** | When clearing store, date or total restrictions would reveal a match, evaluate a one-tap action on the empty results screen. Keep the query, selected collection and Include archived preference when applying it. Keep the existing archive action available for eligible matches under the current filters. A genuine miss should explain what the user can try without offering a shortcut that produces another empty result. Check combined filters, archive-only and genuine misses, keyboard open, maximum text size, and opening Original before returning. Check the 1,000-receipt case with rapid typing and filter changes so the extra work stays bounded. |
| **P19-04 · Verify and close** | Replay both journeys with the same data and compare action counts. Run the affected import, review, search and archive regressions. Check Light and Dark, large text, Reduce Motion and return position. Inspect the candidate in Simulator and build Release. Record any real-device checks as a separate option that can be approved in Main. |

## What counts as an improvement

- The session starts from the same screen and ends at the same usable result in both runs. Count the taps and any necessary scroll or text entry separately. Report the final steps even when a design trades an extra confirmation for a safer outcome.
- Continue an import, reopen a saved draft and edit a finished receipt remain distinct actions. P19-01 can record interruption during edits to finished receipts as a separate finding. A recovery feature for that case needs its own proposal for persistence, Cancel and review semantics.
- Use fictional receipts in the first walkthrough and in recorded evidence. Keep the exact completion requirements for saved receipts and use explicit actions to change a search scope.

**Next approval** · P19-01, the Simulator baseline for returning to a saved draft and recovering from an empty filtered search.
