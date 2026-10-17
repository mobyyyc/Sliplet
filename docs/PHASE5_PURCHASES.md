# P5-03 — Source-backed purchase assembly

2026-10-17 · Approved in Main · Parser `p5-03-purchases-0.5.0`.

## Changes

Long printed item-code prefixes now participate in the existing mutual-nearest description/price pairing for known retailers. Short numeric prefixes remain unresolved because they may represent quantities. Unknown-store product names can compete for a nearby price but remain unpaired automatically. A price must be standalone, to the right, locally close and uniquely associated; a matching receipt total never resolves a tie.

A bounded continuation rule joins an unpriced, SKU-anchored description with the immediately following indented priced text. It requires complete geometry, a known retailer, a vertical gap between 0.45 and 1.75 smaller text heights, indentation between 0.5 and 4 text heights, one printed amount, and no summary/payment/tax/adjustment/date/merchant/quantity/second-SKU boundary. Unanchored or ambiguous wrapping remains unresolved. This is a conservative geometric rule, not a trained layout model or a guarantee for all formats.

Original text and source IDs are conserved; repeated purchases remain separate; no amount, quantity or unit price is calculated to fill a missing field. Existing quantity/unit-price extraction remains unchanged. No OCR settings, cloud services, Apple Intelligence, user interface or review/Finish gates changed. Existing five references and two checked transcripts are reused without new manual annotation.

## Measured result and acceptance decision

All ten imports succeeded, five repeat pairs were stable, and five save/reopen checks passed. All previous draft field values and source memberships were independently preserved on all five receipts. Automatic raw text/geometry is unchanged.

One additional purchase candidate is assembled. One linked OCR observation contains exactly one checked reference name; the parsed amount agrees with that reference. Another linked fragment contributes a short printed code to the description, so the strict scorer intentionally leaves the row unmatched. No reference text was edited, no code was silently stripped, and amount agreement was not used to choose an identity. This source-name diagnostic is not a human-verified region annotation.

The new unmatched-output proxy increases by one. Unlike the rejected P5-02 footer row, this candidate has a unique checked purchase name in its own source plus the agreeing amount; it is retained as a draft candidate with unresolved description quality. This is a deliberate, disclosed residual—not a claimed fully correct recovery. The generic zero-new-unmatched-proxy condition is not met; the no-new-wrong-money and no-lost-correct-fields checks are met for the checked scope. General precision remains unestablished.

Legacy exact purchases remain **53/66**, strict exact pairs **43/66**, subtotal **4/4**, total **3/5**. No fully correct receipt or complete-accuracy gain is claimed. Wrapped-description behavior is demonstrated by fictional tests only on this set. Existing quantity/unit-price and incomplete attribute labels remain unchanged. First/repeat import medians were **787/785 ms** in the hosted Debug Simulator.

**99 focused native tests** (including eight new purchase cases), **18 scorer tests**, and **two private hosted methods** passed. The initial staging attempt lacked the standalone test bundle; it was preserved as an incomplete setup, then a test bundle was generated and the actual imports ran in a fresh folder.

## Verification and limits

The focused native suite covers long versus short codes, source-linked amounts, competing prices, unknown retailers, wrapped descriptions, boundaries, duplicates and missing geometry, together with the existing parser, summary, currency, adaptive-reading and workflow regressions. Actual-app and checked-text results are recorded in the aggregate evidence.

This remains development evidence on five exposed purchases with zero held-out purchases. Repeated successful imports are not independent validation, and unverified quantity/SKU/tax-marker attributes remain unscored. No phone camera, phone latency or human correction-time claim is made. Simulator handler-to-review timings are Debug measurements, not controlled cold-cache benchmarks.

[Aggregate results](evidence/p5-03/aggregate.json) · [Validation](evidence/p5-03/validation.json) · [Reproduction](../evaluation/receipt-purchases/README.md)
