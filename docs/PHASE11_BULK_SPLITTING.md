# Phase 11 · Color-first bulk bill splitting

Planning requested November 5, 2026. Implementation is P11-05, subject to task approval. Included in the P11-01 whole-app audit/design and P11-08 acceptance.

## Current friction confirmed in source

ReceiptSplitView requires a nonempty name before Add person is enabled. Every purchase navigates into a separate item-owner form. SplitParticipant validation also requires a name. The redesign must change the interaction and compatible presentation storage, not merely hide the text field. Existing participant IDs and exact allocation rules must remain stable.

## Primary journey

1. Open Split: show the receipt total, a compact People strip and the item list. Put secondary explanations behind contextual details rather than a long introductory paragraph.
2. Tap +: immediately create and select a participant with the next available color and a stable short label such as Person 1. Do not open a keyboard or require a name. Show an accessible numbered color badge in the people strip. An Edit person action opens optional color and name controls; choosing a name does not remove the color.
3. With a person selected, tap multiple item rows to select their purchases without opening new screens. Existing selections for that person are checked. Show a concise selection count and clearly labeled purchase subtotal; a provisional amount must not be presented as the final amount owed.
4. Apply the selection once. Cancel restores the previous assignments. After Apply, the user can switch people and repeat. If switching or leaving with pending selections, offer Apply or Discard rather than silently losing or committing them. Provide Undo for the last applied assignment batch.
5. Review amounts and adjustments, then Save split or Finalize using existing exact-reconciliation and review requirements. Persist unfinished split choices explicitly. A single-person assignment should require one Add, item taps and one Apply, not a new page per item.

## Layout and controls

- Keep the active person's badge and assignment mode visible while the item list scrolls. People overflow horizontally or use an accessible list picker at large text sizes; do not squeeze many names into one row.
- Every row shows description, amount and ownership markers. Active-person selection uses a subtle tinted background or leading stripe plus a checkmark. Assigned owners use compact colored numbered badges; a name can appear on selection or in details.
- Shared rows show multiple owner badges and the label Shared equally; never imply exclusive ownership with one person's full-row color.
- Use consistent primary/secondary buttons in a floating bottom action area with soft scroll edges. Selection actions are Apply/Cancel; ordinary split actions are Save/Review or Finalize. Avoid stacking both sets of controls at the same time.
- Provide All items and Unassigned views, plus Select all unassigned and Clear this person's selection. Scope bulk controls explicitly; do not hide ownership changes behind an ambiguous Select all.
- Long receipts should scroll naturally. Short control sections should fit without unnecessary scrolling, but accessibility and item legibility take priority over fitting the entire bill on one page.

## Shared items and correction rules

Selecting an item already owned by someone else adds the active person as an equal co-owner; it never silently replaces owners. Before Apply, show a visible summary such as “3 selected · 1 shared” and the affected badges. Deselecting removes only the active person. If no owners remain, show Unassigned and block finalization. Keep an item-level owner editor as an optional advanced route for transferring ownership or inspecting all owners, not the normal workflow.

Remove person is available from Edit person, with confirmation when assignments or adjustment policies are affected. Explain that their memberships are removed and newly unassigned items need attention. Adding another participant must not silently expand existing shared owner sets. Rename or recolor must not change ownership or cents. Existing adjustment policy invalidation must remain intact when membership changes.

## Color and accessibility

Use a restrained palette with light/dark variants. Color is a convenience, never the sole identifier: retain stable participant numbers, optional names, checkmarks, borders and VoiceOver labels. Palette reuse in large groups must remain distinguishable by number/name; never promise 100 unique perceptual colors. Do not reuse a removed person's number within the active plan if it could confuse references. Export/copy summaries include readable participant labels, not unexplained colors.

## Persistence and calculations

Preserve existing named people and IDs. Introduce backward-compatible optional appearance metadata and a deterministic fallback for legacy plans. For unnamed participants, maintain a stable generated display label compatible with old required-name validation, or migrate that validation deliberately with legacy decoding tests. Choose the minimal safe storage change during implementation; do not globally weaken plan validation to permit empty unidentified people.

Colors and custom names are display metadata; assignment sets still contain participant IDs. Persist appearance through save/reopen and encrypted backup/restore. Old backups remain readable. Keep exact money allocation, shared equal splitting, signed returns, zero-value items, tax/discount scope and finalization gates unchanged. Default adjustments remain proportional to assigned purchases where that is the established explicit policy. Color does not infer tax applicability.

## Acceptance checks

- Add multiple unnamed people without showing a keyboard; optionally name/recolor one later.
- Assign a dozen purchases using one list and one Apply per person, without visiting item-owner pages.
- Cancel a selection batch, undo an applied batch, switch people and return without losing position or accidentally changing assignments.
- Shared-item addition/removal preserves other owners; finalization rejects unassigned items.
- Remove a person with affected items/policies, and inspect a split with more people than palette colors.
- Rename/recolor preserves exact monetary results; repeated odd-cent shared items remain balanced and total exactly to the receipt.
- Verify draft save, encrypted restart/backup, legacy named splits, receipt edits, stale saves and background/lock cancellation.
- Check light/dark, color differentiation, VoiceOver, large text, long descriptions and long receipts. Complete a fictional three-person walkthrough and an owner phone check before acceptance.

## Scope

No contacts permission, accounts, cloud synchronization, saved household directory, unequal percentage/quantity shares or payment collection added by this task. The goal is faster assignment using the existing split engine.

## P11-05 handoff · November 10, 2026

U01/U02/U03 are addressed in the scoped implementation: immediate numbered/color people, optional naming, person-first bulk assignment and a responsive selection hierarchy. Shared membership, transactional Apply/Cancel/Undo, exact money and legacy encrypted storage are preserved. 29 unit checks and eight distinct Simulator journeys pass across focused runs. See [implementation evidence and limits](PHASE11_BULK_SPLITTING_IMPLEMENTATION.md). Physical-phone and full VoiceOver acceptance remain P11-08; P11-06 requires Main approval.
