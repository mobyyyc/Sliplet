# Phase 3 personal UX walkthrough

The signed 0.3/build 4 candidate is prepared in Main; installing it on the phone requires the next approval. This updates the same stable app in place using the existing Personal Team; retain receipts and never uninstall/reset. The previous 0.2/build 3 icon update and initial three checks are historical below.

After the update, use Main only and check:

1. Open/unlock and verify the existing receipt count plus one Original. Open a reviewed receipt → Edit: the original-review confirmation should remain checked. Cancel without editing should return directly to the same scroll position. Finish without editing should preserve any finalized split. Change an actual value: confirmation must clear and Cancel must ask to discard.
2. On Home, reveal a left swipe action, then swipe right: the receipt should move continuously back to center. Use a separate right swipe to expose the other action. Repeat on receipts at different heights; enter/return several times and check for jumps or visible pauses.
3. Search for an item, open a result, view Original, return and clear the search. The detail should use the short upward fade, with no home-wallet departure animation or covering Import button. Try a long receipt, scroll to the bottom, edit/cancel, and verify the same reader position.
4. Add a split participant using Return/Add above the keyboard. Save or finalize an existing split, Done, then immediately Edit receipt. Try original double-tap/pinch/reset, photo rotation and the focused comparison. Confirm controls remain reachable with larger text, Reduce Motion and VoiceOver.

Report which step fails and whether you see a jump, covered control, delayed response or lost state. Keep receipt content local. These phone observations validate physical UX; Simulator passes do not prove zero lag. Phase 2 backup/offline receipt and human accuracy/time checks remain open.

---

# Historical personal v0.2 iPhone walkthrough

Approved in Main on 2026-10-11. This is one guided physical test, not another feature phase. Continue replying in Main. The prior signed milestone is `e419d15` (`feat: add portable encrypted receipt backups`).

## Prepare and update

Connect the same iPhone 15 Pro by USB, unlock it, and retain the existing Sliplet installation. Main builds Release v0.2/build 2 with version overrides, the existing Personal Team and the stable bundle `com.mobyyyc.RcpLens`. Installation updates the app in place; no uninstall, reset, synthetic launch arguments or data copying. The project version fields still read 0.1/1; an ordinary Xcode Run without overrides does not identify this test candidate as 0.2/2.

Keep original receipt photos and paper receipts. Before starting the update, note your receipt count and any important drafts, stars/archive choices and splits. If the installed version already offers encrypted backup, export one first. An older version without backup cannot perform that step; verify retained data immediately after the update before making edits. An in-place install is not itself a backup.

## Check 1 — existing wallet

Open Sliplet, unlock using the configured method, and compare your receipt count. Open one existing receipt and its Original. Check its edits and, if present, draft/star/archive/split state. Report only whether these are retained, plus aggregate counts if useful. Do not paste prices, OCR or private photos into public evidence.

## Check 2 — backup without deleting anything

1. Settings → Export encrypted backup. Enter and confirm a password of at least 12 characters; keep it separately. Save to an explicit local Files folder, such as On My iPhone. Confirm the file exists and Sliplet reports it saved.
2. Settings → Restore from backup. First enter a wrong password and select that file: expect rejection and an unchanged wallet.
3. Reopen Restore, enter the correct password, and select the same file. Expect New receipts = 0; existing receipts are skipped. Add is disabled when there is nothing missing. Close without deleting any receipts.
4. Cancel the file picker once and reopen it; the wallet should remain usable. Lock/background during password entry, return/unlock, and check that the old password or prepared preview is gone.

This safely checks the real phone Files/password/duplicate path. It does not independently prove missing-receipt restore on a second physical device; that remains pending, with isolated automated coverage from P2-05. Do not delete your wallet to simulate it.

## Check 3 — one fresh receipt offline

Use one new No Frills, Costco or T&T purchase first. Turn on airplane mode and explicitly turn off Wi-Fi. Import receipt → Take a photo. Use even light, all receipt edges visible, no glare and readable small print. Retake if needed; Use photo starts on-device Vision recognition without Apple Intelligence.

Record approximate seconds from Use photo to review. Start a second timer when review is ready. Try Check first and the focused photo comparison, correct explicit errors, compare every line against the original, then finish only after source review and matching totals. If it cannot be completed, Save draft and report what blocked it. Matching totals alone do not establish accuracy.

Reply with store, short/long/poor-photo category, number of purchase lines, missing/extra/wrong amounts, approximate processing seconds, approximate review-to-save seconds and whether completion or a draft succeeded. Keep detailed values and images local. A second capture of the same purchase is not another independent purchase.

## Later checks — after the first receipt

Repeat with the other stores, including a long receipt. Check bottom access, original zoom/source alignment and focused Cancel/Apply. Reopen after restart; try search, archive/star, an exact split and immediate Split Done → Edit. Exercise Face ID cancellation/passcode fallback and the chosen five-minute grace period. Try large text, VoiceOver and Reduce Motion. Main records actual outcomes rather than treating old Simulator passes as phone results.

## Status and limits

Preparation, install and each physical observation are recorded separately. The task remains in progress until actual results arrive. Recognition targets (95% purchase recovery, 90% merchant/date/total, median review below 30 seconds) remain unmet or unmeasured; a few personal sessions cannot certify general accuracy. Keep repeated shopping sessions and an untouched comparison set for later aggregate measurement.

Full protocol: [Personal release checklist](PERSONAL_RELEASE.md).

Preparation result (2026-10-11): signed Release v0.2/build 2 compiled and verified, then installed over the existing 0.1/build 1 app on the user-selected iPhone 15 Pro. Device metadata confirms 0.2/2. The launch request was rejected because the phone locked; user unlock/manual opening remains necessary. No uninstall/reset, source-code change or private phone data extraction occurred. Actual wallet retention and hardware behavior await user observation. [Preparation evidence](evidence/phone-v02/preparation.json).
