# P7-03: source-verified description boundaries

## Decision

The bounded candidate passes this proof: **43/66 → 45/66 exact purchase pairs**, with zero lost previously correct scored line or summary fields, on the five frozen receipts and on both fresh actual-app import passes. These are five previously exposed receipts, with zero held-out data. This supports a small integration proposal, not a claim that receipt recognition is solved.

The candidate lives only in the test target. Production recognition, installed wallets, original images and historical labels are unchanged. No phone testing or production release was performed.

## User-confirmed boundary

Two checked descriptions omitted a trailing code that other checked names retained. On 2026-10-20, the user confirmed: “Printed in both; retain in the description.” The private review page showed both original rows, OCR descriptions and prior labels. This clarification applies only to the two trailing description codes; it does not newly verify quantities, source boxes or other fields.

The historical reference remains frozen. A separate clarified reference appends only the confirmed codes to those two descriptions, with a private amendment ledger retaining before/after values and the user's answer. Neither prices nor scorer rules changed. Both baseline and candidate are scored against the same clarified reference.

| Reference / input | Unchanged parser | Candidate |
|---|---:|---:|
| Historical labels, frozen observations | 43/66 | 43/66 |
| Clarified labels, same frozen observations | 43/66 | 45/66 |
| Clarified labels, fresh import pass 1 | 43/66 | 45/66 |
| Clarified labels, fresh import pass 2 | 43/66 | 45/66 |

The historical score is not retroactively rewritten. The clarification alone does not improve the baseline score. The gain comes from recovering the missing description/printed-extension associations under the confirmed description convention.

## Candidate behavior

Start with the unchanged parser output. For a recognized retailer, accept an additional purchase only when an intact, single-observation description has a parenthesized integer count and long product code, immediately followed by an indented explicit count `@` unit-price and printed-extension row. Require matching counts, bounded vertical separation, exactly the supported monetary syntax, exact extension arithmetic, and no already-consumed sources.

Move the explicitly repeated count into the quantity field. Retain the complete remaining description, including product code and trailing letters. Copy the printed extension; never calculate a missing price. Preserve all raw observations and source IDs. Existing parsed lines are untouched. There is no receipt-specific name, price or suffix lookup in the Swift candidate.

An early negative test revealed that grouping could absorb unrelated text into a description. The final candidate rejects multi-observation description heads. That excludes the unverified third P7-02 candidate while preserving the two verified recoveries. Earlier runs and source snapshots remain private; only `p7-03-final-v2` is the final evidence. The initial negative test assertion was also corrected to compare candidate additions against the existing parser, rather than assume the existing parser returned no lines.

## Validation

- Five frozen comparisons retain all raw observations and all existing parsed lines; five repeat pairs agree.
- Both previously checked Costco transcript outputs remain unchanged.
- Two hosted XCTest methods passed: one covers a positive case plus ten negative cases, and one performs ten fresh imports (five originals × two passes).
- Fresh imports use `ReceiptWorkspace.importFile`, the normal app import entry point, in a dedicated Simulator. The test-only candidate consumes exactly the OCR observations from each import; references never enter the app.
- Ten paired inputs match exactly; all ten native candidate outputs match host parser replay. All five repeat OCR text/geometry pairs agree.
- Zero previously correct scored line or summary fields are lost on frozen or fresh comparisons.
- No performance, full user-workflow, physical-device or unseen-receipt acceptance is claimed. The candidate is not wired into review/save. Existing diagnostics still remain in the proof output.

## Reproduction and private evidence

1. `prepare.py` creates the focused local boundary page from existing originals and checks their frozen hashes. The retained review is `private-receipts/evaluation/p7-03-boundaries`.
2. Compile `Worker.swift` with `SlipletTests/ReceiptItemBoundaryCandidate.swift`, the unchanged domain/parser source list from `PHASE7_REPRODUCTION.md`, and `-D P703_CLI`; output `/tmp/sliplet-p703-proof`.
3. `evaluate.py` creates a new frozen run with separate original/clarified references. It refuses to overwrite `private-receipts/evaluation/p7-03-final-v2`.
4. Build the Sliplet test target into `/tmp/sliplet-p703-build`. Create and boot only a dedicated `Sliplet P7-03 Item Lab` Simulator, recording its identifier in `/tmp/sliplet-p703-device`. `native.py prepare` stages original bytes without labels and creates the private xctestrun.
5. Run only `SlipletTests/ReceiptItemBoundaryProofTests`, with parallel testing disabled. Use the generated xctestrun and dedicated device. `native.py collect` resolves the current app container after Xcode installation and retains private paired outputs.
6. Export the xcresult test summary to `native/test-summary.json`. `verify.py` rechecks source hashes, the exact two reference amendments, stored scores, native/host parity and executed test counts without needing a running Simulator.

The final private run is `private-receipts/evaluation/p7-03-final-v2`; safe aggregates are in `docs/evidence/p7-03`. Only the task-created Simulator is removed after collection. Existing signing settings are preserved.

## Next task, requiring separate approval

**P7-04: integrate the verified two-row item rule.** Move the narrowed rule into production parsing, keep source order, reconcile only diagnostics actually resolved by the new association, preserve raw evidence and transactional review behavior, and repeat the paired no-regression checks plus targeted review/save tests. Retain printed trailing codes in the description. Do not expand into weighted items, arbitrary suffix stripping or total repair in that task.
