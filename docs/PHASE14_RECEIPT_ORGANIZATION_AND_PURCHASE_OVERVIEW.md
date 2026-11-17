# Phase 14 · Receipt organization, purchase overview and everyday UX

Planned on November 17, 2026. The owner approved P14-01 and requested efficient interactions and rendering. P14-01 is complete with two interactive studies and a recommendation. The owner approved P14-02 with a circular upper-right Wallet/List switch that does not reserve a separate row. P14-02 is complete in Simulator: seven UI methods and 15 unit methods passed. [Implementation and efficiency results](PHASE14_RECEIPT_ORGANIZATION_IMPLEMENTATION.md).

## Product intent

As the collection grows, users should recognize individual receipts, orient themselves in time and reach an old purchase directly from everyday browsing. The owner wants to balance the wallet's tactile paper presentation with convenient access. Purchase overviews and further UI/UX refinement belong in the same phase.

## Current implementation observations

- ReceiptWalletScene renders a continuous chronological stack with an elastic projection. Nearby papers separate in a reading zone and compress at the wallet opening. Visible rendering is bounded, but every unarchived receipt belongs to this one stack. Month boundaries and a date-jump control are absent from the home scene.
- ReceiptPurchaseHistoryView already groups the library by month and offers merchant/month filters and search. ReceiptHome currently opens that surface through the magnifying-glass action named All receipts. The relationship between browsing and searching needs a clearer first-level presentation.
- The empty-wallet message directs people to Settings for archived receipts. Archive and Starred belong in the receipt-browsing navigation.
- The owner reports visual clutter with more receipts. The observations above identify design targets. Large-collection prototypes and interaction checks are still needed to choose a layout.

## Proposed browsing direction

### First-level access

Provide a circular Wallet/List button at the upper right of the main receipt-browsing surface. Its icon names the destination view; no permanent segmented-control row is used. Wallet presents the paper/pocket experience; List presents compact, readable receipts grouped by month. Search is an explicit action within browsing. Archive and Starred are directly accessible collection choices. The current collection and any applied filters are visible.

### Time organization

Explore month separators or paper tabs within the wallet presentation, together with a month jump control. A month jump scrolls to that section. Continuous browsing across months remains available. Each receipt has its own tappable summary containing merchant, date and amount.

The initial prototype must demonstrate past receipts in the normal browsing surface. It must give each receipt enough exposed information to identify it. A full preview can expand on selection. Month labels and counts orient the user, while each month's receipts retain individual entries. Grouping is automatic from the receipt's date. Missing dates use an explicit Date unavailable section.

The prototype must specify chronology, paper depth and the selected paper's return position together. The accepted wallet layering, paper shadows and extraction motion guide this decision. At large text sizes, readable separated receipts provide the equivalent journey.

### Two prototypes for P14-01

1. **Month sections in the wallet.** Time boundaries divide the paper presentation, with merchant/date/amount visible on each receipt and a direct month jump.
2. **Continuous wallet with a visible browsing switch.** Refine exposed paper summaries and time cues, and place the existing month-grouped library one tap away through Wallet / List.

Both prototypes must show 5, 50 and 200 receipts and an older month reached from the main surface. Compare readability, effort to find an old receipt, access to recent receipts, visible density and continuity when opening and closing a receipt. Present the recommendation and trade-offs for owner approval before implementing the selected home layout.

## Proposed tasks

| Task | Deliverable | Acceptance |
| --- | --- | --- |
| P14-01 · Organization and navigation design | Examine current browsing with larger fictional collections. Produce the two home/browsing prototypes and a recommendation. Define navigation, month jumping, card information and the route to Purchase overview. | The owner can inspect recent and older months. Every receipt has an identifiable entry. Search, Archive and Starred are reachable from the main browsing surface. Present the design for approval. |
| P14-02 · Implement receipt organization | Build the selected wallet/browsing arrangement, automatic date grouping, readable previews and direct period navigation. | Verify few receipts and larger collections, missing dates, dark/light and large text. Opening and returning restores receipt location, grouping and depth. |
| P14-03 · Browsing, search and return flow | Integrate Wallet / List, collection choices and search/filter navigation. Reuse current history and search representations. | Preserve collection, query, filters and location after reading, editing and purchase-history navigation. Verify import, archive, restore, deletion and date edits around month boundaries. |
| P14-04 · Purchase overview | Design and implement month totals, receipt counts and merchant summaries, with drill-down. Define the treatment of refunds, drafts, archived records, possible duplicates and multiple currencies before implementation. | Totals reproduce included receipts exactly. Different currencies are displayed separately. Each summary opens its contributing receipts and returns to the same period. Confirm material accounting preferences with the owner. |
| P14-05 · Focused UI/UX refinement | Audit affected journeys and additional concrete issues found during this phase. Prioritize hierarchy, ambiguous actions, excess copy, blocked content, keyboard behavior and interrupted work. | Keep an issue list with reproduction, impact, fix and verification. Select changes that reduce demonstrated friction. Reuse existing design components and native interactions. |
| P14-06 · Scale and owner acceptance | Check completed journeys with 10, 50, 200 and 1,000 fictional receipts, then perform an approved iPhone walkthrough. | Record collection responsiveness, scroll/return behavior, search across years, long receipts, dark/light, large text, Reduce Motion and VoiceOver. Report Simulator measurements and owner observations with their actual scope. |

## Cross-task design checks

- Every receipt should be identifiable before opening it. Merchant, date and amount carry the preview hierarchy. Secondary item excerpts appear where space supports reading them.
- Period navigation, view switching and collection selection communicate where the user is. Returning from a receipt restores that context.
- Search opens the matching receipt with its purchase highlighted and retains the query on return.
- Main actions retain familiar placement, sizing and native feedback. Footer clearance follows rendered controls and system safe areas.
- Imports, date corrections and archived/restored receipts update groups while retaining the currently read receipt.
- Purchase totals and counts have explicit inclusion rules. Draft status, refunds and missing information remain visible where they affect a decision.
- Public screenshots and test evidence use fictional content. Reuse encrypted storage and original-source links.

## P14-01 result

The [interactive studies and design decision](design/phase14/README.md) compare month sections and a continuous wallet. Both provide direct month navigation, a first-level Wallet/List control and individual receipt entries. The recommendation is month sections with the shared browsing controls. The owner can choose the continuous alternative from the same review.

Eighty-eight browser checks passed across collections of 5, 50, 200 and 1,000 fictional receipts. Both browser studies mounted at most 13 receipt elements in the large-collection paths. The existing 30-receipt native open/return baseline also passed and its CPU/clock samples are retained. Browser measurements and native baseline scope are documented separately in the handoff.

## Efficiency requirement

Browsing efficiency and running cost are acceptance criteria throughout Phase 14. P14-02 must reuse bounded native rendering, cache month geometry outside scroll updates and verify receipt-identity restoration. P14-03 retains quick period/search access and browsing context. P14-04 prepares summaries on data changes. P14-06 compares resource measurements and owner-observed responsiveness with the same journeys.

## Next approval

P14-03 · Browsing, search and return flow. Extend context preservation to filters, collections, editing and receipt organization changes after Main approval.
