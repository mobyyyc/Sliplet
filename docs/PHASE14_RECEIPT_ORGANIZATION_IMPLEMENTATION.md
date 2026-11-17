# P14-02 · Native receipt organization

November 17, 2026. The owner approved month sections, efficient rendering and a circular Wallet/List switch at the upper right. Implementation and focused Simulator verification are complete.

## Delivered behavior

- Wallet/List is a native circular glass toolbar button. The destination icon and accessibility label change with the active view. It has no separate vertical control row.
- Wallet receipts remain individually accessible in chronological paper order, with newer papers above older ones in depth. Month labels and additional boundary spacing separate periods within the same continuous stack.
- The leading toolbar control opens a native month chooser. Its year menu and month grid reach older periods directly. Date unavailable has its own entry. Choosing a period scrolls to it without hiding the rest of the wallet.
- The wallet initially positions its recent papers at the pocket. View switching retains the wallet scroll position. Ordinary unfiltered Wallet-to-List browsing uses the nearby receipt identity as its list anchor.
- Detail transitions use the same cached geometry as the visible stack. The selected paper and neighboring papers retain their screen positions and layer order when returning.
- Reduce Motion and accessibility text sizes use separated cards with month headers and a bounded visible range. The empty-wallet illustration is preserved; its archive hint points to List.

## Efficiency

ReceiptWalletLayout is rebuilt when saved receipts change. The separated-card layout uses shared font-scaled dimensions and the same bounded rendering path, avoiding lazy row-height estimates during detail return. It caches chronological month ranges, display titles, logical offsets and identity lookups. Scrolling uses binary searches over those offsets and renders a nearby range. Detail snapshots retain that layout for both directions of the transition. Original photos continue to load only through the existing detail path.

The elastic projection, wallet front/back structure, native swipe actions, static atmospheric background and receipt paper appearance setting are retained. Month selection has no network dependency. The fictional scale fixtures use the separate debug preview store.

## Verification

All final selected checks passed:

- Seven UI methods: circular toolbar switching, month/undated navigation, exact open/return frames, dark appearance, maximum text size, Reduce Motion, native swipe dismissal, short stacks of one/two/three receipts, and the 30-receipt resource journey.
- Fifteen unit methods: month membership and identity, missing dates, changes to saved dates/archive membership, elastic and separated geometry, bounded selection at 1,000 receipts, departure order, and the existing search-index cases.
- Eighty-eight browser interaction checks after the toolbar-button revision. Browser evidence remains separate from native app measurements.

The final native runs use the iPhone 15 Pro Simulator, iOS 27.0. [Native verification record](design/phase14/evidence/native-verification.json) retains their scope and local result paths. Fictional screenshots show [light wallet](design/phase14/evidence/native-month-boundary-light.png), [dark wallet](design/phase14/evidence/native-month-boundary-dark.png), [month chooser](design/phase14/evidence/native-month-picker-dark.png) and [maximum-text layout](design/phase14/evidence/native-accessibility-layout.png). At maximum text size, scrolling is necessary to read a large paper; the toolbar keeps view switching directly accessible and puts secondary wallet actions in a menu.

### Mounted receipt snapshots

| Saved receipts | Initial mounted papers | After month/year navigation |
| --- | --- | --- |
| 5 | 5 | 5 |
| 50 | 11 | 16 |
| 200 | 15 | 15 |
| 1,000 | 16 | 15 |

These are the recorded accessibility-button counts for the bounded scene at the tested positions, including its overscan. They are not a continuous peak-memory or frame-time profile. The native UI checks cap the selected visible range at 36 papers; independent geometry sampling checks the bound across viewport sizes and scroll positions. The [snapshot data](design/phase14/evidence/native-mounted-papers.json) is retained.

### Resource comparison

| Three-iteration mean | P14-01 native baseline | P14-02 |
| --- | --- | --- |
| Automated open/return clock time | 1.795566191 s | 1.801453873 s |
| App CPU time during that journey | 0.4729295197 s | 0.4885657853 s |

Clock time differs by approximately +0.3% and CPU time +3.3% in these samples. The same original fictional receipt-1 and three-round measurement are used; the new month chooser reaches that receipt during setup, outside the measured interval. [Before](design/phase14/evidence/native-wallet-baseline.csv) and [after](design/phase14/evidence/native-wallet-after.csv) retain the samples. XCTest timing includes taps and idle waits. This small run shows no large resource increase on the measured Simulator journey. It does not establish hitch-free rendering or physical-phone latency.

### Regression resolved during verification

Native lazy row-height estimates shifted the separated large-text stack after returning from detail. Both presentation modes now use deterministic positions and bounded mounting. Larger-text previews prioritize merchant, date and total. Frame restoration, month navigation and Reduce Motion swipe dismissal passed after that change.

## Boundaries and next task

This task provides the month grouping, direct period navigation, basic Wallet/List switching and wallet return-position behavior. P14-03 will integrate collection/filter/query contexts, list-to-wallet context, import/archive/restore/deletion/date-edit boundaries and their regression checks. No physical-device installation or owner acceptance is claimed by Simulator results.

Next approval: **P14-03 · Browsing, search and return flow**.
