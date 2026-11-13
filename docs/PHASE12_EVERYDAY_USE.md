# Phase 12 · Everyday use and recovery

Proposed November 12, 2026, after Phase 11 iPhone acceptance. The product goal is to make it easy to put a receipt away, finish checking it when convenient, and find the relevant purchase later. This proposal follows the current app and earlier walkthroughs. The implementation tasks are open for approval.

## Where the workflow fights the user's intent

| User intent | What the current app does | Product decision |
| --- | --- | --- |
| Switch to Messages, then finish scanning | Moving to the background clears the active image, crop session, review edits, and navigation from memory. The Face ID grace period is separate from that cleanup. | Give unfinished work a visible way back. Design one encrypted pending import, checkpointed at stable steps while unlocked and reopened after authorization. Start with the photo and crop. Preserve completed reading and applied corrections at safe checkpoints if the design supports them. An interrupted AI request returns to the saved preparation step and requires fresh consent. |
| Understand what is happening while waiting | Photo opening, on-device reading and Gemini share a spinner layout. Gemini can time out or fail, and returning from Stop goes through a recovery screen. | Give Gemini a short receipt-printer loop and clear status. Keep Stop within reach. Make the next action after a stop or error obvious, with the prepared photo available while the import is active. |
| File a receipt now and check it later | A balanced import can open as paper. A mismatch can send the user into the full editor. Finishing requires opening the original, checking “I checked the original,” and reconciling the receipt. A saved draft can get buried in the wallet. | Remove the mandatory original-photo visit and checkbox. Keep Original available on demand. Let users tap Finish once the required fields and amounts reconcile. A finished receipt is ready to use. It carries no new claim that the photo was checked. Make saved drafts easy to resume and make the first blocking issue actionable. |
| Use my usual reading method | The user passes through photo check and method selection on each import. AI also has privacy and upload confirmation. | Evaluate a remembered reading preference and a shorter path for an already clean photo. Keep the alternative visible and require explicit consent for each prepared AI image. Measure how often people actually change the crop or method before removing a step. |
| Get Gemini working or recover after an error | Key setup, model selection, verification, privacy and enablement are exposed together. A model change can require another check even though the key is still saved. | Show the current state and one primary action. Use the same connection screen from Settings and from an active import. Explain what failed and keep the prepared image available. |
| Know what I paid before | Search shows an item's line amount. Purchase History shows prior line totals, and eligible unit-price comparison sits in the opened receipt's menu. | Put comparable unit prices beside the corresponding purchases where evidence supports it. Keep line total and unit price clearly labeled. Preserve different-pack, currency, quantity and tax safeguards. |
| Split my receipt after correcting one line | Saving a changed line creates a draft, and finalizing a split requires a reviewed receipt. The receipt can still open Split while it needs review. | Show the concrete blocker and give the user one route back to review. Check whether reviewing allocation row by row is actually onerous before adding any bulk confirmation. |

The background and review findings describe the app at the start of Phase 12. Their frequency in real use is still unknown. Phase 11 established that core phone journeys work and included no measurement of how often a person abandons an import or revisits a draft.

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

## AI Recognition settings and recovery

Use one native Settings screen with a status, the current model when relevant, and one primary action for the current state. Keep key replacement, model selection, usage and provider links under secondary controls.

| State | Primary action and behavior |
| --- | --- |
| No key | **Connect Gemini** opens key entry. Explain that verification sends a fictional test image and uses the user's API allowance before they start the test. |
| Key saved, model unverified | **Verify model** uses the saved key. Explain why verification is needed after a model change, including a change to the app default. |
| Verified, AI off | **Turn on AI recognition** shows Google's data-use terms for the first acknowledgment and enables AI once the user confirms. |
| AI ready | Show the active model and an **On** control. Let users change the model, replace the key, or disconnect under connection management. |
| Connection check or reading failed | Explain whether the issue is a rejected key, model availability, network or timeout, or quota. Keep a verified connection intact after transient failures. Offer the relevant next action and keep on-device reading available during import. |

Keep keys in Keychain and verify a replacement before overwriting the saved key. Verify model changes explicitly with the saved key. Each AI upload still requires approval for the exact prepared image. Returning from Settings to an active import restores its photo, crop, and privacy covers. After a failed or interrupted read, retry returns to upload review for fresh consent. Do not send a receipt from a settings check or silently retry with a different model.

Verify first-time setup, model switching, key replacement, enable and disable, offline, timeout, quota, and rejected-key cases with fictional inputs and a simulated transport. Check that Settings opened from import returns to the same preparation state, that cancel and back behave predictably, and that no receipt is sent until the user approves its upload. Review the screen in light and dark mode, with large text and VoiceOver.

## Proposed order

1. **P12-01 · Printer and recovery screen.** Build the Gemini waiting experience and make stop and failure recovery easier to understand. Verify the current upload, privacy and cancellation paths. This task does not add persistence.
2. **P12-02 · Resume an interrupted import.** Design the encrypted checkpoint and resume entry point. Test returning after an app switch, device lock and app relaunch. Make discard explicit, preserve the original, and keep any upload under fresh consent.
3. **P12-06 · Simplify AI Recognition.** Implement the connection and recovery flow above after import resume, so opening Settings or recovering from a failure preserves the prepared work.
4. **P12-03 · Save now, review later.** Remove “I checked the original” from both review layouts and allow Finish without opening the photo when validation and exact reconciliation pass. Update completion and split eligibility to use the new finish semantics, with legacy reviewed receipts and drafts retaining their existing status. Review any copy and indicators that imply photo verification. Improve the review entry point, show the first blocker and make drafts easy to find and finish. Verify one-tap Finish on a clean read, optional Original access, blocked Finish for missing required fields or mismatched amounts, and split eligibility after Finish. Use pilot observations to decide whether to shorten the photo and method steps.
5. **P12-04 · Find and compare a purchase.** Make recorded unit prices and eligible comparisons easier to reach from Purchase History. Check the handoff from receipt review to Split and fix demonstrated friction.
6. **P12-05 · Share a receipt image.** Render the current digital receipt as a single opaque PNG with a small Sliplet signature. Provide an image preview and the iOS share sheet.

During the pilot, use the next five real receipts as they arise. Record capture-to-save time and time spent correcting if convenient. At minimum, note the reading method, whether an interruption cost work, which corrections were needed, and whether the receipt was easy to find again. Include at least one on-device attempt and one interruption scenario if practical. A five-receipt pilot informs workflow decisions. It cannot establish recognition accuracy across stores.

P12-01, P12-02, P12-06, P12-03 and P12-04 are complete. P12-05 completes the Phase 12 implementation.

### P12-02 delivery

The wallet now offers **Continue import** and **Discard** for one encrypted, local import. The checkpoint keeps the original, applied crop and rotation, privacy covers, completed recognition and applied review edits. An unfinished crop or an unapplied edit sheet reopens at the last applied state. AI resumes at the privacy step and requires fresh upload consent. Saving the receipt clears its pending import in the same database transaction. Pending imports stay on this device and are excluded from receipt backup exports.

Simulator checks use fictional receipts. Device-level file protection and Face ID remain to be checked on a physical iPhone.


### P12-06 delivery

AI Recognition shows the current Gemini model and the next action for its connection state. First-time setup verifies a fictional image before saving the key. Enabling recognition presents Google's data-use terms, and receipt uploads still require separate approval. Model changes reuse the saved key and require an explicit model check before AI can be turned back on. Key replacement, connection testing and disconnect are grouped under **Manage connection**.

Temporary connection-test and receipt-read failures preserve existing verification. Rejected keys, account access, model availability and billing errors provide specific recovery actions. Settings from an active import preserve the photo adjustments and covers. Retrying an upload returns to its preview and asks for fresh approval.

Automated provider checks use fictional images and simulated responses. Live Gemini behavior and the physical iPhone remain separate verification steps.


### P12-03 delivery

Tap **Finish** once required fields and amounts reconcile. **Original** and suggested checks are available during review. A new finished revision records the explicit finish, while legacy source-reviewed revisions and drafts retain their existing status. A finished receipt becomes eligible for splitting subject to assignment and split validation.

The **Needs review** collection is available from All receipts. A draft opens with a **Continue review** action. The first blocking issue links to the relevant field or section, and Split offers a way back to the receipt editor. Photo preparation and recognition-method selection remain as designed in P12-02 pending the pilot.


### P12-04 delivery

Purchase History shows the current purchase, each matching receipt's line total, and its recorded unit price when available. An unrecorded unit stays unspecified. Comparable candidates can open price comparison directly from the matching entry. Confirming identity and pack size applies to price comparison. Purchase History continues to discover candidates automatically. Saved comparisons appear with both rates and the confirmed tax basis, and the existing revision checks keep stale decisions out of history.

The draft-to-Split handoff was rechecked with a fictional mismatch. The Split action returns to review and its first blocker points to the printed total.


### P12-05 delivery

**Share receipt image** opens a zoomable preview of the current saved receipt. The export uses white paper, dark monospaced text, a soft gray margin and a Sliplet signature on the lower right. The image uses light paper in both app appearances. Drafts retain a visible status. It contains the digital receipt and uses an opaque RGB PNG with no original photo embedded.
