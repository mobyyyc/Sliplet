# Wallet return layout fix — 2026-10-30

Reported: returning from receipt detail leaves papers floating above the wallet until a subsequent scroll, with small status text behind the stack.

The live stack's geometry observers previously discarded updates while a frozen receipt presentation existed. Native navigation/safe-area relayout can change the live stack origin during that interval. SwiftUI's geometry observer has already consumed that value, so clearing the presentation does not emit it again; the cached projection remains stale until another scroll changes geometry.

Live stack origin, scroll offset, end pull, stack height and pocket height now keep updating behind the presentation. Frozen paper frames and the frozen wallet rectangle still drive the entry/return animation and preserve layer order. Status notices are removed from the populated home stack, where they could appear behind projected receipts and add an unintended layout row. Existing notices remain available in Settings; receipt accessibility summaries are preserved.

Added a Simulator regression for three repeated detail returns with one, two and three receipts, asserting the original height and wallet overlap without any corrective scroll. The existing repeated-return test covers 13/30 receipts, detail scrolling and the newest receipt.

Validation: app build and UI test build both succeeded with Xcode 27.2. UI execution is pending: Xcode updated, but the running CoreSimulator service was older than the required build and startup/component setup stalled. No passing visual test or physical-phone verification is claimed. The user was asked to finish Xcode component setup. No receipt data was deleted or phone app installed.

Logs: `/tmp/sliplet-wallet-build.log`, `/tmp/sliplet-wallet-test-build.log`, `/tmp/sliplet-wallet-return.log`.
