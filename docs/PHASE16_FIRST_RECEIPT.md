# Phase 16 · Save the first receipt

P16-02 applies the priorities from the [first-receipt audit](PHASE16_FIRST_RECEIPT_AUDIT.md). A new import with a missing merchant opens the focused editor from the existing required-field prompt. Up to three names from the initial unpriced header appear as choices. Selecting a line fills the working copy and highlights its source on the original photo when coordinates are available. The field is also editable by hand. Apply updates the receipt draft. Cancel discards the working copy.

The candidate list uses the parser's existing header boundary and excludes common dates, addresses, contact details, transaction labels and currency codes. It preserves the exact observations for comparison. Retailer matching and automatic field decisions retain their existing rules. The receipt still needs complete fields and exact reconciliation to finish.

The empty wallet names the plus as the import entry. The local action stays selected by default and optional Gemini setup is a secondary action when AI is unavailable. A wallet with a saved pending import points to Continue import. Wallet information describes how to return to an import and when to save edits to an existing receipt.

## Verification scope

On November 20, 2026, Xcode 27.2 ran 39 focused unit tests and four UI test methods on an isolated iPhone 15 Pro Simulator running iOS 27.0. The methods covered the disconnected AI setup, changing photo preparation and reading locally, resuming an interrupted import, and a clean launch through the normal Photos entry point with two fictional receipts. The known merchant finished directly. For the unknown merchant, the test checked the disabled Finish state, resumed after switching apps, selected the header and confirmed Cancel discarded the selection. It then selected and applied the header, finished, and found the saved receipt by item after relaunch. The known-merchant receipt also reopened through item search after relaunch.

The generic iPhone Release build passed without signing. The acceptance run used simulated hardware and no live AI provider. Physical-device and human onboarding checks remain scheduled for the candidate walkthrough.

[Selected Simulator screens with fictional receipts](design/phase16/p1602-first-receipt.jpg)

## Next approval

P16-03 covers interruptions, retry and cancellation, backup/restore, and preservation of originals, drafts and splits during an upgrade.
