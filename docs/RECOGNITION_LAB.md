# P4-01 — Simulator recognition lab and failure map

Approved in Main on 2026-10-13. This milestone measures unchanged recognition and defines the next experiment; it does not implement regional OCR or new parser behavior. The user accepts Phase 3 in Simulator and prefers Simulator-first accuracy work.

## Actual app boundary

`SlipletTests/ReceiptRecognitionLabTests.swift` is an explicitly enabled hosted XCTest on a task-created iPhone 15 Pro Simulator. It calls the same `ReceiptWorkspace.importFile` handler as Files import, lets production image decoding/Vision/parsing create the editable draft, and captures raw observations, actual Swift row memberships, parser output, domain fields and editable fields. It then saves the unedited draft into a separate encrypted test store, closes/reopens it and compares the original, fields and review input. Checked references never reach the Simulator request, test bundle or recognition logic. The ordinary app UI/picker and camera are not driven by this hosted test; its timing measures handler-to-review, not user picker time.

The lab is Simulator-only and skips in ordinary test runs unless explicitly enabled with a matching run nonce. Input copies and all results/logs live in a disposable device/private ignored run. Main preserves original photos, historical labels/evidence, existing app source, signing settings and user-installed wallets. Existing production recognition/settings remain unchanged.

## Reference and scoring contract

Retain historical counters for comparison, with all their limits. The new private reference sidecar separately covers merchant/date/currency/subtotal/total; purchase description, kind, printed line amount, quantity, unit, unit price, SKU and tax marker; adjustment description, kind, amount and rate. It retains stable row identities and optional original regions. Full printed-line coverage and summary coverage require explicit verification.

Field states are printed and checked, checked as not printed, unreadable, or unreviewed. Printed zero is distinct from absence. Existing labels verify the dimensions they actually collected; currency and newly introduced quantities/units/SKUs/unit prices/markers/rates are not silently declared checked. Historical free-text quantity transcription is retained without automatic semantic normalization. Sidecars are versioned; every captured run freezes its reference hash.

New pairing does not select a duplicate row by its expected amount. Verified original regions can establish identity; unique kind/description matching remains a disclosed proxy without those regions. Ambiguous repeated names remain unresolved, while known row-count discrepancies or unrelated extra rows still fail completeness. Description errors can appear as unmatched rows; these are not automatically called invented products.

A whole receipt is **incorrect** if a verified discrepancy exists, **indeterminate** if no known discrepancy exists but evidence/coverage is incomplete, and **correct** only with complete verification and no discrepancies. All line/field omissions remain in their applicable denominators. Arithmetic equality, OCR confidence and source-review confirmation are separate concepts. No result is auto-finalized.

## Failure-map interpretation

The lab uses actual Swift grouped/interpreted rows rather than re-created Python geometry. It records interpretation/description-match suspects when expected text/amount appear in a corresponding interpretation row; nearby separated evidence can create an association suspect. Absent evidence leaves capture/OCR/reference unresolved. These are hypotheses, not human image adjudication. Conversion/storage differences can be proven from captured before/after structured fields. No crop/quality defect is asserted merely because text is missing.

The next experiment distinguishes original image, human-verified regions, automatic regions and checked-text replay. Recovering raw transcription is reported separately from getting the final receipt correct. If checked text still fails, parser work takes priority; a negative regional experiment does not force an adaptive-reading feature.

## Frozen Phase 4 targets before experiments

These are proposed personal-test acceptance gates, not achieved accuracy or statistical guarantees:

- At least **95% exact purchase recovery** and **99% precision** on independently checked, previously untouched purchases. Report exact numerators, omissions, extra rows and each store separately; do not combine repeats/crops as new purchases.
- At least **95% exact printed monetary summary fields** (subtotal, each tax/discount/fee amount and total), with verified absence tested separately. Merchant/date target at least **90%**. All evaluated money remains exact minor units; no tolerance or balancing-based correction.
- At least **80% wholly correct receipts before assistance**, across all in-scope verified fields and lines. Unreviewed/unreadable references remain disclosed and cannot support a pass. Tiny denominators require reporting actual counts and cannot establish broad reliability.
- No new observed wrong accepted financial values, duplicated rows or regression on previously correct development cases. If a proposed change trades errors between stores, bring the explicit tradeoff back to Main; it does not silently pass.
- Report assistance separately: exact completed receipts after help, unresolved receipts, region adjustments/rereads/typed edits and actual user Simulator review seconds. Target median correction under 30 seconds on a future timed, checked comparison; P4-01 does not collect or claim this timing.
- For the next experiments, use the same Simulator/build configuration and record all first/repeat attempts and outliers. Candidate repeat-import median must be no more than the larger of 1 second or 1.5 times this baseline's repeat median; worst repeated sample no more than the larger of 3 seconds or twice this baseline's repeated maximum. These are provisional comparison budgets for this corpus, not phone promises; bounded longer processing requires explicit review. A 120-second lab watchdog is not a product wait-time target.
- Before production integration, select a bounded regional retry budget from P4-02 measurements; never introduce unlimited full-image retries. Measure cancellation/background cleanup, memory and responsiveness separately. Maximum actor polling gap here is not a frame-rate measurement.

Start with the existing five exposed purchases. Expand in small batches toward a balanced corpus when available, reserving untouched purchases before tuning. Copies/photos/crops of one purchase stay together. The current five remain development data permanently. If held-out failures guide a fix, that set becomes development evidence and cannot certify the revised candidate.

## User participation

No new receipts or crops are required to complete P4-01. The generated private read-only comparison links originals and identifies unreviewed fields and unresolved row identities. Main will ask for only specific annotations when needed, using ordinary language; the user is not expected to edit JSON. Explicit answers are recorded in a new sidecar with verification provenance. Historical checked references remain untouched. Automatically generated annotations remain unverified.

P4-02 can first test whether human-marked regions help at all. A region selection for an experiment is user assistance, never part of the fully automatic score. An interactive in-app highlight/reread/candidate UI remains P4-05 scope.

## Verification boundary

Fictional scorer regressions cover canceling money errors, missing/extra rows, duplicate-name ambiguity/cardinality, verified-region identity, zero/absence/unknown distinction, incomplete coverage, expanded fields, actual Swift-row diagnosis, source relationship stability and exposed-data split rejection. A second verifier independently computes essential aggregate/coverage/conversion/storage checks without importing the main scorer; it is not described as an independent implementation of every v2 field score.

Native first/repeat capture and final aggregate results are recorded below after completion. Runtime test logs and XCTest bundles remain private, not committed. Safe evidence contains only reviewed counters, source hashes and environment metadata.

## Final measured result · 2026-10-13

The accepted private run is `private-receipts/evaluation/p4-01-final-baseline`. All **10/10 imports** completed, with **5/5 identical semantic repeat pairs**, **5/5 unchanged domain-to-editable field conversions**, and **5/5 eligible/attempted/passing unedited draft save/reopen checks**. Originals/parser output/review inputs are preserved. The hosted baseline method passes with zero runtime warnings. Eighteen fictional protocol cases and both report-recomputation and independent essential-counter checks pass. These are diagnostic results; production app source is unchanged.

| Stage / checked measure | Result |
| --- | ---: |
| Legacy parser exact purchase amounts | **53/66** |
| Legacy parser all-kind exact line amounts | **57/73** |
| Legacy merchant / date | **5/5 / 5/5** |
| Legacy printed subtotal / total | **4/4 / 3/5** |
| Legacy omitted / unmatched-extra line proxies | **15 / 7** |
| Legacy matched-line amount discrepancies | **1** |
| Whole receipts correct / incorrect | **0 / 5** |
| Receipts with currency unresolved in structured fields | **3/5** |
| Parsed line amounts blocked at structured currency conversion | **43** |
| Parsed summary amounts blocked at that conversion | **3** |
| Checked / unreviewed expanded reference cells | **238 / 343** |
| Rows with ambiguous identity under stricter pairing | **10** |

The legacy comparison is deliberately not the app's complete-field score. In the structured editable fields, checked subtotal/total matches are **2/4 and 2/5**; merchant/date remain **5/5** each. Three receipts retain their raw parsed amounts and editable amount strings but cannot represent those amounts as `ReceiptMoney` because currency is unresolved. This is a proven conditional-conversion boundary, not proof that those receipts print a currency or permission to silently assign one. It does not mean originals were lost. Prior references did not verify printed currency, so determine whether it is absent, missed, or awaiting a user-selected currency in the next diagnostic work.

The new scorer can establish only **18/66 exact structured purchase pairs** on the current incomplete references and conservative matching. This is not interchangeable with the legacy parser's 53/66: currency blocks and ten ambiguous duplicate identities deliberately prevent stronger claims. There are 15 missing-line proxies and seven unrelated unmatched output rows. Repeated identity requires local region adjudication rather than using amounts as a matching shortcut. Expanded quantity/unit/SKU/rate fields remain unreviewed, so no complete-field generalization claim is possible.

The failure map contains **5 association suspects, 3 interpretation/description-match suspects and 8 unresolved capture/OCR/reference cases** across the mismatched legacy lines. These need controlled experiments, not asserted root causes. Every current full parsed output differs from its historical Mac counterpart despite stable repeat pairs. On the same checked set, previous Mac purchase recovery was 57/66; the current iOS Simulator parser recovery is 53/66. Engine/platform differences and raw OCR changes need inspection before attributing this to one setting. This supports the user's Simulator-first benchmark instead of assuming the historical Mac score describes the app.

First handler-to-review imports: median **745 ms**, max **995 ms**. Repeated imports: median **763 ms**, max **809 ms**. All five first/repeated values and outliers are retained privately. These include polling at roughly 20 ms and run in one hosted Debug process; there is no phone latency, controlled cold-cache or user-correction-time claim. The comparison budgets above therefore resolve to roughly **1.14 s median** and **3 s worst repeated sample** for P4-02 on this configuration, unless Main approves a measured tradeoff.

## Next proposed task

**P4-02 — controlled reading and interpretation experiments**, requiring separate approval. First separate currency availability/conversion from actual OCR errors. Prioritize the 16 legacy mismatches: compare full-image reading, locally verified regions, automatic regions and checked-text replay. Retain transcription-recovery and complete-field scores separately. Request only the narrow source annotations needed to adjudicate ambiguity; new photos remain optional for early experiments, with untouched purchases needed for later generalization claims. No P4-02 code or recognition variants were started in P4-01.
