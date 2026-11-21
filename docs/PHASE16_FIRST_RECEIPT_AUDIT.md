# Phase 16 · First receipt and everyday use audit

P16-01 was approved in Main on November 20, 2026. Audited app revision `e1b540a`, project version 0.3 (4), using Xcode 27.2 (27B52) and a dedicated iPhone 15 Pro Simulator on iOS 27.0. The first-receipt and recovery probes used the regular app launch and store on this fresh device. System Photos held one generated receipt covering a previously unknown merchant, a printed date and currency, three purchases, subtotal, tax and total. The probes used Apple Vision through the ordinary on-device reading route with a fresh connection state. The other scenarios used existing isolated fictional fixtures. Production app code was identical to the audited revision.

## Observed journeys

| Journey | Result |
| --- | --- |
| Empty wallet → system Photos → photo check → reading method | The 64-point plus opened Take a photo, Photo library and Files. The fixture opened from the system picker. On-device was selected before interaction and the enabled primary button said Read on device. |
| Read → review → finish | The normal OCR/review pipeline opened. Date, currency and purchase data displayed in review. The first probe expected Finish to be available and failed because the required merchant was blank. The first blocker named the missing field and Save draft was available. |
| Resume → inspect original → edit → save → find after restart | Relaunch offered Continue import and restored the same blocked review. Original → Printed text contained the full fictional merchant heading. Entering it in the merchant field was the only correction needed to enable Finish. The saved receipt reopened from item search after another relaunch. Returning from detail preserved the search query. |
| Camera entry, retake, draft, relaunch and Original | Passed using the existing simulated-camera fixture. The draft and original remained available after relaunch. |
| Exit Search with the keyboard showing | Passed. The keyboard dismissed, Latest and the newest receipt became reachable, and the paper stayed tucked into the wallet. |
| Long receipt opened from monthly overview | Passed. The full total was reachable above the bottom actions. |
| Month total drill-down and return after scrolling | Passed in dark mode. The month drill-down restored the same visible row. |

Five native journeys passed across two runs. The original direct-Finish expectation failed and remains recorded separately. The test driver observed review 1.46 seconds after tapping the on-device action on this one fixture. That interval includes driver overhead. It describes neither production OCR latency nor human correction time.

[First-run Simulator evidence with a fictional receipt](design/phase16/p1601-first-run.jpg)

## Priorities

| Priority | Reproduction and impact | Proposed response |
| --- | --- | --- |
| 1 · Resolve a required unknown merchant with its source | Import a complete receipt for a merchant outside the directory. Review can show Merchant is missing even while Printed text contains the heading. The parser uses only matching directory entries for the merchant field. On the audited receipt, this forces a new user to switch to Original, locate the text, return and type it before finishing. | In P16-02, reuse the required merchant correction route to make nearby header text available for explicit selection or editing. Keep ambiguous headings unassigned until the user acts and preserve the source and receipt total checks. |
| 2 · Make the first import's next action obvious | On an empty wallet, the plus has an accessible label and opens the right choices. The visible hint names the task without naming the control. The reading screen correctly defaults to on-device, but the disconnected AI card and provider copy have similar visual weight. | In P16-02, point the empty-wallet hint to the existing plus and make local reading the clear next action at first use. Keep the three system import sources and the configured-AI journey. |
| 3 · Explain when imports can resume | Wallet information says backgrounding clears unsaved work. The audit restored the pending import and OCR review after relaunch. Pending imports and unsaved edits to an existing receipt have different behavior. | In P16-02, make the wording specific to a resumable import and to unsaved edits. In P16-03, check interruptions and checkpoint failures at each stable step before making broader recovery claims. |

Relevant implementation is in [merchant header parsing](../Sliplet/Parsing/Parsing.swift#L489), [receipt review](../Sliplet/UI/ReceiptReviewView.swift), [reading choice](../Sliplet/UI/ReceiptUploadPreview.swift) and [wallet information](../Sliplet/UI/ReceiptHome.swift).

## Next approval

P16-02 should test a clean and an unknown-merchant fictional receipt from the real import entry without an API key, then save and find the result. Keep the phase's iPhone walkthrough for the candidate build after separate approval. Camera permission and capture hardware, airplane mode, Live Gemini, human onboarding and correction time, and physical device performance remain unverified by this audit.
