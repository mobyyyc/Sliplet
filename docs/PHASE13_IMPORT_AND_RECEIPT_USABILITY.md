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

## Remaining milestones

- **P13-03 · Read, Correct & Share.** Align receipt actions across entry points. Put the blocking correction and target field first. Verify that a long image is readable and saves from the share sheet.
- **P13-04 · History & Split.** Give both unit prices a compact overview before evidence details. Surface remaining assignments and adjustments, including with large text.
- **P13-05 · iPhone Walkthrough.** Verify the import and reading paths, long receipts, wallet gestures, Face ID, light and dark appearances, Dynamic Type, VoiceOver and Reduce Motion.
