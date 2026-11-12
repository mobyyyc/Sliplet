# P11-01 · Whole-app UI/UX audit

Audit conducted November 5, 2026; finalized November 6, 2026. Audit/design only. Production UI and calculation behavior are unchanged. The owner approved P11-01 after requesting an app-wide audit and color-first bulk splitting.

## Method and scope

Reviewed the current SwiftUI surfaces and their state/navigation paths, then ran disposable fictional Simulator journeys. Findings distinguish source-confirmed workflow/design friction, observed screenshots, regression checks and hypotheses requiring targeted reproduction. A source pattern alone does not prove clipping or lag. Existing import phone acceptance is retained; this audit is not another recognition evaluation or a claim of complete device/accessibility certification.

Screen inventory: wallet/empty wallet/detail; collection/search/filter/archive/star; camera/import/loading/failure; paper/full review and row correction; original zoom/region rereading; split/adjustments/summary; product history/match/price comparison; settings/AI connection; lock; backup/restore. New screenshot coverage and live tests are listed in the evidence section; camera hardware and VoiceOver speech need a device pass. No real receipt upload, key access or phone-store read was performed.

## Prioritized findings

Severity reflects user impact, not security or monetary correctness. High means significant repeated workflow cost; medium means confusion, unnecessary navigation or layout inconsistency. No critical data-loss defect is established by this audit.

| ID | Priority / evidence | Finding and reproduction | Fix / acceptance | Owner |
| --- | --- | --- | --- | --- |
| U01 | High · source-confirmed requirement gap | Split → People requires a nonempty name; Add person is disabled until typing. | One-tap numbered/color participant, optional rename, no automatic keyboard. Old named participants remain intact. | P11-05 |
| U02 | High · source-confirmed workflow | Split → purchase → Item owners → select → Back for every item. For N individually owned items, this is at least 3N taps after adding people, excluding scrolling. | Person-first batch selection with one Apply per person; shared markers, Cancel and Undo. No per-item navigation for ordinary assignment. | P11-05 |
| U03 | High · screenshot and source-confirmed hierarchy | Split root puts receipt explanation, people, purchases and adjustment rules before amounts. Allocation terminology dominates the adjustment footer. At accessibility5 the introductory block occupies more than the first viewport, before People appears. | Compact bill/person overview, visible assignment progress and separate final review. Put allocation explanations beside the relevant choice, retaining explicit acceptance. | P11-05 |
| U04 | Medium · source-confirmed structural inconsistency | Paper review has a regularMaterial source-confirmation inset; the parent separately adds floating Save draft/Finish. | Unify bottom presentation/spacing and native soft edges, preserving source-check and exact finalization gates. Verify no hard band or duplicate blank reservation in paper and form modes. | P11-02 |
| U05 | Medium · screenshot and source-confirmed hierarchy | Collection/search starts with Collection, Store, Month and Include archived before the result count and receipts. | Compact filter entry and visible active-filter summary; show results earlier. Keep one-tap reset and a clear archive scope. | P11-06 |
| U06 | Medium · source-confirmed navigation cost | Saved receipt → item editor → Purchase history → candidate → Compare unit prices. This is four taps from the receipt before configuring comparison, plus scrolling. | Keep the existing Line details title, but prioritize the purchase summary and history over editing/original-reading tools; expose explicit Edit for changes. Retain the existing search route and original evidence. | P11-06 |
| U07 | Medium · screenshot and source-confirmed hierarchy | Product comparison renders two full purchase sections before match decisions; price comparison renders setup sections before its result even for saved evidence. | Show a compact comparison/status first; separate saved-result viewing from editing verification. Keep full original/quantity/pack/tax evidence available. | P11-07 |
| U08 | Medium · source-confirmed action styling | Confirm same product, Different products and Undo are adjacent form actions; Compare unit prices remains available for unmatched/incompatible pairs and explains failure later. | Establish decision hierarchy and visible eligibility guidance beside the price entry. Do not infer a match or silently change an earlier decision. | P11-06/07 |
| U09 | Medium · source-confirmed information density | AI settings distributes connection, testing, privacy, enablement and management across a long form with repeated explanatory footers. | Separate connection status and setup from advanced management; concise essential disclosure at the action, expandable technical details. Preserve explicit acknowledgment and per-image upload consent. | P11-04 |
| U10 | Medium · source-confirmed inconsistent status | Settings summary says Gemini whenever a key exists, regardless of enabled/verified/error state. | Summarize Not connected / Ready / Off / Needs attention from actual connection state. Never present stored-key presence as a successful connection. | P11-04 |
| U11 | Medium · screenshot and source-confirmed missing feedback | Export backup disables Choose where to save for short or mismatched passwords, but provides only the general length rule and no inline mismatch explanation. | Contextual validation after interaction; preserve secure entry, non-persistence and cancellation. Check keyboard reachability before moving controls. | P11-04 |
| U12 | Medium · source-confirmed inconsistent recovery layout | Import failure uses a vertical cluster of differently sized actions within content, unlike the accepted step flow's clear bottom primary action. | Reuse recovery hierarchy: concise status, recommended next action, secondary alternatives. Preserve source photo and fresh upload consent. | P11-04 |
| U13 | Investigation · not yet a reproduced defect | Focused correction combines a fixed 150/180-point original preview, zoom tools, Expand original and Reread; rereading reserves 300 points and uses a horizontal tool row. | Inspect at compact/large-text sizes; only change actual clipping, cramped controls or excessive scrolling. Retain zoom and explicit Apply/Cancel. | P11-02/04 |
| U14 | Measurement gap · position test passed | Crowded-wallet round trips preserve position, but the XCTest hitch run exports an empty metric list. No quantitative smoothness claim is supported. | Obtain a usable frame/hitch trace during P11-03; only change animation for a reproduced defect. Preserve accepted wallet appearance and chronology. | P11-03 |
| U15 | Medium · screenshot-observed ambiguity | Reread a fictional amount: two candidates both show 1.00, one from literal 1 and one from literal 1.00, with similar source text. | Clearly distinguish source candidates, or group identical interpreted values while retaining selectable provenance. Do not silently alter parsing or source association. | P11-04 |
| U16 | Medium · observed at actual system accessibility5 | AI recognition → Model truncates its value to “Gem…lash” on iPhone 13 mini. The model identity is not readable in the closed control. | Use a wrapping label or stacked model summary outside the compact picker. Preserve full model identity at large text sizes without shrinking the requested font. | P11-02 |

## Design decisions for the next tasks

1. Keep the accepted visual identity. This is a consistency pass, not a new wallet/background redesign.
2. Primary actions occupy one predictable action region. Secondary tools align consistently. Native form rows need not all become pill buttons; role and context determine presentation.
3. Do not replace every system Form with a custom scrolling stack. First reproduce occlusion; use native edge behavior appropriate to the screen, with readable reduced-transparency alternatives.
4. Keep core choices and critical privacy/money information visible. Collapse optional explanations, not everything indiscriminately.
5. Do not force long receipts, history or accessibility text onto one screen. Compact short steps; preserve scrolling and legibility where content is inherently long.
6. For splitting, color/number is the default identity. Selected person → multi-select rows → Apply is the normal path. Selecting an already owned row visibly shares it; it never silently steals ownership. See the dedicated bulk-splitting plan.
7. Existing transactional edits, incomplete drafts, exact totals, backups and privacy behavior are acceptance constraints, not candidates for simplification.

## Task order after this audit

P11-02 fixes verified shared-layout problems first. P11-03 is bounded to reproduced interaction/performance defects; if checks pass and no new defect is found, record that instead of inventing an animation rewrite. P11-04 tackles utility/review hierarchy. P11-05 implements the requested bulk split workflow. P11-06/07 improve retrieval and comparisons. P11-08 performs the consolidated phone walkthrough and remaining Phase 10 checks.

The owner approves each implementation task independently. No production fix is included in P11-01.

## Live verification and limits

The scoped runs exercise 16 distinct UI methods, with passed outcomes across the corrected runs: four audit inventories; three product-history/price methods; lock return; restore merge; reverse swipe; nested rereading Apply/Cancel; import fit; camera unavailable alternatives; crowded wallet return; long receipt bottom reachability; archive/star/restore persistence. Standard layout inventory ran on iPhone 15 Pro and iPhone 13 mini Simulators, both on installed iOS 27.0. Dark/accessibility preview paths and a passing separate system accessibility-size inventory distinguish screen-specific preview overrides from actual OS text sizing. The final system-size screenshots were inspected on November 6 and exposed U16; this inventory passing establishes navigation/capture success, not absence of layout defects.

The first audit run had one harness failure: it queried an offscreen Add person before scrolling at large text size. The corrected inventory passed. Two initial wallet selectors used the wrong test class and executed zero wallet tests; they are not counted as coverage. The actual WalletInteractionTests methods were then run and passed on the compact Simulator. The hitch metric export was `[]`; position assertions passed, but no frame-rate or hitch benchmark is established.

Passed behavior worth retaining: reverse swipes close the revealed side before exposing the other; history returns preserve query/row position; confirmation/undo and saved price evidence work; long receipt totals remain reachable; nested reread cancellation does not commit changes; lock hides receipt content; restore merges without replacing existing records. The accepted import steps still fit the standard iPhone 15 Pro viewport.

The new review fixture opens the full form, so U04's paper-only material band is source-confirmed and still needs a targeted visual reproduction before implementation. U13 remains a responsive-layout investigation, not a demonstrated clipped-control bug. The original-view fixture opens a sheet during synthetic initialization; any unusual background stack in that one launch image is not treated as a normal user-path animation defect.

This is broad source/layout review with scoped live journeys, not exhaustive testing of every state. New runs did not certify physical Face ID/camera quality, live cloud networking, VoiceOver speech, every backup Files-provider path, or unseen long real receipts. Import phone acceptance remains the owner's prior report. Runtime accessibility-loader/debugger warnings are retained in local logs and are not treated as Sliplet UI defects without a reproduction.

## Review deliverable

Sixteen findings: 12 source-confirmed design/workflow issues, two additional screenshot-observed issues, one layout hypothesis and one performance-measurement gap. Selected fictional screenshots and run details are in [the evidence index](evidence/p11-01/README.md). No production app code changed. Next approval is P11-02: a focused shared-layout pass, starting with confirmed hierarchy/spacing problems and reproducing the paper-review bottom band before modifying it.


## P11-02 follow-up · November 8, 2026

U04 was visually reproduced on long paper and fixed with soft scroll edges and a native bottom safe-area bar. U16 is fixed with wrapping adaptive model/provider values. U13 was promoted from hypothesis after a large-text screenshot showed clipped original controls; the toolbar now separates Expand original at accessibility sizes. See [implementation and scoped verification](PHASE11_LAYOUT_FIXES.md). Historical audit statements above describe the pre-fix state.

## P11-03 follow-up · November 8, 2026

Eight navigation/gesture/resource scenarios now have passing results, including Reduce Motion and search return. No new production navigation defect was reproduced. U14 is partially addressed: native CPU/clock data now exports, but Instruments explicitly reports Animation Hitches unsupported on Simulator. Hardware frame/hitch validation remains open for P11-08. See [navigation findings and limits](PHASE11_NAVIGATION.md).

## P11-04 follow-up · November 8, 2026

U09/U10: AI settings prioritizes state and enablement, retesting is optional, and the summary distinguishes stored keys from readiness. U11: inline password feedback explains disabled export. U12: import recovery now has one primary safe-area action with soft edges. U15: rereading distinguishes exact printed tokens and source rows without merging provenance. The remaining U13 rereading toolbar separates zoom from selection; fixed preview heights remain unchanged because no additional height defect was established. Sixteen connection unit tests and six distinct scoped UI journeys passed; see [utility changes and limits](PHASE11_UTILITY_POLISH.md).

## P11-05 handoff · November 10, 2026

U01/U02/U03 are addressed in the scoped implementation: immediate numbered/color people, optional naming, person-first bulk assignment and a responsive selection hierarchy. Shared membership, transactional Apply/Cancel/Undo, exact money and legacy encrypted storage are preserved. 29 unit checks and eight distinct Simulator journeys pass across focused runs. See [implementation evidence and limits](PHASE11_BULK_SPLITTING_IMPLEMENTATION.md). Physical-phone and full VoiceOver acceptance remain P11-08; P11-06 requires Main approval.

## P11-06 handoff · November 10, 2026

U05 and U06 are addressed: compact expandable filters with scope/reset, return to the opened result, and saved-line summary/history before explicit editing. U08 decision buttons now have primary/secondary hierarchy with separate Undo; price eligibility remains P11-07. Ten unit checks and eight distinct scoped UI journeys pass. See [search/history evidence and limits](PHASE11_SEARCH_HISTORY.md). Phone and full manual VoiceOver acceptance remain P11-08.


## P11-07 handoff · November 11, 2026

U07 and the remaining price eligibility portion of U08 are addressed. Match status appears before receipt evidence. The unit-price entry explains missing product or pack confirmation, review, currency compatibility or source values before opening setup. Saved results show both normalized unit prices and the tax basis immediately, with explicit Edit, Cancel and Clear actions. Line totals and printed unit prices have separate labels. The existing exact calculations and verification gates remain in effect.

Six unit checks passed, including saved verification persistence, reversal and clearing. One optional private fixture was absent. Two fictional Simulator journeys passed across focused runs: saved comparison preview, save, view, edit, cancel and clear, and match confirmation, source inspection, undo and return position. Phone and manual VoiceOver acceptance remain P11-08.


## P11-08 split redesign · November 11, 2026

The owner found the pinned people strip confusing during the phone walkthrough. The overview now begins with a People section and a labeled Add person row. Adding a person opens a focused item assignment view. Apply items or Cancel returns to the overview, and closing with unsaved work offers a single discard prompt. Color, optional names, equal sharing, explicit allocation review and exact finalization remain available.

Four fictional Simulator journeys passed across the redesign checks: bulk selection and saved colors, maximum text size and removal, finalize/share/restart and unsaved dismissal. The final summary and badge polish passed another maximum text size run. Owner acceptance of the revised split remains pending.

## P11-08 native controls review · November 12, 2026

Reviewed the UI sources for gesture recognizers, transitions, control styles and UIKit wrappers. Receipt cards in the wallet and rows in the library now use SwiftUI swipe actions. The wallet uses the iOS 27 swipe container to coordinate reveal and dismissal. Receipt identity keys the projected stack as cards move or leave it. Swipe left reveals Delete with confirmation and swipe right reveals Archive, or Unarchive in the archive. A long reverse swipe can reveal the opposite side. A short swipe reveals the action. A full swipe invokes it directly, including the existing confirmation for Delete.

The People form uses native swipe actions. Search, forms, pickers, menus, sheets, alerts and sharing use platform controls. Photo and backup selection use system pickers, the camera uses AVFoundation, and the original viewer uses UIKit scrolling and zoom. SwiftUI composes the wallet artwork, the paper lift and the import transitions. Crop and cover editing use UIKit gestures with Sliplet’s receipt-specific handles and selection rules.

## P11-08 phone checkpoint · November 12, 2026

The owner passed the receipt swipe and split walkthrough on the installed iPhone build at `ee768b6`. The next phone check is search return, repeat-purchase history and undo, and unit prices when an eligible pair is available. Record unavailable cases as skipped.
