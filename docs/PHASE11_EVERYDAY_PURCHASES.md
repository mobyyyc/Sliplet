# Phase 11 · Find and use saved purchases

Proposed November 5, 2026. Planning only; each implementation task requires Main approval.

## Starting point

The owner accepted the import redesign after iPhone testing. Phase 10 product links, row/search history and verified unit-price comparison are implemented. Its narrowly specified history/undo/comparison device walkthrough has not been explicitly reported; carry that check into P11-01 rather than repeat the accepted import walkthrough. Preserve the existing wallet, receipt appearance, optional AI, local storage and privacy rules.

## Outcome

A user can find an old purchase, understand its history, inspect the original and compare eligible prices without navigating confusing nested screens. Improve the existing features before adding a dashboard or more recognition work.

| Task | Scope and acceptance |
| --- | --- |
| P11-01 · Journey audit and design | Walk wallet → search → receipt → row → history → comparison and back, including no matches, draft, archive and missing-data states. Inventory actual friction, count taps and capture fictional screenshots. Produce the navigation/layout proposal for approval before broad implementation. Include the outstanding Phase 10 phone history/undo/comparison checks in the acceptance checklist. |
| P11-02 · Find receipts and purchases | Refine existing search and collection browsing with clear Receipts/Items result grouping and compact merchant/date/status filters where the audit demonstrates need. Preserve query, filters, scroll and selection on return. Make archive/star discoverable without replacing the wallet home. Verify empty states, combined filters and long result sets. |
| P11-03 · Product history that reads clearly | Make history discoverable from saved item rows and item search. Present a compact purchase timeline with store, date, quantity and amount; keep source inspection and editing easy. Clearly separate confirmed matches from suggestions; simplify confirm/undo without automatic product merges. Verify original/receipt round trips and stale or deleted purchases. |
| P11-04 · Understand price changes | Refine the existing comparison screen so its primary result explains comparable unit prices and the basis used. Distinguish row total from unit price. Show a concise reason when comparison is unavailable and disclose quantity, pack, currency, discount and tax differences. No inferred quantity, invented savings or unsupported trend chart. Verify equal prices with different quantities and incompatible-price cases. |
| P11-05 · Everyday acceptance | Run focused regressions and measured long-wallet navigation checks; check light/dark, large text, Reduce Motion and lock/return. Update the phone in place when authorized, then perform find/history/undo/price walkthroughs. Fix observed issues and record acceptance separately from Simulator results. |

## Design rules

Use established Liquid Glass controls, consistent action placement, native back behavior and retained navigation state. Show the key answer first; expand supporting evidence on demand. Keep essential actions visible and allow scrolling for long histories or accessibility text rather than shrinking text. Use brief transitions that respect Reduce Motion. Keep atmospheric backgrounds scoped to home and receipt detail.

## Scope boundary

No cloud sync, accounts, subscriptions, model replacement, automatic product merges, shopping recommendations or spending dashboard in this proposal. Existing saved receipts and manual references suffice to begin. Any additional human verification should be a focused question tied to an observed ambiguity, not a full receipt relabeling exercise.

## Workflow

Main remains the only coordination chat. Each approved task ends with implemented behavior, verification, commit/push and a proposed next task. P11-01 approval authorizes audit and design, not all later implementation tasks.
