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

## P18-01 · Purchase history and price comparison

Each purchase now uses one list row. The store and date lead, with the line total and any recorded unit price alongside. The row opens the receipt at the matching item. Going back restores the purchase row and its position. The fictional example shows both previous purchases and their recorded prices without opening another screen.

A single **Compare prices** action opens a purchase chooser. Saved comparisons are marked next to the corresponding purchase in both history and the chooser. The formal comparison keeps its existing product, pack, unit and tax verification. A purchase in a different currency stays readable in history and shows why it cannot open a comparison. Missing printed rates remain absent from the row.

The scope includes light and dark history, system maximum text size, a long item name, a long highlighted receipt, a missing recorded rate, incompatible units and currencies, and reopening a saved comparison. Six distinct Simulator UI tests and 24 targeted unit tests passed. The maximum-text run used the Simulator system accessibility setting. The unsigned iPhone Release build succeeded. The UI runs used an isolated fictional wallet that was reseeded before each journey.

## P18-02 · Active search filters

Search and the receipt list now place a compact active-filter summary below the navigation controls. It remains visible as results scroll. The summary announces the count and current conditions to accessibility tools. At large text sizes it displays the count and opens a vertical list of the full conditions.

Tap a condition in **Active filters** to remove it immediately. **Clear filters** stays at the bottom of that sheet. The remaining conditions and the search term carry forward after a single removal. Clearing all filters preserves the search term. The toolbar’s **Filters** button still opens the native editor with Apply and Cancel. Archive discovery still offers **Include archived** when an archived receipt matches all current conditions.

The first layouts allowed the native toolbar to cover the filter summary’s hit region. The final layout places the summary in the navigation safe-area bar and verifies that the control starts below the toolbar. The tests exercise the keyboard, the maximum system text size, three active conditions, an archived match, and returning to the same result after opening its original. Seven distinct Simulator UI tests and 24 targeted unit tests passed across the scoped runs. The unsigned iPhone Release build passed. All wallets and receipts in the checks are fictional.

## P18-03 · Unfinished import choices

**Continue import** is the primary action. The adjacent options menu offers **Choose another photo** and **Discard import**. Photo selection keeps the same camera, photo library, and Files sources. Picking a replacement opens a confirmation after Sliplet reads the new photo. Cancelling returns to the wallet, where the original import remains available.

After confirmation, Sliplet writes the new photo and its initial progress in one encrypted database transaction, then opens photo adjustment. A failed read or write leaves the original photo and progress available. Discard has its own confirmation. Once the pending import is gone, the add button opens the source choices in one tap.

The Simulator checks cover system Photos cancellation, cancelling or confirming replacement, relaunch, discard, and the normal add action. The storage regression verifies that a malformed photo or a failed database write preserves the original photo, crop, rotation, privacy covers and reading step. All 50 targeted import and workflow unit tests and the unsigned iPhone Release build passed. Run the replacement UI test with the fictional Photos fixture from the [import demo](IMPORT_DEMO.md).

## P18-04 · Combined Simulator verification

The checks use Xcode 27.2, iOS 27.0 and isolated iPhone 15 Pro Simulators with fictional receipts. The standard paths cover light and dark appearance. The accessibility path uses the Simulator's maximum Dynamic Type size, the software keyboard, and Sliplet's test switch for its Reduce Motion behavior.

### Interaction counts

The counts start on the named screen and end when the action takes effect. The pre-Phase-18 counts come from the routes in `e8e27eb`. The current counts come from the Simulator journeys. The history comparison uses two earlier purchases with recorded unit prices.

| Starting point and action | Before Phase 18 | Current |
| --- | --- | --- |
| Purchase history · Read both recorded prices | No taps. Two purchase rows and two separate comparison rows. | No taps. Two purchase rows and one shared comparison action. |
| Purchase history · Open a comparison for a particular earlier purchase | One tap on its comparison row. | Two taps to open the chooser and select the purchase. |
| Filtered search · Clear all three active conditions | One tap once the horizontally scrolling control is visible. | Two taps from the fixed summary. No sideways scroll. The query stays in place. |
| Filtered search · Remove only the archive condition | One tap once its chip is visible. | Two taps to remove it, then Done to return to results. The other conditions stay applied. |
| Search with an eligible archived match · Include the archived result | One tap. | One tap. |
| Wallet · Continue an unfinished import | One tap. | One tap. |
| Wallet · Discard an unfinished import | Two taps including confirmation. | Three taps including the options menu and confirmation. |
| Wallet · Start another photo from Photos while an unfinished import exists | Five taps, including discarding the old import before opening Photos. | Five taps, with the replacement confirmation after Photos. Cancelling preserves the old import. |
| Wallet · Open photo source choices with nothing pending | One tap. | One tap. |

### Long receipts and large wallets

A 31-item receipt opened from Purchase overview and scrolled until its total cleared the bottom actions. Going back restored its originating row. Purchase history opened a late item in a previous receipt, highlighted the item and restored the history row within 5 points on return.

| Fictional receipts | Papers before and after one drag | Drag and snapshot | Detail round trip | Search to result count |
| ---: | ---: | ---: | ---: | ---: |
| 10 | 8 → 10 | 2.64 s | 3.06 s | 1.90 s |
| 50 | 8 → 10 | 2.63 s | 3.01 s | 1.93 s |
| 200 | 8 → 10 | 2.57 s | 2.94 s | 1.86 s |
| 1,000 | 8 → 10 | 2.58 s | 2.97 s | 1.87 s |

At each size, the saved wallet reopened, the card returned within 4 points of its original position, and search found all the matching receipts. The 200- and 1,000-receipt runs also found an older receipt across the year boundary. The timings are single XCTest samples and include input, queries and idle waits. Frame pacing and VoiceOver operation remain for physical-device verification.

### Accessibility and closeout

The maximum-size wallet screenshot exposed a split word in **Continue import** and an ellipsis extending past its round button. At accessibility sizes, the primary action now gives the full label the available width. The adjacent symbol stays within its 44-point target. The final screenshot shows the label wrapping between words. The Photos cancellation and replacement journey passed at both standard and maximum text sizes.

The UI tests now dismiss the system Photos notice when present, scroll to the AI method before selecting it, and open Search and the Month picker through their current controls. The scoped reruns passed after these test updates. The archived-result journey kept its query and filters after opening the source photo, and the reading screen still offered Stop after its delayed status update with Reduce Motion.

Phase 18 is complete in Simulator. Nineteen distinct UI tests passed across the scoped runs, along with the unsigned iPhone Release build.
