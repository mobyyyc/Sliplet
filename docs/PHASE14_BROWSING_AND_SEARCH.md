# P14-03 · Browsing, search and return flow

November 17, 2026. The owner approved P14-03 and requested a simpler search interface. Implementation and scoped Simulator verification are complete.

## User experience

- The toolbar collection menu opens All receipts, Needs review, Starred and Archive directly. Wallet/List remains the upper-right circular glass button.
- During active native search, a compact safe-area control bar keeps collection and filters available even while iOS hides the navigation toolbar.
- Filters use a separate native sheet with Store, Month and Include archived. Cancel preserves the current view. Apply commits the selections together. Active conditions have removable chips; the unfiltered list has no default-status paragraph or filter configuration rows.
- Result rows lead with merchant and price, followed by item and date. Month headers organize receipts. A compact receipt count replaces the earlier standalone summary section. Search accepts a merchant, item or code.
- A matched receipt has a compact item heading, Original and Purchase history. Current merchant-name matches open the regular receipt without a repeated merchant banner. Match details holds the optional full text/code evidence. A linked current item receives the existing soft receipt highlight.
- Current purchase prices remain distinct from original-only evidence. An unlinked or removed original hit is labeled Original text only and has no invented current item amount.
- Search terms, collection and applied conditions survive reading, editing, original viewing and purchase-history navigation. Explicit filters stay selected even if an edit removes their last matching value; the visible filter can be cleared deliberately.
- Returning to results preserves the selected receipt and its position within the visible viewport. When a result disappears, browsing prefers its next surviving purchase, then an earlier neighbor. Empty results retain clear filter/search controls.
- Switching from a scrolled list to Wallet focuses the nearby active receipt. Wallet and filtered/archived browsing retain separate contexts. Switching views does not unarchive anything. A view round trip without browsing preserves the previous wallet position.
- Saved date changes update month membership. Wallet return snapshots are prepared against the new layout before the paper returns. Archive/delete choose a surviving wallet anchor. Saving a new import opens its receipt while retaining existing browsing criteria.

## Audit and repair record

| Observed issue | Resolution |
| --- | --- |
| Filter configuration, default scope, receipt count and results occupied separate blocks | Toolbar collection/filter controls, a transactional filter sheet, active-only chips and a compact section count |
| Search detail repeated Search match, Current receipt match and several full-width explanations | Compact item/actions; source evidence and codes move into optional details |
| Default result rows repeated recognition/provenance labels | Ordinary rows emphasize purchase information; original-only hits remain explicit |
| The current search list was regrouped and reformatted during view updates | Memory-only row/section snapshot and cached month titles refreshed on data/criteria changes |
| Switching to Wallet did not follow a purchase browsed in List | Stable receipt identity carried into a deterministic wallet focus request |
| Edits could silently reset a store/month filter when its last value disappeared | Keep the chosen condition and expose a clear removal action |
| Native List restored a stable row at the center instead of its previous screen height | Resolve the same native scroll view and align its saved row position after identity restoration |
| Month reordering could release an outdated retained wallet layout after detail | Prepare fresh retained records, geometry and departure frames before reverse transition |
| Native search hid the toolbar filter control after typing a query | Descendant search-state controls keep collection/filter access within the search surface |
| Empty-wallet startup could evaluate a retained paper child against a newly cleared layout | Each render captures records, offsets and sections together; layout-generation geometry ignores obsolete callbacks and empty wallets reset positioning |
| Active-search collection menu exposed only an 18-point label to the hit-region audit | Give its interactive label a 44-point minimum, bound the symbol size, and verify regular/large-text controls plus the native accessibility audit |
| Native grouped-header secondary styling compounded and made headings too faint | Explicit semantic label colors, with secondary dates and count metadata |

## Implementation and efficiency

ReceiptBrowsingSnapshot contains stable row IDs, grouped sections and identity lookups. ReceiptWorkspace prepares it when receipts, query or criteria change. Month titles are cached from receipt-date groups. Native List supplies cell reuse, selection, scrolling and swipe actions. Only nearby measured row frames are retained for browsing restoration; the scroll-idle path does not scan every receipt.

ReceiptListScrollAccess keeps a weak reference to the public UIScrollView backing visible native cells. It changes content offset only for explicit restoration/reset; it does not replace delegates, gestures or swipe actions and does not inspect private class names. The row is first reached by native identity scrolling, then aligned to the saved global row position within current safe bounds. Content is revealed after alignment. A bounded fallback reveals the same result if a future native implementation cannot supply the backing view, so restoration cannot leave an indefinitely blank list.

Wallet grouping and nearby paper rendering continue to use the cached Phase 14 geometry. Data-change focus requests preserve receipt identity and prepare the updated retained scene before returning. Each wallet render retains its matching records, offsets and section metadata before SwiftUI evaluates deferred children. Generation-tagged geometry ignores stale callbacks after empty/startup changes. Original image decoding stays in the existing asynchronous detail path. Recognition, API connections, stored receipt formats and encrypted-backup behavior are unchanged.

## Verification

Twelve distinct UI methods have passing evidence across the full run and focused reruns. The full selection passed 11/12 and found a small collection-menu hit area. After that fix, all three affected control/accessibility reruns passed. Eighteen final unit methods passed, with no failures or skips. The focused checks include native calendar date changes, archive/restore/delete/relaunch, fictional import/review/split/share/relaunch, original-only evidence, long receipt scrolling, Unicode/code search, 500-receipt filtering, larger text, Wallet/List identity transfer and exact search-row restoration. The native element-detection, hit-region and sufficient-description audit passed after repair; this is not a human VoiceOver walkthrough.

The 30-receipt wallet round trip averaged 1.802594 seconds clock and 0.487526 seconds CPU across three samples. P14-02 averaged 1.801454 and 0.488566 seconds respectively: clock +0.06% and CPU -0.21%. These are small observed differences in one Simulator journey, not frame/hitch or physical-phone measurements.

[Aggregate results, native samples and fictional screenshots](design/phase14/evidence/p1403/README.md) retain the evidence. Earlier verification caught the empty-wallet deferred-layout crash and active-search toolbar/accessibility issues documented above; the repaired paths passed subsequent checks.

## Scope and next task

Simulator checks do not establish physical-phone latency or hitch-free rendering. Device installation and owner acceptance remain separate approved work. Search/restoration state is memory-only and clears when the wallet locks.

Next approval: **P14-04 · Purchase overview**. Define which drafts, archived receipts, refunds and possible duplicates contribute before implementing month totals, receipt counts and merchant summaries. Different currencies must remain separate.
