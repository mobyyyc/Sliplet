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

## P19-01 · Simulator baseline

Both journeys passed on isolated iPhone 15 Pro Simulators running iOS 27.0 against the planning commit `e075af1`. The saved-draft fixture used a local fake reading response containing 36 fictional items with one missing amount. The pending import used a different photo from the Simulator library. The search fixture used one item with a unique receipt match. The audit counts taps, drags and text entries along each route. Fixture setup, relaunch and assertions sit outside the counts. Search submission is included in its text entry.

### Find a saved draft

| From Wallet | To Review | To the required amount | Drags or text entry |
| --- | ---: | ---: | ---: |
| One draft with its paper visible | 2 taps | 3 taps | 0 |
| One draft reached through **Filters → Collection → Needs review → Apply** | 6 taps | 7 taps | 0 |
| Two saved drafts and a pending photo import, through the same filter | 6 taps | 7 taps | 0 |

The saved draft reopened after relaunch with the last amount still missing and the source photo available. Leaving the correction returned to the same visible wallet paper within 5 points. The filtered route returned to its draft scope. In the two-draft fixture, a deliberate tap on **Continue import** took one tap to reach the separate photo's reading-method step. Reopening the saved draft afterward left that import available.

**P19-02 entry point** · Use one **Needs review** action next to the saved count in the wallet pocket. In List, place the action as a row before the first receipt group. Show it at unfiltered home when there are active saved drafts. With one draft, open its existing review. With several, open a draft list and let the user choose. Keep the path to the required field in the existing review screen. This makes the one-draft target measurable from home to the same missing field.

### Recover an empty filtered search

The same item query was used with a conflicting store filter, with the only matching receipt archived, and after removing that fictional receipt. The conflicting store test also selected **Starred** and enabled **Include archived** to make the effect of each recovery action observable.

| From Wallet with the stated starting filters | Taps to the outcome | Text entries | Drags | Outcome |
| --- | ---: | ---: | ---: | --- |
| Store filter hides the item, then remove only Store | 4 | 1 | 0 | Result returns. The last three taps open the summary, remove Store and close the sheet. Starred and Include archived stay selected. |
| Same store filter, then use **Clear filters** | 3 | 1 | 0 | Result returns in two taps from the empty screen. Starred and Include archived are also cleared. |
| Archive contains the only match | 2 | 1 | 0 | **Include archived** reaches the result in one tap from the empty screen. |
| The item is absent, including from the archive | 1 | 1 | 0 | The generic empty state appears. With Include archived on, it still suggests clearing a filter. |

Opening the result, viewing Original and returning took four additional taps. Both restored results kept their query and remaining filters, and returned within 12 points of the same row position.

**P19-03 entry point** · Put the recovery action inside the empty search card. Show it when clearing the purchase filters alone produces a match in the current collection and archive scope. Target one tap from the empty screen, down from three while preserving the same scope. An eligible archive-only match under current filters can keep its existing path. For a genuine miss, offer guidance on changing the search text.

## P19-02 · Resume saved drafts

Unfiltered Wallet shows **Needs review** by the saved count. List places the same action above the first receipt group. It uses the existing review eligibility rules and the active receipts. A single draft opens in Review. With several drafts, the picker shows merchant, date and total so the user can select a receipt. The original receipt and correction controls are available through the usual review flow.

| From Wallet | P19-01 through Filters | P19-02 shortcut |
| --- | ---: | ---: |
| One draft, reach Review | 6 taps | 1 tap |
| One draft, reach its missing amount | 7 taps | 2 taps |
| Two drafts, choose a draft and reach Review | 6 taps | 2 taps |

The shortcut leaves a pending photo import available through **Continue import**. Cancel keeps the saved revision and returns to the original Wallet or List position. Saving or finishing opens the updated receipt. Finishing and archiving update the active draft count. The shortcut is hidden when the active count reaches zero.

The first check caught a roughly 25-point movement after canceling from Wallet. The final run restored the paper within the 5-point test tolerance, and List restored the entry within the same tolerance. The verification covered relaunch, the chooser in Wallet and List, the separate pending photo, archive visibility, correction followed by discard, finalization, and a 1,000-receipt wallet. The one-draft shortcut passed at the Simulator's maximum Dynamic Type size with Reduce Motion. Five distinct UI tests, 38 targeted unit tests and the unsigned iPhone Release build passed. The multi-draft test uses the fictional Photos fixture. [Simulator fixture](IMPORT_DEMO.md)

**Next approval** · P19-03, recover a filtered search in place.
