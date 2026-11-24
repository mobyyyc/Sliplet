# P17-05 · Everyday quality and pilot decision

Verified the Phase 17 candidate against the [five-journey baseline](PHASE17_EVERYDAY_AUDIT.md). The application source starts from `1e56f35`. Tests used Xcode 27.2 and disposable iPhone 15 Pro Simulators on iOS 27.0, with isolated wallets and fictional receipts. First and repeat imports used the same four Photos assets and the on-device reader with AI disconnected. Two temporary debug-fixture switches reproduce the baseline's unique archived match and different printed price units. The recognition failure cases use local injected responses.

## Everyday journeys

| Journey | P17-01 baseline | P17-05 result |
| --- | --- | --- |
| First use and repeat import | 9 taps, no scrolling, one search entry | 9 taps, no scrolling, one search entry per run. All four saved with no correction and reopened by item. The first local read reached review in 2.46 s versus 2.53 s. Repeats took 2.47 s median (2.45–2.48 s), versus 2.59 s at baseline. Repeat save-to-detail took 2.52 s median (2.50–2.52 s), versus 2.65 s. |
| Correct one amount with Cancel and retry | 8 taps, 2 scrolling gestures, two amount entries | 7 taps, two scrolling gestures and two amount entries. The required-field action opens the image and amount together. Cancel keeps the missing amount, and applying the correction enables Finish. Corrected Finish reached detail in 2.51 s versus 2.55 s. |
| Find a previous price | 7 taps, no scrolling, one search entry | 7 taps, no scrolling, one search entry. A late matching line highlighted in the older receipt, and backing out restored the query and result position within 14 points. Each and kilogram still blocked comparison. |
| Find an archived return receipt and return from Original | 8 taps, no scrolling, one search entry | 6 taps, no scrolling, one search entry. Include archived takes one tap instead of the three actions in Filters. Returning from Original retained the same query, scope and result within 12 points. A separate regression kept the merchant filter and verified that a genuine miss has no shortcut. |
| Split a purchase between two unnamed people | 10 taps, no scrolling or text entry | 10 taps, no scrolling or text entry. Assigning unclaimed items opened one tax question. Both displayed amounts reconciled to the total and stayed the same after reopening. Finalize-to-totals took 2.77 s. |

The four local imports reused the same images and the same initial and repeat states as the baseline. The reading and save timings include XCTest waits. The history opening segment took 3.98 s versus 3.12 s, and archived result to Original took 7.36 s versus 5.88 s. These are single samples and serve as a reference for the phone check.

A separate system Photos run used a fresh wallet. The exact original opened its saved receipt and retained its prompt after the app was backgrounded. A separately rendered image of the same basket offered a choice before saving. A different basket with matching merchant, date and total saved without a duplicate prompt.

## Large wallets and accessibility

| Fictional receipts | Mounted papers before and after a drag | Cold relaunch to ready | Detail round trip | Search to result count |
| ---: | ---: | ---: | ---: | ---: |
| 10 | 8 → 10 | 8.77 s | 4.03 s | 1.93 s |
| 50 | 8 → 10 | 6.34 s | 3.03 s | 2.90 s |
| 200 | 8 → 10 | 5.49 s | 3.20 s | 2.06 s |
| 1,000 | 8 → 10 | 7.14 s | 3.76 s | 2.53 s |

At every size the wallet reopened from disk, kept the card position on return, opened the monthly total and its receipt list, and searched the full wallet. The two larger stores also found an older result across the year boundary. The 31-item receipt reached its total above the detail controls from Purchase overview. Mounted papers count the visible accessibility hierarchy at two positions. The times are single XCTest driver samples under concurrent Simulator runs and include UI queries and idle waits. Physical responsiveness and frame pacing remain open.

Search filters and purchase history passed with the Simulator system set to its largest accessibility text size. Filters opened at 21 points above and below the center of the native control. Applying a merchant filter and opening the matched original preserved the query and filter on return. At that text size, Purchase history requires scrolling to Other purchases. Opening the previous receipt made the matching line reachable and highlighted, and returning restored the query. Scoped accessibility audits ran on search, purchase history and focused correction. Other checks covered Reduce Motion, increased contrast, opaque controls and both appearances. Real VoiceOver operation remains a phone check.

## Interruption and storage

Backgrounding and relaunch restored the import checkpoint, including photo preparation and redactions. A stopped or timed-out read kept the original available, and an injected offline failure required a new upload preview and fresh consent. The required amount could be left as a draft after interruption, reopened and finished after correction. Simulated authentication covered returning within the grace period and hiding the in-progress import on immediate lock. A debug-only import button was made icon-only so it fits alongside the wallet toolbar during the lock test.

The native Files path exported an encrypted backup to On My iPhone, selected that file for restore, and showed three existing receipts with zero additions. The first run did not expose the expected filename field. The local Files round trip passed on a different isolated Simulator where the field was available. Unit checks covered interrupted writes, exact originals, restore merging, wrong passwords, and split reconciliation. SQLite reported unlink warnings in temporary unit-test databases, where fixture teardown can remove a file while the asynchronous close finishes. All affected tests passed. The warnings occurred on temporary test paths.

## Verification summary

145 selected unit tests and 28 distinct UI tests passed across the final scoped runs. The unsigned iPhone Release build succeeded. The initial runs exposed two stale large-text test paths, a test toolbar overflow, a native Files filename field missing on one Simulator, and an assertion that expected one specific outcome for an odd-cent split between randomly identified people. The final split probe checks both valid allocations against the same total and confirms that each person’s amount persists. The verified test changes use current public controls and scroll to lazy rows. Real camera capture, Face ID, VoiceOver, live AI, and phone responsiveness remain open for candidate verification.

## Candidate decision

Continue personal use through a signed, in-place candidate walkthrough before inviting external testers. The Simulator closeout proposed the [owner’s iPhone 15 Pro walkthrough](PHASE17_DAILY_USE.md#keep-these-items-open-for-candidate-verification). Check retained receipts and originals, capture a fictional receipt, finish after an interruption, verify real Face ID and VoiceOver, and export and select a local backup. A live provider check, if needed, requires its own consent. Revisit the small pilot decision after the device results.

On November 24, 2026, the owner skipped the walkthrough and chose to continue with [Phase 18 · Everyday interface refinements](PHASE18_UI_UX.md).
