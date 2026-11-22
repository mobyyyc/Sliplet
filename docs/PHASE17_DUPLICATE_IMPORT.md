# P17-03 · Duplicate import guidance

Sliplet now recognizes the exact bytes of a saved original when the user selects a photo. The check uses the existing encrypted receipt record's SHA-256 digest and runs locally before photo preparation or recognition. The prompt shows the saved receipt's merchant, date and total. Open saved receipt cancels the current import and opens that record. Import another copy continues through the regular import flow. That choice is stored in the encrypted pending import so a background interruption does not ask the same question twice. Earlier checkpoints still decode.

A different image can show a Possible duplicate prompt before Finish or Save draft. The advisory match requires a matching merchant, printed date, currency, total, subtotal, purchase basket and financial adjustments. The comparison preserves repeated rows and ignores row order. Known quantities, codes, unit prices and signed amounts participate in the match. Single-product or incomplete baskets provide too little evidence for this prompt. Keep reviewing preserves the import. Save separately keeps both receipts. The advisory match makes no changes to the saved receipt.

## Verification

- The normal iPhone 15 Pro Simulator app used system Photos and on-device reading. Re-selecting the same JPEG prompted before reading. Leaving the app and resuming restored the prompt. Opening the saved receipt kept one receipt in the wallet.
- A separately rendered fictional photo with the same printed content reached the Possible duplicate prompt. Keep reviewing returned to review. Save separately added a second receipt. A different basket from the same merchant, date and total saved directly as a third receipt.
- Unit checks confirmed opening an archived photo match, retaining an explicit copy decision through interruption, and distinguishing changed products, codes, quantities, missing amounts and adjustments. The purchase overview and backup checks also passed.
- The final scoped results were 44 passing unit cases, four passing UI methods and a successful unsigned iPhone SDK Release build. One earlier native run hit duplicated accessibility nodes for a single system alert button. Selecting the visible action in the driver resolved it. The interrupted-import regression now seeds its fictional wallet before testing relaunch so a preceding test's saved fixture cannot trigger a real duplicate warning.

All examples are fictional. The recapture case used a separately rendered photo with changed lighting and position. The results cover the Simulator and on-device reader with no live provider or physical capture.

## Next approval

P17-04 · Value from saved receipts. The audit's clearest candidate is a one-action way to include archived receipts when a search misses, keeping the current query and filters so old proof of purchase is easier to find.
