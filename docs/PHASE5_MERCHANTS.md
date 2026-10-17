# P5-04 — Merchant resolution

2026-10-17. Approved in Main; complete as bounded merchant-header hardening. P5-05 still requires approval.

## Implementation

`ReceiptMerchantDirectory` is a local, code-maintained directory for No Frills, Costco and T&T. It separates stable retailer identity from the displayed name, preserving visibly fictional demo identities. New entries need positive aliases and misleading-mention regression fixtures; no remote directory or model is used.

Resolution uses the first twelve grouped header rows, stopping at the first money-bearing row, summary label or explicit payment/thank-you boundary. Complete alias patterns replace unrestricted substring search. Conflicting retailer identities remain unknown and retain their source IDs in an extraction issue. The selected identity, rather than arbitrary display text, controls retailer-specific date and purchase rules.

Supported header forms include whitespace/full-width normalization, decorations, Costco Wholesale, spaced T&T, possessive operator names and two-word operator prefixes before No Frills, including an OCR-joined brand. For an exact T&T identity, a supermarket descriptor may differ by at most two edits. This tolerance never fuzzy-matches the brand itself. Context words, websites, product suffixes and conflicting brands are rejected. Operator prefixes are a bounded header heuristic, not general merchant-name understanding; unsupported or misleading phrasing can still require review.

No price inference, OCR setting changes, reference edits, review-gate changes, or automatic finalization. Original OCR remains unchanged.

## Verification

- 105 focused native tests pass, including six new merchant methods covering aliases, misleading mentions, footer/late matches, conflicts, date-policy routing and detached-price routing.
- 18 scorer tests pass; two private hosted methods pass.
- Ten actual-app Simulator imports of five existing originals, five stable repeat pairs, five draft save/reopen checks, and two previously human-checked Costco text replays.
- All five drafts preserve every previous field value and source membership. Raw OCR text/geometry is unchanged for all five; checked transcript observations are unchanged for both.
- Merchant and date results remain 5/5; checked subtotals 4/4; totals 3/5. Strict exact purchase pairs remain 43/66 and legacy exact pairs 53/66. No new unmatched output proxies or lost correct fields.
- First/repeat import medians were approximately 827/830 ms in this debug Simulator run. These are not physical-phone latency measurements.

The initial strict candidate lost three merchant headers. Intermediate candidates and failed test runs were retained privately; they were not accepted. Bounded noisy-header support restored all prior results. One date-policy test initially assumed unknown dates or no review flag; the final test instead asserts the ordinary date interpretation and rejects the retailer-specific interpretation.

This is coverage hardening, not an accuracy gain on the development set. There are five exposed purchases and zero held-out purchases. Existing unresolved totals, item descriptions and reference/identity uncertainty remain. The prior P5-03 additional candidate is unchanged and still is not an exact-pair success.

## Evidence and reproduction

Safe results: [aggregate](evidence/p5-04/aggregate.json), [validation](evidence/p5-04/validation.json).

Frozen private run: `private-receipts/evaluation/p5-04-final-v2`; parser `p5-04-merchants-0.6.0`. Earlier candidate directories are not the accepted baseline. Use `evaluation/receipt-merchants/run.py` with a dedicated `Sliplet P5-04 Merchant Lab` device and a build-for-testing output. The runner stages original images without labels in the app, compares against P5-03, checks frozen source/reference hashes, and verifies private captures. Keep all native logs and captures private. Public evidence contains aggregate counts and code hashes only.

No normal Simulator wallet or physical-phone installation was changed. Next proposed task: P5-05 focused corrections, connecting unresolved evidence to the existing targeted reread/edit flow while preserving Apply/Cancel and independent source review.
