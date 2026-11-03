# Phase 10 · Purchase history

November 3, 2026. P10-01 approved and completed. Remaining tasks require individual approval.

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

Implementation awaits the owner's pair decisions. The storage review identified existing receipt revisions, line IDs, original asset hashes, transaction guards and encrypted receipt payloads as the foundations for links. Confirmed identity must retain the evidence used at confirmation and stop resolving when that evidence changes or an endpoint is removed. Candidate suggestions and explicit rejections must remain distinct from confirmed links. Backup merge must respect existing records and must not resurrect an undone link through a divergent peer record. These cases require persistence checks during implementation.
