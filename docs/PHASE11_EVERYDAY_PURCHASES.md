# Phase 11 · Consistent UI and everyday purchase journeys

Revised November 5, 2026 at the owner's request. Supersedes the narrower five-task purchase-history proposal. This revision is planning and a preliminary source audit; no app implementation or new visual walkthrough has occurred.

## Starting point and intent

The owner accepted the import redesign on iPhone, but reports remaining UI problems elsewhere. Preserve the accepted direction while auditing the entire app. Phase 10 product links, history and verified unit-price comparisons are implemented; their specific phone confirmation/undo/comparison checks remain part of final acceptance. Main remains the only coordination chat.

## Preliminary source audit

These are verified implementation observations and investigation targets, not claims of reproduced visual bugs:

- ReceiptReviewView uses a bottom safeAreaInset with regularMaterial for source confirmation, unlike the floating safeAreaBar pattern used by import and focused correction. Check whether it creates an abrupt edge or competes with parent save actions.
- ReceiptRereadView fixes its image height at 300 points; focused correction uses 150/180-point source previews. Check usable image area, keyboard reachability and small/large-text layouts before deciding whether these should change.
- PurchasePriceView starts with explanations and two purchase configuration sections. Audit whether returning users can see their saved comparison result without repeatedly navigating setup content.
- AI settings combines connection status, key verification, privacy acknowledgment, enablement and account links. Audit hierarchy, repeated copy and disabled-action explanations while preserving meaningful consent.
- Shared primary/secondary/action-bar components already exist. Audit call sites for inconsistent sizing, placement and destructive-action treatment rather than introduce a second design system.

## Revised sequence

| Task | Scope and acceptance |
| --- | --- |
| P11-01 · Whole-app UI/UX audit | Inspect wallet/empty wallet, receipt detail, search/filter/archive/star, camera/import/loading/error, review/full and row editing, original zoom/reread, split, product history/comparison, settings/AI connection, lock, backup/restore. Exercise full forward/back paths, keyboard and cancellation. Record screenshots or reproduction steps, severity, user impact, proposed fix and owning task. Present the prioritized fix list before implementation. |
| P11-02 · Shared layout and action consistency | Address confirmed header/footer occlusion, safe-area spacing, button alignment/roles, text hierarchy, dark/light contrast and sheet sizing. Reuse current components. Keep short steps compact; preserve scrolling for long content and accessibility text. Verify final rows and actions are reachable without excessive blank space. |
| P11-03 · Navigation, gestures and responsiveness | Fix reproduced wallet/detail jumps, reverse-swipe behavior, inconsistent dismissal, lost search/scroll state and keyboard conflicts. Measure transition/layout stalls using repeatable fictional large-wallet fixtures. Respect Reduce Motion. Preserve unsaved-edit confirmation and do not claim zero lag from code inspection. |
| P11-04 · Review, split and utility screens | Apply audit findings to review, focused edits, originals/rereading, split assignments, settings/AI setup and backup/restore. Show the main action and status first; shorten or progressively disclose secondary explanations. Keep essential privacy, money and destructive-action information visible at the decision point. Protect Apply/Cancel, draft/finalization and restore semantics. |
| P11-05 · Search and product history | Improve existing receipt/item result grouping, filters and history discoverability as justified by the audit. Preserve query/filter/position on return. Present clear purchase timelines and distinguish confirmed matches from suggestions. Make source inspection, confirmation and undo straightforward without automatic merges. |
| P11-06 · Price comparison clarity | Refine existing comparison so eligible saved results are easy to understand and verification remains separate from viewing. Clearly distinguish row total and unit price, and explain unavailable comparisons. Retain pack/quantity/currency/tax/discount evidence rules; no guessed quantities or invented savings. |
| P11-07 · Regression and phone acceptance | Check the repaired full journeys in Simulator, then on the owner's iPhone when authorized. Include light/dark, large text, Reduce Motion, VoiceOver, long receipts/wallets, interruptions and lock/return. Carry forward the Phase 10 history/undo/comparison phone checks. Resolve critical/high findings; document remaining lower-priority issues and actual device feedback before closure. |

## Audit method and priority

Use fictional fixtures for screenshots and automated tests. Exercise normal, empty, loading, failure and disabled states where applicable. Primary baseline is iPhone 15 Pro at standard text size; also check a smaller supported viewport and accessibility text. Inspect first and last content, overlays, keyboard, action reachability and return position. Use actual reproduction before labeling a suspicion a defect.

Priority: blocked actions, hidden content or lost work first; confusing navigation and visible jumps next; spacing, hierarchy and decorative polish after. Every finding must map to a task, acceptance check and status. Reorder or shrink later tasks based on findings rather than redesign screens that already work. Phone import acceptance remains valid; regression-check it only for interactions affected by shared changes.

## Design rules and boundaries

Preserve paper/wallet layering, shadows, accepted atmospheric backgrounds on home/detail only, and native Liquid Glass controls. Avoid opaque bars where soft system scroll edges are appropriate, but retain readable opaque accessibility alternatives. Compact single-page steps are a preference, not a reason to shrink text or disable necessary scrolling. Use restrained, interruptible transitions with consistent forward/back behavior.

No model replacement, cloud sync, accounts, subscriptions, new analytics dashboard or automatic product identity inference. This phase improves current features. Consent, exact calculations, source provenance, encryption and backup safety remain intact.

## Workflow

Planning changes do not authorize all implementation. Begin P11-01 with the owner's approval; deliver the audit and proposed fixes for review, then proceed one approved task at a time. Each implementation task ends with validation, commit/push and next-task approval. No new chats or agents are required.
