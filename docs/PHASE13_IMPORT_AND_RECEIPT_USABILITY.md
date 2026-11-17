# Phase 13 · Import and receipt usability

The wallet home, receipt library and lock screen keep the design accepted before Phase 13. P13-01 ended with the design exploration. Use Main to approve each implementation task.

## P13-02 · Capture to save

- In landscape, the photo and crop canvas use the main pane. Crop, Rotate, Reset, photo guidance and the next action sit alongside it. Portrait and accessibility-size layouts use the scrolling arrangement.
- The reading method step uses an in-place AI setup action when Gemini is disconnected or disabled. On-device reading remains available, and the primary button names the next action.
- A Gemini timeout leads to Review and retry upload, with on-device reading available on the same screen. Offline or unavailable connections prioritize on-device reading. Retry returns to the prepared image and requires explicit upload confirmation again.
- The import and reading changes use the existing photo adjustment, checkpoint and recognition paths.

### Simulator verification

The iPhone 15 Pro simulator on iOS 27.0 passed 12 focused UI tests using fictional receipts and an intercepted provider. These cover camera and crop, disconnected setup and local reading, timeout and offline recovery, retained covers, fresh upload consent, interruption, and saving. Three affected layout and camera cases passed again after the final landscape adjustment. Physical camera use and live Gemini latency remain for the owner walkthrough.

### Owner checks on iPhone 15 Pro

1. Check a long receipt in landscape. Drag a crop corner, apply the crop and verify the item list and total are still visible. Open Original to confirm the saved source.
2. Read a receipt on-device with Airplane Mode enabled. On a clean read, finish and reopen it from the wallet.
3. With an existing Gemini connection, try an ordinary AI import. After a temporary failure, verify that the photo is still available and a retry asks permission again. There is no need to disconnect a working API key or force a provider timeout.

## P13-03 · Read, correct and share

- The receipt toolbar exposes the same Share image action from the wallet, search and purchase history. Original remains alongside it. Opening and closing share from history keeps the matched purchase highlighted.
- Review identifies the first required correction above the optional checks. Missing dates and currencies jump to their own rows. The optional checks can be expanded when needed.
- Reread area starts with Field to update and Current value. Read selected area remains visible at the bottom. Candidate values stay alongside the printed token and source row. Use reading updates the working copy, and Apply returns it to the receipt draft.
- The share preview starts at Full width for reading and scrolling. Fit shows the whole image in the viewport. Both modes share the same opaque PNG using the approved cream background and Sliplet signature.

### Simulator verification

Twelve distinct UI cases and three native cases passed across the focused iPhone 15 Pro Simulator runs. They cover sharing from the wallet, search and history, the highlighted purchase after returning, exact review-field targets, large text, and nested Cancel and Apply. The reread test retains an independent missing total to verify that a line edit leaves that blocker in place. The system share sheet saved the 48-line fictional receipt to local Files. The saved file was 1380 × 5631 pixels, PNG and opaque. Physical iPhone checks remain pending.

### Owner checks on iPhone 15 Pro

1. Open a receipt from Wallet, Search and Purchase History. Check the top Share action and confirm the highlighted purchase stays visible when you return from sharing.
2. Open a longer receipt, compare Fit and Full width, scroll to the total, and use the system share sheet to save the PNG to Files.
3. Tap a Required to finish message. Confirm that it lands on the field to correct. In Reread area, check the field and current value before reading, then verify that Cancel discards a trial value.

## P13-04 · History & Split

- Compare unit prices opens with both purchases, merchants, dates and recorded unit prices. The overview stacks at accessibility text sizes. If a receipt has no unit price, the overview labels the line total separately. Price evidence expands per purchase, with a separate link to the original receipt.
- Split progress links directly to unassigned items and the next adjustment to confirm. Confirmed adjustments show each person's exact share once the split reconciles.
- At accessibility text sizes, one bottom action reserves its own space. Save choices moves to Amounts when Finalize becomes available. Cancel is in the navigation bar during bulk assignment, with Apply items at the bottom.

### Simulator verification

Five focused UI cases passed across the iPhone 15 Pro Simulator runs on iOS 27.0. They covered price evidence and saved comparison, the two split progress shortcuts, long bulk selection, the single action at accessibility text sizes, and finalized split sharing and recovery. All 27 selected tests for unit-price evidence, split arithmetic and split persistence passed. UI runs used fictional receipts. Physical iPhone acceptance remains pending.

### Owner checks on iPhone 15 Pro

1. Compare two purchases in Purchase History. Check that each price and unit is easy to associate with its purchase. Open the price evidence and return from the original.
2. With accessibility text sizing enabled, open a split with unassigned items and tax or discounts. Follow both progress links, then confirm the bottom rows remain reachable as the action changes from Save choices to Finalize. Open bulk assignment and check the top Cancel and bottom Apply items actions.

## P13-05 · iPhone Walkthrough

The signed Debug build from `3dfc916` was installed over Sliplet 0.3 (build 4) on the iPhone 15 Pro running iOS 27.0.1 on 2026-11-16. The owner opened the updated app and confirmed that existing receipts were visible. The rest of the physical-device walkthrough is pending.

### Walkthrough refinements

- Share preview has a Save to Photos action. The first tap requests permission to add images, and approval saves the same PNG shown in the preview. Share remains available if access is denied.
- Assign items exposes Select all unassigned next to the person's selection count. It adds only unassigned purchases to the current selection. Apply items still commits the selection to the split.
- Once every purchase has an owner, non-tax adjustments use purchase shares and explicitly linked discounts follow the item. Tax with no saved allocation is presented separately. Choose By purchase share, Split equally, or Choose who pays. One selected person covers the tax; multiple selected people share it equally. Multiple tax charges require a choice for each charge. Back leaves a new choice unapplied.
- The tax explanation distinguishes absent or unclear markers from markers that cannot be linked to a particular charge. Choosing a payer records a payment allocation. Choosing specific taxable items remains in More options and retains its source confirmation.
- Finalize opens a dedicated summary with large per-person amounts, Copy and Share. View breakdown and Edit split provide access to the details. Reopening a finalized split shows this summary. Changes to assignments clear finalization and require tax choices to be confirmed again.
- Purchase history uses a separate heading for the product and item code, so both purchase sections display complete rounded cards in the system list.

Across focused Simulator runs, nine UI cases and 31 unit and persistence cases passed. These included the system Photos allow and deny paths, saving a long PNG to Files, default and custom split rules, and the dark history layout. Build `e2bacf0` was installed in place on the owner's iPhone 15 Pro. On 2026-11-17 the owner reported the other refinements working and requested a clearer split completion and tax-allocation flow.

The 2026-11-17 split refinement passed seven distinct focused UI cases across Simulator runs and 33 calculation and persistence cases. These covered per-person results in light and dark appearances, tax cancellation, a payer without assigned purchases, separate choices for multiple tax charges, large text, and encrypted restoration of the chosen payer. Physical-device acceptance of this refinement is pending.

### Remaining owner checks

1. **Import.** Photograph a long receipt, adjust the crop in landscape, and open Original after saving. Try on-device reading in Airplane Mode and Gemini with the existing connection online. If a Gemini attempt fails, check that retry preserves the prepared image and requests upload permission again.
2. **Read and share.** Open a long receipt from the wallet, scroll to its total, and compare Fit and Full width in the share preview. Try Save to Photos and check the saved image. Use Share to save the PNG to Files. From Search or Purchase History, return from sharing and check that the matched item remains highlighted. If a draft needs correction, check that Required to finish takes you to the field and cancelling an area reread leaves its value unchanged.
3. **History and split.** Compare two purchases, open their price evidence and return from Original. In a split, use Select all unassigned for the last person and Apply items. Choose how to pay each tax, finalize, and check each person's amount. Try assigning the tax to a person with no purchases and cancelling a tax choice. Reopen the split and use Edit split. Check the tax and summary screens at accessibility text sizes.
4. **Wallet and accessibility.** Open and close a receipt from the middle of the wallet stack and verify the stack returns to its place. Check the lock-and-return flow with Face ID and spot-check light and dark appearance, VoiceOver and Reduce Motion.
