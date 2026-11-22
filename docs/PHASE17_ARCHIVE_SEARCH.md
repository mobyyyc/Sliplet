# P17-04 · Find archived receipts from search

A search with no visible receipts now offers **Include archived** when an archived receipt matches the query and all active filters. The button applies the existing archive filter in one tap. The search text, collection, store, date and total constraints carry forward. Include archived can be removed using its ordinary filter chip. A returned receipt still carries its Archived label.

The [everyday audit](PHASE17_EVERYDAY_AUDIT.md) needed three taps in the filter sheet to recover an archived-only search. The new shortcut uses the existing in-memory search index and search matching rules. The archive check runs after an empty result, evaluates archived records only, and stops at the first eligible match without creating result rows. Empty, unsupported and genuinely unmatched queries use the ordinary empty state.

## Verification

A dark-mode iPhone 15 Pro Simulator run archived a fictional 31-item receipt. An unrelated search left the ordinary No matches state. The target item with the store filter active offered Include archived, exposed the matching receipt in one tap, and preserved both the query and store filter. The test opened the original photo and returned to the same result position, then removed the archive filter to restore the earlier search scope.

All 24 targeted unit tests and three Simulator UI tests passed. Unit coverage includes current matches, collection scope, excluded merchants and dates, total-range constraints, empty and invalid queries, and original-only evidence. The screenshots verified the compact, labeled archive button and the restored result with the Archived label. The unsigned iPhone Release build passed. The Simulator used fictional receipts, and physical iPhone verification remains pending.

## Next approval

P17-05 · Everyday quality and pilot decision. Repeat the Phase 17 baseline journeys and review accessibility, interruptions, large wallets and what remains to verify on a device.
