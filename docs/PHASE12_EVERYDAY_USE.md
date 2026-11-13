# Phase 12 · Everyday use and recovery

Proposed November 12, 2026, after Phase 11 iPhone acceptance. The product goal is to make it easy to put a receipt away, finish checking it when convenient, and find the relevant purchase later. This proposal follows the current app and earlier walkthroughs. The implementation tasks are open for approval.

## Where the workflow fights the user's intent

| User intent | What the current app does | Product decision |
| --- | --- | --- |
| Switch to Messages, then finish scanning | Moving to the background clears the active image, crop session, review edits, and navigation from memory. The Face ID grace period is separate from that cleanup. | Give unfinished work a visible way back. Design one encrypted pending import, checkpointed at stable steps while unlocked and reopened after authorization. Start with the photo and crop. Preserve completed reading and applied corrections at safe checkpoints if the design supports them. An interrupted AI request returns to the saved preparation step and requires fresh consent. |
| Understand what is happening while waiting | Photo opening, on-device reading and Gemini share a spinner layout. Gemini can time out or fail, and returning from Stop goes through a recovery screen. | Give Gemini a short receipt-printer loop and clear status. Keep Stop within reach. Make the next action after a stop or error obvious, with the prepared photo available while the import is active. |
| File a receipt now and check it later | A balanced import can open as paper. A mismatch can send the user into the full editor. Finishing requires opening the original, checking “I checked the original,” and reconciling the receipt. A saved draft can get buried in the wallet. | Remove the mandatory original-photo visit and checkbox. Keep Original available on demand. Let users tap Finish once the required fields and amounts reconcile. A finished receipt is ready to use. It carries no new claim that the photo was checked. Make saved drafts easy to resume and make the first blocking issue actionable. |
| Use my usual reading method | The user passes through photo check and method selection on each import. AI also has privacy and upload confirmation. | Evaluate a remembered reading preference and a shorter path for an already clean photo. Keep the alternative visible and require explicit consent for each prepared AI image. Measure how often people actually change the crop or method before removing a step. |
| Know what I paid before | Search shows an item's line amount. Purchase History shows prior line totals, and eligible unit-price comparison sits in the opened receipt's menu. | Put comparable unit prices beside the corresponding purchases where evidence supports it. Keep line total and unit price clearly labeled. Preserve different-pack, currency, quantity and tax safeguards. |
| Split my receipt after correcting one line | Saving a changed line creates a draft, and finalizing a split requires a reviewed receipt. The receipt can still open Split while it needs review. | Show the concrete blocker and give the user one route back to review. Check whether reviewing allocation row by row is actually onerous before adding any bulk confirmation. |

The background and review findings come from current app behavior in source. Their frequency in real use is still unknown. Phase 11 established that core phone journeys work and included no measurement of how often a person abandons an import or revisits a draft.

Three focused iPhone 15 Pro Simulator checks passed with fictional inputs. They covered waiting and Stop, offline recovery with renewed upload review, and saving a receipt with a total mismatch as a draft. The background finding is from source and the existing lifecycle contract. This audit did not measure real provider latency or conduct a new phone walkthrough.

## Printer waiting screen

Use a small thermal printer with a matte housing, a horizontal paper slot and a short slip with Sliplet's torn edge. Feed the paper downward in two or three small advances, pause briefly, then reset the slip behind the slot. Target a roughly two-second loop with a fixed footprint. Use faint generic marks on the slip so the animation stays separate from the receipt data. Use native SwiftUI shapes and masking, adaptive contrast and a static illustration under Reduce Motion. The illustration is decorative for VoiceOver. Announce the real status and keep Stop reachable at large text sizes.

| State | What the user sees |
| --- | --- |
| Gemini reading | “Reading your receipt” and “Using Gemini.” The loop runs only while waiting. |
| Longer wait | Show a single “Still reading” message after a short delay. Progress remains indeterminate. |
| Ready | Open Review as soon as the result arrives. The illustration never adds a minimum wait. |
| Stop or failure | Show a clear outcome. Offer on-device reading or return to the existing upload preview when the prepared image is still available. For Stop, retain the disclosure that an image already sent cannot be recalled. |
| Photo opening or on-device reading | Keep a simple system progress treatment with copy appropriate to the actual operation. |

Use the existing simulated transport for immediate success, slow success, failure, cancellation and late completion. Inspect light, dark and large text, Reduce Motion, and VoiceOver focus. Check that the animation releases with the screen and that cancellation or lock cannot apply a late response. Provider latency and network behavior require separate evidence.

## Proposed order

1. **P12-01 · Printer and recovery screen.** Build the Gemini waiting experience and make stop and failure recovery easier to understand. Verify the current upload, privacy and cancellation paths. This task does not add persistence.
2. **P12-02 · Resume an interrupted import.** Design the encrypted checkpoint and resume entry point. Test returning after an app switch, device lock and app relaunch. Make discard explicit, preserve the original, and keep any upload under fresh consent.
3. **P12-03 · Save now, review later.** Remove “I checked the original” from both review layouts and allow Finish without opening the photo when validation and exact reconciliation pass. Update completion and split eligibility to use the new finish semantics, with legacy reviewed receipts and drafts retaining their existing status. Review any copy and indicators that imply photo verification. Improve the review entry point, show the first blocker and make drafts easy to find and finish. Verify one-tap Finish on a clean read, optional Original access, blocked Finish for missing required fields or mismatched amounts, and split eligibility after Finish. Use pilot observations to decide whether to shorten the photo and method steps.
4. **P12-04 · Find and compare a purchase.** Make recorded unit prices and eligible comparisons easier to reach from Purchase History. Check the handoff from receipt review to Split and fix demonstrated friction.
5. **P12-05 · Add one feature based on actual use.** Favor a single-receipt share action if users need proof for a return or reimbursement. Offer Original and Digital as explicit choices with a preview of what will leave the app. If repeated imports are the bigger issue, prioritize a warning for an identical photo with an option to keep both. Keep reminders, budgets and collaborative splitting in the backlog until there's a concrete use case.

During the pilot, use the next five real receipts as they arise. Record capture-to-save time and time spent correcting if convenient. At minimum, note the reading method, whether an interruption cost work, which corrections were needed, and whether the receipt was easy to find again. Include at least one on-device attempt and one interruption scenario if practical. A five-receipt pilot informs workflow decisions. It cannot establish recognition accuracy across stores.

The first implementation approval is for P12-01 only.
