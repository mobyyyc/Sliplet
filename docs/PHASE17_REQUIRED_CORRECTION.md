# P17-02 · Required receipt-line correction

The [P17-01 baseline](PHASE17_EVERYDAY_AUDIT.md) found two choices before a user could open the editor that compares a required line with its original. The main review prompt jumped to the line in the full form. The photo comparison editor was under Suggested checks.

The required prompt now names the affected item when it is available. A single tap opens the existing line editor with the original photo and editable fields. It uses the line identity from reconciliation and highlights source regions when the existing evidence has coordinates. A new receipt with a required line correction can open on the paper preview. The full form remains available for editing receipt fields and investigating totals that do not reconcile to any specific line.

Cancel discards the sheet's working copy. Apply returns to the same review and changes the draft. Finish still requires exact reconciliation. A draft with a missing amount can be saved and reopened for review. The merchant prompt retains the option to select a name from the printed header.

## Verification

On iOS 27.0 with an iPhone 15 Pro Simulator and Xcode 27.2:

- A 36-item fixture opened the last amount editor in one tap from the top prompt with Suggested checks still collapsed. Its original photo was available. The corrected receipt could finish. The large-text case also reached the amount and expanded the original.
- A fictional model response with the final amount missing opened on the paper preview. Cancel kept the original review position and missing value. Backgrounding restored the pending review. Saving it as a draft and reopening allowed the amount to be corrected and finished, with one new saved receipt in the wallet.
- A total difference with every line amount present opened the full review at the total. It remained blocked from finishing and splitting, and search could reopen the saved draft.
- Known and unknown merchants imported through system Photos with on-device reading and no AI key. The unknown merchant still offered its printed header. A clean review finished directly. A separate long-paper check confirmed retention of the scroll position after viewing the original.

Sixty selected unit cases passed, with two private-fixture cases skipped. Seven distinct UI cases passed across scoped runs. The first runs exposed stale test navigation and an incorrect seed-count assertion. The final tests use the current review and search routes and the actual fixture wallet count. The unsigned iPhone SDK Release build succeeded. UI data was fictional, and physical iPhone testing remains pending.

## Next approval

P17-03 · Duplicate import guidance. Test identical images, independent rephotographs, and distinct transactions with similar details. Offer the existing receipt for a strong match and let the user decide how to handle uncertain matches.
