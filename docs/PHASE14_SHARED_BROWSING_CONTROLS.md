# Phase 14 · Shared browsing controls

Owner-requested revision, November 17, 2026.

## Interaction

Wallet and List share the same browsing toolbar: A compact Wallet / Receipts / Search title on the leading side; Search and Filters grouped on the trailing side, followed by a separate Settings button at the far right. Remove the standalone month selector, information button and view-switch button. Display mode moves into Settings. Keep receipt import as the bottom primary action in either mode.

Search uses the same query and scope in either mode. Filters apply to both the paper wallet and list. A filtered empty wallet must offer Clear filters rather than suggest that receipts have disappeared.

## Filters

Use a native Form sheet with working-copy Apply/Cancel and Reset. Offer collection, merchant, and an exclusive date choice: Any date, Month, Specific date, or Date range. Native date pickers use inclusive date bounds. Offer optional receipt-total minimum and maximum. Validate reversed dates, malformed amounts and reversed amount bounds before Apply. Amount filtering must select a single currency whenever the data contains multiple currencies; currencies must not be compared as equivalent amounts. Missing totals or dates are excluded only when the corresponding constraint is enabled.

Show a discreet active-filter indicator and result count. Avoid permanent configuration rows and repeated explanatory text. Active search retains access to Settings and Filters when native search hides navigation toolbar items.

## Efficiency and verification

Prepare filtered identities and month geometry when saved receipts or query/filter inputs change. Keep viewport rendering bounded and retain valid receipt anchors through filter/view changes. Use existing native List swipe actions and cached search indexing.

Verify shared results, month/exact-date/inclusive-range boundaries, amount/currency handling, reset/cancel/apply, empty results, opening/return position, large text, dark/light appearance and native hit areas. Installation is separate from this navigation change.

## Implementation and scoped verification · November 18, 2026

The shared toolbar is implemented: grouped trailing Search and Filters followed by separate far-right Settings, with a compact leading title. Month jumping and the display toggle no longer occupy the toolbar. Settings contains a persistent Wallet/List choice and wallet information. Import remains the bottom primary action in both views. Search temporarily presents the native result list without changing the preferred display mode; closing search restores ordinary browsing. Native search uses avoidHidingContent to retain the toolbar, without a custom duplicate control bar.

The native filter Form provides collection, merchant, month, specific day, inclusive date range and receipt-total minimum/maximum in an explicit currency. Apply/Cancel is transactional. Invalid or reversed amounts/date ranges block Apply. Wallet and List derive the same receipt identities from one cached result set. Active conditions have compact labels and can be cleared; filtered empty states offer Clear filters. Wallet counts distinguish matching receipts from saved receipts. Search keyboard dismissal precedes filter/settings presentation.

Twenty focused unit methods passed, covering shared identities, exact/inclusive amount bounds, date endpoints, currency isolation, validation, scope resets, source search, privacy clearing and cached wallet geometry. Two fictional Simulator UI journeys exercise both toolbars, filter/apply/reset, empty results, the Settings display choice, search/detail/return and native date-range controls in light/dark appearance. Production Release compilation also passes after guarding two existing debug-only typography fixture references. This is scoped verification, not a complete rerun of older navigation-specific UI suites or a human accessibility/performance walkthrough.

Next roadmap task remains P14-04 Purchase overview, pending owner approval and explicit accounting inclusion rules.

Fictional Simulator screenshots: [List toolbar](design/phase14/evidence/shared-controls/shared-list-toolbar.png), [active search](design/phase14/evidence/shared-controls/shared-active-search.png), [date range](design/phase14/evidence/shared-controls/shared-date-range-filter.png), [empty filter result](design/phase14/evidence/shared-controls/shared-wallet-empty-filter.png).

The signed Release build was installed in place on the paired iPhone 15 Pro on November 18, 2026 using the existing com.mobyyyc.RcpLens identity. No uninstall or wallet replacement was performed. Existing-receipt visibility and owner interaction acceptance are not claimed by the installation result.

The owner refined the placement on November 18: all actions occupy the upper right, ordered Search, Filters, then a separated Settings control. The leading title indicates Wallet, Receipts or Search. The redundant large List heading and empty-wallet heading are removed to preserve vertical space. Native UI checks verify button order and the existing search/filter/display-mode journeys.
