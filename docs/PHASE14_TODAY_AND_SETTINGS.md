# Phase 14 · Today, Settings and search return

Owner-requested refinement, November 18, 2026.

## Behavior

Settings begins with Display, combining Receipt view and Receipt paper. Recognition follows; Privacy, Backup and the informational Receipt actions follow. Wallet information lives in About at the bottom. Existing controls and saved preferences remain intact.

Today is based on the receipt's recorded purchase date and the user's current local Gregorian day. It uses the same capsule, count, gap, depth and paper geometry as month dividers. Earlier purchases stay in their month; undated purchases remain Date unavailable. Empty Today groups are omitted. Wallet runs from older periods toward Today at the pocket; List puts Today first. Future-dated purchases retain their original date and ordinary month group, preceding the pinned Today group. No receipt is duplicated or re-dated.

A fresh wallet uses its existing bottom/latest default. Closing native search clears only its query and old browsing-position requests, preserving applied filters. The wallet then starts at the latest matching receipt; the ordinary list starts with its newest group. Changing the display choice also starts at the newest matching purchases. Receipt-detail return continues using its retained paper position.

Search dismissal previously mixed native presentation animation with the content replacement and its scroll-edge material. The closing-search state change now uses a transaction without animation, and the root scopes the same suppression specifically to changes in searching state. Normal paper interactions retain their animation. There is no delayed correction or extra animated fade overlay.

Period snapshots and wallet geometry rebuild on data/filter changes and local calendar-day changes. The midnight notification refreshes Today without a per-frame clock check. Stable receipt identities and bounded paper rendering remain in use.

## Verification

22 focused unit methods passed with zero failures or skips: Today/month separation and ordering, a day rollover, inclusive filters and currency isolation, future-date identity conservation, query cancellation resetting home position, and the existing search, privacy clearing and 1,000-receipt geometry checks.

Three distinct fictional native UI journeys passed across scoped runs: search/detail/filter return in dark appearance; shared controls, amount-filter reset and display switching; and initial Today visibility, native X cancellation returning to the same latest paper height, merged Display controls and Wallet information at the bottom. The Today visibility journey uses three purchases, with one today, one yesterday and one in an earlier month. Multiple Today receipts are also covered by the grouping tests. An inline section heading can naturally scroll above the viewport when many receipts occupy its group, as month headings already do.

The settled before/after return position passed within four screen points. This does not measure intermediate-frame hitches or establish physical-phone optical smoothness. Owner verification of the reported top-edge wipe remains a device check. No physical-phone installation was performed for this refinement.

Fictional screenshots: [initial wallet](design/phase14/evidence/today-settings/today-wallet-initial.png), [after native search cancellation](design/phase14/evidence/today-settings/today-wallet-after-search-cancel.png), [Settings bottom](design/phase14/evidence/today-settings/settings-information-last.png).

Next: approved iPhone update and owner check of search dismissal and newest positioning. P14-04 Purchase overview remains the next roadmap feature, pending approval.
