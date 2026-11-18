# P14-03 fictional verification evidence

All screenshots use isolated fictional stores. No private receipt or cloud request was used.

The full UI selection passed 11 of 12 methods, detecting a small collection-menu hit area during active search. After increasing its label to a 44-point minimum, all three focused reruns passed: active filtering, large-text controls and the native element-detection/hit-region/description audit. All 12 distinct UI methods therefore have passing evidence across these runs. The final 18 unit methods passed without failures or skips. [Aggregate results](validation.json).

The UI scenarios cover current and original-only evidence, Unicode and codes, 500-receipt filtering, calendar date changes, return position, Wallet/List identity, direct Archive access, archive/restore/delete/relaunch, long paper, and fictional import through review/split/share/search/relaunch. Unit checks cover snapshot identity, surviving neighbors, transactional filters, retained scope, index/store consistency, privacy clearing and bounded month geometry at 1,000 receipts.

[Clean list](clean-list.png) · [Filtered search](filtered-search.png) · [Filters](filters.png) · [Search detail](search-detail.png) · [Large text in dark mode](large-text-dark-search.png) · [Wallet after List browsing](wallet-from-list.png)

The [native wallet CSV](native-wallet.csv) retains three 30-receipt open/return clock and CPU samples. Clock includes XCTest taps and idle waits. Resource samples do not establish device frame rate, hitch duration or human-perceived smoothness. Physical-device acceptance remains separate.

Reproduce with the T05Workflow scheme and ReceiptBrowsingUITests, ReceiptSearchUITests and WalletInteractionTests/testCrowdedWalletRoundTripResourceBaseline. Use the Sliplet scheme for ReceiptBrowsingTests, ReceiptSearchTests and ReceiptWalletLayoutTests. Select an available iPhone Simulator and set DEVELOPER_DIR to /Applications/Xcode.app/Contents/Developer.
