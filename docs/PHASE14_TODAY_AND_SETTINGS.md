# Phase 14 · Today, Settings and search return

Owner-requested refinement, November 18, 2026.

## Behavior

Settings begins with Display, combining Receipt view and Receipt paper. Recognition follows; Privacy, Backup and the informational Receipt actions follow. Wallet information lives in About at the bottom. Existing controls and saved preferences remain intact.

The recent group uses the receipt's purchase date and the user's local Gregorian day. It reads Today when the current results include today's purchases. Otherwise it reads Latest and contains the newest purchase day. If every date is missing, Latest holds the most recently added receipt. The recent group uses the same capsule and spacing as each month divider. Earlier purchases stay in their months, with undated purchases in Date unavailable. Wallet places the recent group nearest the pocket. List places it first.

A fresh wallet uses its existing bottom/latest default. Closing search clears its query and old browsing-position requests, preserving applied filters. The wallet then starts at the latest matching receipt; the ordinary list starts with its newest group. Changing the display choice also starts at the newest matching purchases. Receipt-detail return continues using its retained paper position.

Wallet, List, search results, receipt details and the review flow use SwiftUI's native soft vertical scroll edges. The home mask and the extra receipt-detail material overlays have been removed. The bottom search field lives in the same safe-area bar as the home actions. The navigation title and toolbar stay stable as search opens and closes. Close clears the search and restores the wallet's bottom anchor without a search-specific navigation-toolbar transition.

Period snapshots and wallet geometry rebuild on data/filter changes and local calendar-day changes. The midnight notification refreshes Today or Latest without a per-frame clock check. Stable receipt identities and bounded paper rendering remain in use.

## Verification

22 focused unit methods passed with zero failures or skips: Today/month separation and ordering, a day rollover, inclusive filters and currency isolation, future-date identity conservation, query cancellation resetting home position, and the existing search, privacy clearing and 1,000-receipt geometry checks.

Five focused Simulator UI journeys passed across the final runs. They cover Today and Latest after search exit, closing with the keyboard visible, search detail and filter return, display switching, and reaching the totals on a 31-item receipt. Frame samples around search close show the native top effect appearing across the screen width in the tested Simulator. The older chronology test still expects an eight-row detail to scroll and fails identically on the shipped baseline. The device still needs a visual check.

Fictional screenshots: [initial wallet](design/phase14/evidence/today-settings/today-wallet-initial.png), [after native search cancellation](design/phase14/evidence/today-settings/today-wallet-after-search-cancel.png), [Settings bottom](design/phase14/evidence/today-settings/settings-information-last.png).

Next: approved iPhone update and owner check of search dismissal and newest positioning. P14-04 Purchase overview remains the next roadmap feature, pending approval.
