# P14-01 · Receipt browsing design

November 17, 2026. The owner approved P14-01 and added efficiency as an explicit requirement.

Open [the interactive studies](index.html). The controls select 5, 50, 200 or 1,000 fictional receipts, light/dark appearance, larger text and Reduce Motion. Each study supports month/year jumping, Wallet/List switching, item search, Starred, Archive, a purchase-overview entry and receipt open/return. Import choices illustrate the route into the current capture flow.

## Recommendation for P14-02

Implement **Month sections**, together with the first-level Wallet/List control and direct month jump.

Each receipt exposes its merchant, date and amount before opening. Month boundaries create a visible pause between groups. Every receipt retains its own entry. The List view provides a denser reading surface when locating an older purchase or comparing rows.

The continuous-wallet alternative uses the same navigation and bounded rendering. It fits more compact previews across month boundaries, but the transition between periods remains less apparent. Both concepts use the same direct-month route, so the design choice concerns orientation and density as well as access effort.

The prototype recommends larger gaps at month boundaries and a single wallet pocket. Grouping follows recorded dates. The initial wallet position shows the latest dated purchases; Date unavailable remains reachable through the same month control and continuous browsing. Wallet order runs older to newer, with newer paper layered in front. List order runs newer to older. View switching keeps the previously viewed purchase visible. Returning from its detail restores the exact prior scroll position.

### Everyday routes

| Intent | Route in both studies | Design-level actions |
| --- | --- | --- |
| Open a recent receipt | Tap its visible merchant/date/amount summary | 1 |
| Find a receipt in another visible year/month | Jump to month → month → receipt | 3 |
| Find a receipt in an older year | Jump to month → choose year → month → receipt | 4 |
| Scan a denser collection | List | 1 |
| Find an item | Search → enter merchant/item/code → receipt | 3 |
| Browse archived or starred receipts | Collection → Archive or Starred → receipt | 3 |

These counts describe control selections. They exclude text entry time, the platform picker's individual gestures and any extra scrolling needed to identify the wanted receipt within a selected month. Human task times remain unmeasured.

## Efficiency design

The browser studies build sorted groups and row offsets when the collection, query, view or text size changes. Scrolling uses a binary search over cached offsets and mounts only the nearby receipt elements. The full logical scroll extent and month index remain available. Detail open/return retains that extent and the browsing position.

The 1,000-receipt browser study mounted at most 13 receipt elements in either variant during the recorded paths. Its measured 95th-percentile JavaScript paint work was approximately 0.6 ms and layout work 1.2 ms in this run. These cover instrumented JavaScript execution and synchronous layout observed by this prototype. They exclude browser composition, GPU work and input-to-display latency. They establish browser prototype behavior, while native iOS implementation and hardware animation measurements remain later work.

### Native implementation constraints for P14-02

- Reuse the existing bounded receipt rendering and retained selected-paper scene.
- Prepare date groups and stable receipt-to-offset lookup when receipt data changes. Scroll updates should operate on cached section geometry and the visible slice.
- Mount the visible papers and a small overscan margin. Keep a logical extent for reaching every receipt.
- Reuse the static atmospheric image and the app's paper-appearance setting. Keep shadow and glass work bounded to displayed surfaces.
- Keep original-photo decoding outside scroll updates. Detail navigation reuses the existing asynchronous source path.
- Anchor restoration uses receipt identity and local offset. Date edits, imports, archive/restore and deletion update that anchor deliberately.
- Compare the same scripted native journey on the same Simulator/device before and after implementation. Investigate a repeatable increase in CPU or automated round-trip time before accepting the change. Record visible view counts at 50, 200 and 1,000 receipts.
- Check touch and VoiceOver access to each visible receipt. Larger text uses separated readable cards. Reduce Motion uses the equivalent short transition.

These are implementation acceptance requirements. P14-01 has measured the current native baseline and the browser studies.

## Verification

The [browser report](evidence/browser-checks.json) records 88 passing checks. The checks cover exact fictional totals, individually reachable receipt entries, old-month jumps, item search, view switching, detail return, undated receipts, direct collections, bounded rendering, narrow layout and the overview/import entries. Screenshots show five receipts, a month boundary, a 200-receipt list, dark wallet and larger-text dark list.

The existing native XCTest `WalletInteractionTests/testCrowdedWalletRoundTripResourceBaseline` passed on the iPhone 15 Pro Simulator, iOS 27.0, against app revision `57b8857`. Its three measured 30-receipt open/return rounds averaged:

| Metric | Recorded baseline |
| --- | --- |
| Automated round-trip clock time | 1.795566191 s |
| App CPU time during the measured round trip | 0.4729295197 s |

The [native metrics export](evidence/native-wallet-baseline.csv) retains the individual samples. Clock time includes XCTest taps and idle waits. CPU time describes the Simulator process. The metric export's zero baseline column is a framework placeholder. These measurements provide a repeatable starting point for P14-02. Native frame rate, hitch duration and physical-phone responsiveness remain unmeasured in this task.

### Reproduce the browser checks

Use an existing Playwright installation and Chrome:

```sh
PLAYWRIGHT_MODULE=/absolute/path/to/playwright \
node docs/design/phase14/verify.cjs
```

The prototype runtime uses local project files. Its browser-check runner is a review tool.

## Scope and next approval

P14-01 delivers these design studies, the recommendation and the performance constraints. The next task is **P14-02 · Implement receipt organization**, with approval of the chosen layout in Main.
