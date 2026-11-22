# Phase 17 · Everyday experience, quality, and useful features

## P16-05 · Phase 16 closeout

Phase 16 is closed at the Simulator milestone. Keep developing the everyday experience before deciding whether to invite a small group to try Sliplet.

| Task | Outcome |
| --- | --- |
| P16-01 · First-receipt audit | The normal Photos import reached review with on-device reading and a fresh AI connection state. A previously unknown merchant exposed an extra trip to Original and manual entry. The receipt could be saved and found after correction. [Audit](PHASE16_FIRST_RECEIPT_AUDIT.md) |
| P16-02 · Save the first receipt | Merchant confirmation now offers printed header choices. Cancel discards the working edit. Both fictional Photos imports saved and reopened through item search. The disconnected AI flow still offers on-device reading. [Implementation and checks](PHASE16_FIRST_RECEIPT.md) |
| P16-03 · Recovery and data preservation | Fixed retry after the first import checkpoint fails. Simulator coverage includes resuming, discarding, stopping AI reading, injected offline and timeout paths, encrypted backup and restore, and an in-place update. Three fictional receipts, original bytes, a saved receipt draft, a split draft, a finalized split, and an in-progress import survived the update. The Files test passed on a fresh Simulator after encountering a missing filename control on a reused one. [Verification](PHASE16_RECOVERY.md) |
| P16-04 · iPhone candidate and walkthrough | Skipped at the owner's direction. No Phase 16 phone install or device walkthrough took place. |

### Keep these items open for candidate verification

- On the owner’s iPhone, perform a separately approved signed update over the current installation. Check the existing wallet, an original image, a saved draft and a saved split, where present. Use a new fictional photo for write-path checks.
- Capture a receipt on real camera hardware, check orientation, switch apps during an import, finish it, and reopen it through search. Exercise the recovery path after losing connectivity. Test a consented live Gemini submission separately if that path is in scope.
- Check physical scroll and transition smoothness, device-lock file protection, and native Files export and restore with an explicitly selected local file. Record owner observations separately from Simulator measurements. Earlier phone results apply to their respective builds.

## P17-01 · Everyday baseline complete

Five everyday journeys were exercised in Simulator. The first implementation priority is direct access to the source-backed editor from a required amount correction. Archived discovery and price-comparison friction follow later. [Measurements, reproduction, and ranked follow-ups](PHASE17_EVERYDAY_AUDIT.md).

Use the current source with an isolated fictional wallet. Start with a clean wallet and AI disconnected for onboarding. Seed a familiar wallet for repeat use. Include a long receipt with matching items near the end, compatible and incompatible repeat purchases, an archived receipt, and an itemized receipt with ambiguous tax allocation. Keep any recordings and shared screenshots fictional. Use Simulator fixtures for recognition failures. Defer separately approved device and live-provider work to candidate verification.

| Journey | Start → finish | What to check |
| --- | --- | --- |
| First and repeat import | Wallet → Photos → photo preparation → on-device reading → saved receipt → find by item | Discoverability of the plus and reading choice, required decisions, and ability to find the saved record. Compare the clean first run with a repeat import. |
| Correct one amount | Review showing one known discrepancy → locate its source → edit and apply → save | Time to reach the right row, remaining reconciliation, keyboard clearance, and return to the same part of a long receipt. Check Cancel before applying the correction. |
| Find a previous price | Home → item search → Purchase history → previous receipt → return | Make product, merchant, amount and unit easy to distinguish. Confirm that incompatible price bases stay separate and the previous query and row are restored. |
| Find a return receipt | Home → find an older purchase → open Original → back | Start with a merchant, approximate date or item name. Check the full receipt, archived discovery, and return to the same filter or result. Use this baseline to judge whether a return-date feature is worth building first. |
| Split a purchase | Saved receipt → add two people → assign or share items → allocate ambiguous tax → saved totals | Check what can be understood without opening advanced options. Verify that each participant’s amount is visible and the amounts sum to the receipt total. |

### Measurement and deliverables

- Preserve the source revision, device/runtime, fixture configuration and starting state for each run. Record taps, required fields or decisions, navigation detours and the outcome. Count a gesture once and record text entry separately.
- Time the path in segments. Record app or provider waits separately from hands-on steps, and label XCTest timings as driver measurements. Use fresh state for first-use checks. Where a stable timing comparison is useful, repeat the fixture path three times with the same starting state and record median and range. A skipped or blocked path gets a reason.
- Spot-check high-impact screens with light and dark appearances, a larger text size, Reduce Motion and VoiceOver where Simulator can exercise it. Capture a short fictional screen recording for a repeatable jump or clipping issue. Reserve phone smoothness judgments for the device check.
- Finish with a ranked issue list. Include reproduction, affected journey, impact, evidence, proposed change, and the test that would show improvement. Prioritize wrong totals, data loss, and blocked paths first, then frequent extra steps, then visual refinements. Carry forward findings that need confirmed phone or live-provider behavior with their verification status.
- P17-01 passes when all five journeys have a baseline or a precise documented blocker, the follow-up work is ranked, and the first fixes and their specific regression checks are ready to approve.

## Remaining Phase 17 tasks

| Task | Deliverable and acceptance |
| --- | --- |
| P17-02 · Import and review | Use the audit to simplify the path from import to save. A clean fixture reaches save without correction. A one-field error exposes the corresponding source, updates only the applied field and preserves the review position. Exact totals and existing draft recovery still pass. |
| P17-03 · Duplicate import guidance | Build on the purchase overview's saved-copy behavior to bring guidance into import. Test identical photos, a recaptured receipt, and genuine transactions at the same merchant with the same amount. An exact match offers the saved receipt. An uncertain match stays user-controlled and does not delete or merge anything. |
| P17-04 · Value from saved receipts | Choose one feature using the audit. For return receipts, propose a manually entered deadline and an optional reminder that opens the saved receipt. For faster price comparison, use compatible products, units, currency and price basis with supporting receipt evidence. Validate the chosen path end to end and check how old saved receipts appear. |
| P17-05 · Everyday quality and pilot decision | Rerun the agreed paths on the same fixtures and compare actions, waiting, context restoration, long and large wallets, accessibility, and interruption handling. Record phone checks after separate approval. Use those results to decide between continued personal use and a small pilot. |

**Next approval** · P17-02, focused correction and import-to-save improvements.
