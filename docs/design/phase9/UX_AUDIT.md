# P9-01 · Everyday receipt UX audit

The first change should be the screen immediately after a successful read. Sliplet already allows a correct receipt to finish without changing its fields. The friction is that every purchase appears as an editor and the confirmation lives below them all.

## Findings in priority order

| Priority | Evidence from the current experience | Design decision |
| --- | --- | --- |
| 1 · Every successful import | The review form presents editable line controls before the user has found anything wrong. In the 36-item fixture it took 18 scripted short swipes just to reach the last item in the conventional editor. | P9-02 opens on readable digital paper, in the same order as saved detail. Keep Original accessible and give confirmation and Finish a reachable place. |
| 2 · Checking the original | Original is in the toolbar, its viewer has Done, the explicit check is at the end of the form, and Finish is in the bottom controls. A successful comparison still sends the user looking for a switch. | Keep the check explicit and accessible from the review actions. Preserve the reading position when closing Original. An exact reconciliation and an independent source check still govern Finish. |
| 3 · One wrong item | The existing focused sheet already lets the user change one amount and Apply. The full form still surrounds that small edit. | P9-03 opens the focused sheet directly from the printed row or issue. Apply and Cancel return to that row. Show original context when its location is known and offer the full original otherwise. |
| 4 · Failed reading | The timeout path retains the image and offers manual entry. Showing several recovery choices requires the user to decide what to do with a photo they have already supplied. | P9-04 makes recovery with the current photo explicit. Distinguish retrying a cloud read from continuing on-device. Preserve the upload preview and deliberate Send step. |
| 5 · Wallet and retrieval | Returning to the same stack position, reversing an open swipe, and preserving a search query are separate interaction promises. A test that finds a saved receipt cannot establish smooth motion. | In P9-05 check all three with sparse and crowded wallets, then profile repeatable hitches. Retain the existing large glass import control. |

The first three findings concern effort and visual hierarchy. The navigation count measures one reproducible gesture length. It does not estimate how fast a person can flick through a receipt.

## Two sketches to review

[Open the sketches side by side](review-sketches.html) or [view the rendered image](review-sketches.png). The left sketch shows an already-checked example of a correct read. A fresh import begins unchecked. The right sketch shows one focused correction over the same paper. A default currency must be labeled as a default and unresolved amounts must remain visible. Draft remains available when Finish is blocked.

## Verification scope

iPhone 15 Pro Simulator, fictional fixtures, current build. The clean and timeout scenarios use a controlled model response through the app's preview and send flow. They isolate interaction from provider latency and camera handling. The roadmap's historical provider waits are a separate measurement. Human reading time, physical-phone animation performance, and recognition accuracy were not measured here.

## Recorded walkthrough

The focused sheet reached the missing amount directly. After Apply, Original, and Done on the 36-item receipt, reaching the independent confirmation took **20 short swipes**, followed by a tap to confirm and a tap to finish. That repeated navigation is the clearest opportunity for P9-02. [Current fictional review screen after Apply](current-review.jpg)

The Simulator passed the focused correction through Finish, the conventional last-item walk, the upload cover/consent/send flow, the image import through split/share and item search, archive/restore/delete/relaunch, and the lock settings five-minute default. The backup walkthrough reached its merge result before the UI test runner exited unexpectedly. Return from that result remains unverified in this run. Wallet navigation was exercised, but there is no frame-level measurement of its return animation.

Three isolated UI walks also passed. A clean read finished with four taps after the response (Original, Done, confirmation, Finish) plus scrolling and zero editor visits. A simulated timeout kept the original accessible and allowed manual entry with Save draft. Opening a search match on a long receipt kept the match context and paper in the same scrollable detail. These fixtures did not contact a provider.
