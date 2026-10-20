# P7-04: integrate verified count/extension purchases

## Outcome

The verified P7-03 rule is now in production parsing. On the same clarified reference used for both versions, exact purchase pairs improve from **43/66 to 45/66**, on frozen observations and on both fresh import passes. No previously correct scored fields were lost. This remains five exposed receipts with zero held-out receipts; it fixes one verified layout, not recognition generally. Summary/total repair is outside this change.

Parser version: `p7-04-count-extensions-0.7.0`. Neither the phone nor the normal Simulator wallet was updated. The built app is ready for the user's next Simulator run. Existing saved receipts are not automatically reparsed.

## Production behavior

The parser first applies its existing rules. It then recovers the narrowly verified two-row layout only when the description is one intact OCR observation with an explicit parenthesized count and long product code, followed immediately by an indented row containing the same count, `@`, unit price and printed extension. Known merchant, bounded geometry, exact supported syntax, exact extension arithmetic and unused source IDs are required.

The printed extension supplies the amount; no missing price is calculated. Quantity is stored separately, and the remaining full description retains the printed product code and trailing letters as the user requested. Raw OCR remains unchanged.

Recovered purchases are inserted at their original source position without reordering existing parsed lines. Only `unpriced_source_row` and `quantity_association_uncertain` issues wholly belonging to the recovered source IDs are removed. Unrelated warnings and full source-review requirements remain. Review, correction, split and persistence policy are unchanged.

The test-only P7-03 candidate remains historical proof code; the shipped app calls the production parser rule. No cloud service or additional OCR engine was added.

## Evidence

| Check | Result |
|---|---:|
| Frozen exact purchase pairs | 43/66 → 45/66 |
| Fresh import pass 1 | 43/66 → 45/66 |
| Fresh import pass 2 | 43/66 → 45/66 |
| Previously correct scored fields lost | 0 |
| Additional purchases per five-receipt pass | 2 |
| Prior checked transcript outputs preserved | 2/2 |
| Original bytes preserved during imports | 10/10 |
| Actual-app parser output equals replay | 10/10 |
| Drafts saved and reopened with identical fields | 10/10 |
| Review input preserved after reopening | 10/10 |
| Draft Finish blocked without source confirmation | 10/10 |
| Executed tests passed | 88/88 |

The fresh comparison uses the actual app's normal `ReceiptWorkspace.importFile` path and draft save/reopen flow. The pre-integration parser, compiled from commit `f96f36a`, is replayed against the exact same newly captured OCR observations to isolate parser changes from OCR variation. Reference labels are not staged into the app. The P7-03 user-confirmed reference amendment is reused unchanged; the historical labels are not overwritten and their historical scores are not reinterpreted.

The 31-test focused run covers production guards, receipt order, scoped warning removal, original preservation, draft save/reopen and Finish gating, corrections, currency context, guidance, foundation behavior and private imports. The additional 57 existing parser regression tests cover retailer parsing, purchase assembly, summaries and merchants. This is hosted Simulator/domain validation, not physical-camera or human UI acceptance, and no performance improvement is claimed.

## Reproduction

- Compile `evaluation/receipt-independent-ocr/ParseWorker.swift` with unchanged domain dependencies and current `Parsing.swift` to `/tmp/sliplet-p704-parse`, using the Swift invocation in `PHASE7_REPRODUCTION.md`.
- Extract `f96f36a:Sliplet/Parsing/Parsing.swift` to `/tmp/sliplet-p704-baseline.swift` and compile the same worker using that file instead, to `/tmp/sliplet-p704-baseline`. The baseline source snapshot is retained privately.
- `python3 evaluation/receipt-item-integration/run.py frozen` creates a new private output directory and evaluates the five frozen inputs and two checked transcripts.
- Build the app/tests to `/tmp/sliplet-p704-build`. Create and boot a dedicated Simulator named `Sliplet P7-04 Integration Lab`, storing its identifier in `/tmp/sliplet-p704-device`. `run.py prepare` stages only original images and generates the private xctestrun.
- Run `ReceiptCountExtensionTests`, `ReceiptRecognitionLabTests/testExplicitPrivateSimulatorBaseline`, `ReceiptCorrectionTests`, `ReceiptCurrencyContextTests`, `ReceiptFocusedGuidanceTests` and `FoundationTests` with parallel testing disabled. Run the four parser suites listed above separately. Retain both xcresults privately.
- `run.py collect` validates actual import/save outputs. Export xcresult summaries to `native/test-summary.json` and `native/parser-summary.json`. `verify.py` replays stored evidence and checks hashes, baseline source, scores, original preservation, draft persistence and executed test counts without requiring a running Simulator.

Final private evidence: `private-receipts/evaluation/p7-04-final`. Public files contain only safe aggregate counters. The dedicated Simulator is deleted after collection; private evidence and existing signing configuration remain intact.

## Next proposed task

P7-05, requiring separate approval: validate the integrated build on a small set of previously unseen receipts before expanding recognition rules. Keep results separate from the five exposed receipts, report actual remaining error types, and select the next change from those failures rather than claim broader accuracy from this small gain.
