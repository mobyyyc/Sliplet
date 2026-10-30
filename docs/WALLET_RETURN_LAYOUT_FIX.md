# Wallet return layout fix — 2026-10-30

Reported: returning from receipt detail leaves papers floating above the wallet until a subsequent scroll, with small status text behind the stack.

The live stack's geometry observers previously discarded updates while a frozen receipt presentation existed. Native navigation/safe-area relayout can change the live stack origin during that interval. SwiftUI's geometry observer has already consumed that value, so clearing the presentation does not emit it again; the cached projection remains stale until another scroll changes geometry.

Live stack origin, scroll offset, end pull, stack height and pocket height now keep updating behind the presentation. Frozen paper frames and the frozen wallet rectangle still drive the entry/return animation and preserve layer order. Status notices are removed from the populated home stack, where they could appear behind projected receipts and add an unintended layout row. Existing notices remain available in Settings; receipt accessibility summaries are preserved.

Added a Simulator regression for three repeated detail returns with one, two and three receipts, asserting the original height and wallet overlap without any corrective scroll. The existing repeated-return test covers 13/30 receipts, detail scrolling and the newest receipt.

Validation completed after Xcode 27.2 component setup: app and UI test builds succeeded, and both focused Simulator tests passed. Eighteen detail-to-home returns covered stacks of 1, 2, 3, 13 and 30 receipts, including detail scrolling and the newest receipt. Returned card coordinates matched their pre-entry coordinates without a corrective swipe; short stacks remained tucked into the wallet. Inspected the one-receipt and 13-receipt returned screenshots. No stray status notice was visible behind the populated stack. No physical-phone verification or installation was performed.

Executed result: `/tmp/sliplet-wallet-return/Logs/Test/Test-T05Workflow-2026.10.30_15-22-33--0400.xcresult`.
Logs: `/tmp/sliplet-wallet-build.log`, `/tmp/sliplet-wallet-test-build.log`, `/tmp/sliplet-wallet-return-verified.log`.
Fictional screenshot evidence: `/tmp/sliplet-wallet-return-attachments/`.
