# Phase 14 · Today, Settings and search return

Owner-requested refinement, November 18, 2026.

## Behavior

Settings begins with Display, combining Receipt view and Receipt paper. Recognition follows; Privacy, Backup and the informational Receipt actions follow. Wallet information lives in About at the bottom. Existing controls and saved preferences remain intact.

The recent group uses the receipt's purchase date and the user's local Gregorian day. It reads Today when the current results include today's purchases. Otherwise it reads Latest and contains the newest purchase day. If every date is missing, Latest holds the most recently added receipt. The recent group uses the same capsule and spacing as each month divider. Earlier purchases stay in their months, with undated purchases in Date unavailable. Wallet places the recent group nearest the pocket. List places it first.

A fresh wallet uses its existing bottom/latest default. Closing native search clears only its query and old browsing-position requests, preserving applied filters. The wallet then starts at the latest matching receipt; the ordinary list starts with its newest group. Changing the display choice also starts at the newest matching purchases. Receipt-detail return continues using its retained paper position.

The top scroll edge uses a full-width vertical fade owned by the home surface. Wallet uses a soft blur and List and Search use their grouped background. The underlying native top edge is disabled on both browsing scroll surfaces, so it cannot wipe across while search dismisses. The returning wallet anchors to its bottom edge while the keyboard insets settle.

Period snapshots and wallet geometry rebuild on data/filter changes and local calendar-day changes. The midnight notification refreshes Today or Latest without a per-frame clock check. Stable receipt identities and bounded paper rendering remain in use.

## Verification

22 focused unit methods passed with zero failures or skips: Today/month separation and ordering, a day rollover, inclusive filters and currency isolation, future-date identity conservation, query cancellation resetting home position, and the existing search, privacy clearing and 1,000-receipt geometry checks.

Four fictional native UI journeys passed in the final run. They cover Today and Latest on first open and after native search cancellation, search detail and filter return, and shared controls, amount-filter reset and display switching. The Today and Latest checks verify the newest paper returns within four screen points of its initial position. The intermediate blur transition still needs a physical-device visual check.

Fictional screenshots: [initial wallet](design/phase14/evidence/today-settings/today-wallet-initial.png), [after native search cancellation](design/phase14/evidence/today-settings/today-wallet-after-search-cancel.png), [Settings bottom](design/phase14/evidence/today-settings/settings-information-last.png).

Next: approved iPhone update and owner check of search dismissal and newest positioning. P14-04 Purchase overview remains the next roadmap feature, pending approval.
