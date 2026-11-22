# P16-03 · Recovery and data preservation

P16-02 made the first saved receipt easier to complete and find. P16-03 verifies that an interrupted import remains recoverable and that saved receipts survive backup and an in-place update.

## Import recovery

A transient failure on the first checkpoint could leave the import usable on screen but unable to resume later. Subsequent writes carried only the editing state, even though the first transaction had rolled back the original photo. The workspace now includes the original until checkpoint creation succeeds and flushes an outstanding first checkpoint when the app leaves the foreground. The store writes the photo and checkpoint atomically. Queued writes for the same import update the checkpoint while retaining the existing photo.

A regression test rejects the initial SQLite checkpoint insert, restores writes, and backgrounds the workspace during photo preparation. Before the fix, the receipt could not resume. With the fix, a reopened workspace restores the original photo bytes, rotation, crop, and stage. The wallet stays empty until the user saves.

## Simulator verification

| Path | Observed result |
| --- | --- |
| Background and relaunch | Resume restores the prepared photo and covers. Returning to the AI upload step requires fresh consent. Discard removes the pending import. |
| Offline, AI timeout, and Stop | A simulated offline error returns to recovery and requires a new preview and consent before sending. Simulated timeout keeps the original accessible and allows manual entry. Stop returns to recovery with the photo available. |
| Encrypted backup and restore | Native Files export and local file selection reach the duplicate preview. A confirmed merge adds missing content and keeps existing content. Cancel keeps the wallet usable. Backgrounding clears the entered backup password. Unit coverage includes wrong passwords, altered archives, and interrupted merge rollback. |
| In-place update | On a disposable iPhone 15 Pro Simulator, installed the pre-phase source revision `e1b540a`, seeded the normal encrypted store, and installed the fixed P16-03 build over it with the same bundle identity. Both builds report version 0.3 (4). The probe verified exact record equality and byte-identical originals for all three saved receipts. One saved review draft, one split draft and one finalized split survived. The pending import and its original also matched. A normal app launch displayed all three receipts and the Continue import action. |
| Backup of the upgraded wallet | Restored to a different store key and compared the same three records and original photos. A second restore offered zero additions and skipped all three. The in-progress import is local to its existing installation. Backups cover saved receipts, including saved drafts. |

The final run used Xcode 27.2 and iOS 27.0 Simulator. Of 94 selected unit cases, 93 passed and the device-only file-protection check was skipped. Eight distinct UI cases passed across the main run and a fresh Files rerun. In the reused Simulator, the system picker omitted the test’s expected filename field. The same export and restore test passed on the final source in a Simulator with fresh Files state. The unsigned iPhone Release build succeeded. All wallets and uploads used fictional fixtures. The AI failures were injected locally. Physical hardware, real network behavior, and phone installation remain for separate on-device verification.

## Next task

P16-04 is the iPhone candidate and walkthrough. Install the signed candidate over the current app when approved, then verify the existing wallet, camera and first-save workflow, returning from the background, and reopening a saved receipt. Use a new fictional receipt for the write-path checks.
