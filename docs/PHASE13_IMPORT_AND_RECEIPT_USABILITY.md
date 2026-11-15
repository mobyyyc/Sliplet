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

## Remaining milestones

- **P13-04 · History & Split.** Give both unit prices a compact overview before evidence details. Surface remaining assignments and adjustments, including with large text.
- **P13-05 · iPhone Walkthrough.** Verify the import and reading paths, long receipts, wallet gestures, Face ID, light and dark appearances, Dynamic Type, VoiceOver and Reduce Motion.
