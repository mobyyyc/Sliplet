# Phase 10 · Purchase history

November 3, 2026. P10-01 through P10-04 approved and completed. P10-05 requires individual approval.

## P10-01 evidence

Read the five existing development references from the final Phase 8 reference repair and the five retained echo-acceptance responses locally. The source references and responses were unchanged. No provider calls or phone-store access occurred.

| Finding | Count |
| --- | --- |
| Development receipts / merchants | 5 / 3 |
| Checked purchase descriptions and line amounts | 66 / 66 |
| Cross-receipt exact-description pairs | 3 |
| Those pairs within the same merchant | 3 |
| Model-extracted same-merchant product-code pairs | 3 |
| Code pairs also sharing an exact description | 3 |
| Manually verified codes, quantities, units or unit prices | 0 |
| Model purchase rows with codes | 63 of 66 |
| Model rows with quantities / units / unit prices | 4 / 2 / 4 |
| Code pairs with quantities on both purchases | 0 |
| Code pairs with unit prices on both purchases | 0 |
| Held-out receipts | 0 |

The checked references mark codes, quantities, units and unit prices unreviewed. Field absence in these references cannot be interpreted as absence from the original paper. The retained model output supplies candidates, but its field presence is not a correctness measurement.

The sample supports three candidate purchase-history links. It cannot establish product identity precision, matching recall, or a trustworthy unit-price change. Equal descriptions and store codes can still conceal changed packages. Line amounts describe what was charged for a row and can differ because of quantity, discounts or returns.

The existing local search already preserves descriptions, original evidence and SKU matches. Reuse those representations and source navigation. A purchase link must refer to the receipt and current line identity, with explicit user correction, rather than rewriting the source description.

## Revised remaining tasks

| Task | Deliverable and acceptance |
| --- | --- |
| P10-02 · Confirm and model repeat purchases | Present the three candidate pairs for focused verification of printed code and product/pack identity. Let the owner mark same product, different product, or uncertain. Implement reversible local links with receipt/line provenance after this check. Evaluate fictional cases for different merchants sharing a code, changed pack sizes, duplicate imports, multiple identical rows in one transaction, missing codes, returns and discounts. Only explicitly confirmed links count as confirmed identity. |
| P10-03 · Item history | Add purchase history to saved row detail and item search. Show date, store, printed description and line amount with access to each original. Provide unlink/correction. Draft status, archived receipts and missing dates must remain visible. Verify corrections, receipt deletion, restart and backup/merge preserve or invalidate links appropriately. |
| P10-04 · Comparable prices | Compare only compatible products, units, currencies and price bases with adequate evidence. Distinguish printed unit price from an explicitly derived line amount divided by verified quantity. Keep pre-discount, net and tax-inclusive amounts distinct. A focused real repeated purchase with printed quantity or unit price is required for real-data acceptance. Until then this portion remains fixture-verified. |
| P10-05 · Personal acceptance | Check previous-purchase retrieval and undo on the iPhone. Report confirmed versus candidate links, real-data versus fixture coverage, and measured interaction effort. Resolve misleading comparisons before accepting the phase. |

## Human input

No full relabeling of the five receipts is required. P10-02 needs a small review of the three candidate pairs, covering codes and product/pack identity omitted from previous labels. Existing references for descriptions and amounts remain useful.

For P10-04, a future receipt showing a repeat of a previously purchased weighted item with its printed quantity and unit price would provide a real comparison. Two purchases of the same packaged item with explicit count and pack size would also work. Confirm their relationship before treating the pair as evaluation truth.

## Reproduction

Run `python3 evaluation/purchase-history/audit.py` from the project root. It reads only the existing private evidence and emits aggregate counts and input hashes. Product details, prices, dates and photos remain local. It measures field coverage and candidate pairs, not matching accuracy or recognition accuracy. The input hashes enable a subsequent run to detect evidence drift.

## P10-02 review prepared

The owner approved P10-02. The offline review page contains three candidate pairs, each with both full source photos and separately labeled model-read codes. It asks for product identity, pack-size evidence and code verification independently. Uncertain and unreadable answers are valid completed reviews. Answers bind to hashes of the existing reference, responses and photos. No decisions are preselected.

Generate with `python3 evaluation/purchase-history/review.py`. Save the exported `sliplet-p1002-checked.json` in the project root, then validate with `python3 evaluation/purchase-history/review.py --validate`. The page, proposal and exports are excluded from Git. A local validation exercise accepted a completed uncertain review and rejected incomplete, wrong-review, missing-case and mismatched-input exports.

At review preparation, implementation awaited the owner's pair decisions. The verified export and implementation are recorded below. The storage review identified existing receipt revisions, line IDs, original asset hashes, transaction guards and encrypted receipt payloads as the foundations for links. Confirmed identity must retain the evidence used at confirmation and stop resolving when that evidence changes or an endpoint is removed. Candidate suggestions and explicit rejections must remain distinct from confirmed links. Backup merge must respect existing records and must not resurrect an undone link through a divergent peer record. These cases require persistence checks during implementation.

## P10-02 accepted evidence and implementation

The exported review passed all three case checks and matched the source hashes. The owner confirmed the same product, same pack and printed code for all three pairs. One note explicitly distinguishes differing quantities from equal unit prices. The original export and note are preserved locally in the ignored review folder. Historical receipt references were not relabeled. The product-link rules use no hardcoded merchant, description, code or purchase from these examples.

The implementation introduces row endpoints, revision-and-original evidence snapshots, explicit same/different decisions, and a separate same/different/unknown pack decision. Candidate discovery uses a matching code within a normalized merchant, or an exact normalized description where a code is missing. Conflicting codes never fall back to a name match. Different merchants, exact-image duplicate imports, rows from the same receipt, adjustments and nonpositive amounts do not become candidates. Rephotographed duplicates cannot be reliably identified by this rule and require human review.

A confirmed or rejected pair is stored in both encrypted receipt payloads in one transaction. Both copies must agree and both current revisions must match before resolving it. Any content revision conservatively makes the previous decision inactive, even if the edit concerns another row. Organization changes preserve links. Explicit undo removes both copies with fresh concurrency tokens. Missing endpoints and one-sided old backups cannot resolve a link. Restoring a complete historical wallet to an empty store restores its historical decisions.

Receipt corrections preserve decision evidence, while removed rows can still be explicitly unlinked. Partial writes roll back, stale edits and revoked operations fail, old records decode without links, and malformed decision structure is rejected. No identity is inferred transitively from other pairs. A same-product decision with unknown or different pack size never establishes a comparable price.

This task delivers the matching and encrypted persistence foundation. P10-03 remains the user-facing history and confirmation/undo integration. The existing phone store has not been populated from the audit references, and this milestone makes no new phone interface available.

Verification used fictional receipts. The five initial link tests and 19 existing split/backup tests passed. Two additional checks passed for explicit-row scope, absence of transitive linking, legacy decoding and invalid endpoint rejection. No recognition, model or physical-phone performance claim follows from these checks.


## P10-03 item history

Saved purchase-row sheets now offer Purchase history. Current purchase matches in search offer the same destination. Unsaved row edits must be saved or cancelled before entering history. Original-only search evidence and adjustment rows do not expose product history.

History groups direct confirmed pairs, candidates, decisions invalidated by a revision, and rejected pairs. Entries are ordered by printed date with unknown dates last. Archived receipts participate with an explicit label, and drafts show Needs review. The comparison shows each printed row, merchant, date, line amount, available quantity/unit/code/unit price, plus independent access to the full digital receipt and original image. Product confirmation and pack selection remain separate. Undo restores candidate eligibility. Read-only receipt and photo navigation stays inside history so the original row editor and search query retain their place.

Writes use the P10-02 transactional API and publish both endpoints together to the workspace. Original loading checks the session and operation lease before and after decoding. The history and photo views cover private data when locked. A comparison whose receipt or row has been removed shows unavailable. Candidates still require explicit user confirmation, and this milestone adds no price-change calculation.

Validation on fictional data passed nine purchase-link domain/workspace/persistence tests and two native UI walkthroughs. The UI checks exercised row entry, original viewing, confirmation, undo, rejection, return within three points, search entry, full receipt viewing and query preservation. The dark large-text/Reduce Motion history list passed hit-region and sufficient-description audits. Unit tests cover archive/draft/changed/rejected states, missing dates, deletion, encrypted restart and restore, stale and interrupted writes, invalid endpoints and locked workspace access. No new provider call or physical-phone installation occurred. Device acceptance remains P10-05.


## P10-04 comparable row prices

Purchase comparison now offers Compare unit prices. The user selects printed unit price or line amount divided by explicit quantity independently for each purchase, verifies units and a common tax basis against the originals, then saves or clears that verification. Comparisons require reviewed receipts, a confirmed same-product/same-pack relationship, matching currency and compatible units. Missing quantity is never assumed to be one. Metric weight, imperial weight and volume normalize within their own unit groups; metric and imperial weights are not mixed.

The comparison covers item-row prices, not an allocated final basket cost. Separately listed coupons, fees and taxes are excluded and disclosed. Embedded discounts remain in a calculated row rate. Exact rational arithmetic determines equality and ordering; rounded display values are marked approximately. Unsupported or overflowing values stop comparison. Evidence is mirrored in the existing encrypted pair decision, handles reversed viewing order, and becomes inactive after receipt revision. Clearing price verification preserves the product link.

The owner completed the focused pair review. Its source hashes and both answers validated, and the accepted export remains ignored locally. The owner's note establishes that one single-quantity row requires calculation while the other has a printed unit price. The native comparison engine confirmed equal unit prices despite differing line amounts. CAD uses the previously approved default; this review does not establish a printed currency. Historical references and originals were not rewritten, and no receipt fields were imported into the phone store.

Reproduce the private check with `python3 evaluation/purchase-history/price_review.py --validate`, which validates the local export and creates a temporary native test manifest. `PurchasePriceTests.testCheckedPrivatePair` consumes that manifest without logging private amounts; it skips when the manifest is absent. Remove the temporary manifest after testing.

Validation passed 15 native tests, including the checked real pair, fractional quantities, compatible unit normalization, missing evidence, currency mismatch, arithmetic bounds, persistence and clearing. One simulator UI walkthrough passed verification, result display, save and clear; its fictional screenshot was inspected. These results cover one exposed real pair plus fictional fixtures, not general matching accuracy. No provider calls or phone installation occurred. P10-05 remains physical-device acceptance.
