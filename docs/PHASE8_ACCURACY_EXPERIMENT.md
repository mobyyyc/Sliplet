# P8-02 — bounded real accuracy experiment

Approved 2026-10-24. Bounded experiment complete; candidate rejected for integration. Production app unchanged.

## Frozen comparison

Baseline: 57/65 exact purchases, 3/5 totals, 4/4 checked subtotals, 4/8 adjustments, merchant/date 5/5. The retained Phase 7 acceptance check passed again before model evaluation. References remain unchanged. Five exposed receipts, zero held-out receipts.

Candidate: Groq `qwen/qwen3.8-27b`, existing P8-01 prompt v2 and strict schema. Account Free plan and inference ZDR are user-confirmed; the corrected five-image transfer approval is privately bound to exact export/PNG hashes. Direct consumer-app BYOK eligibility remains unresolved and separate from this approved developer test.

Protocol: eleven image-only fictional challenges, then the weighted case with local raw Vision OCR. At most twelve fictional requests. Choose image-only unless the paired OCR case fixes a core failure without introducing errors. This is a narrow OCR-assisted comparison. Freeze configuration before looking at real scores. Two passes over the five approved redacted receipts, at most twenty real requests. Current inputs each fit one prepared image: ten real calls expected. Maximum output 6,000 tokens, no overview, no automatic retries, 65-second spacing. Stop on rate/quota/provider errors. No account upgrade or paid fallback.

All exact requests/responses and source hashes remain private. The runner cannot take an arbitrary receipt path. It verifies the approved export and opaque masks before sending. No original photos, checked answers, original OCR or local identities appear in model requests. Optional OCR is produced from the prepared pixels only. Metadata is removed locally.

## Measurement and decision

Use the unchanged reference normalization and comparator. Explicitly report source matches based on raw OCR, model boxes and unresolved cases. Model-provided boxes remain claims, not verified evidence. Payment/change rows are outside existing label coverage and are reported separately. Quantity/weight/unit-price extraction is tested on fictional evidence but lacks verified real-corpus labels. Do not imply those fields achieved 90% accuracy.

Report exact purchase pairs, summary fields, exact adjustments, previously correct losses, unmatched rows, validation errors, instability, latency and token use. Required acceptance: at least 59/65 purchases, all five totals, four checked subtotals, eight adjustments, preserved merchant/date, no previously correct loss and no unsupported money. A partial gain does not pass the full gate. No app integration is authorized by running this experiment.

## Harness correction

After two completed fictional calls, the reservation log was found to concatenate JSON arrays because append mode ignores seek for writes. The runner stopped before a third call. Recovered the two complete reservations, preserved the original log privately, changed to locked read/write mode and added a three-reservation regression test. No completed call was repeated; model prompt, geometry, expected answers and scoring were unchanged. The implementation-hash correction is recorded privately.

Implementation and reproducibility: `evaluation/receipt-vision-ai/experiment/README.md`.

Provider documentation checked 2026-10-24: [model capabilities/output limit](https://console.groq.com/docs/model/qwen/qwen3.8-27b), [rate limits and account-specific exceptions](https://console.groq.com/docs/rate-limits).

## Outcome — 2026-10-24

**The bounded experiment is complete; this configuration is rejected for integration.** Both five-receipt passes were attempted. Provider failures remain in the denominator; this is not ten successful extractions. The app and previous baseline remain unchanged.

Twelve fictional requests: 10 exact cases. The weighted case failed both with and without OCR because the measurement line was included in the description. Quantity, unit, unit price and amount were correct on that fictional example. The 40-item/two-tile case, repeated items, summary-word product, discount, return, unreadable total, printed instruction, product suffix and multilingual cases passed. The paired OCR test did not justify selecting OCR hints for private requests.

Eleven real requests: the ten planned samples plus one explicitly user-authorized retry of the first rate-limited attempt. Eight returned structured outputs: seven failed image-source identity validation; one passed source/schema checks but had a total conflict. Three attempts were rate-limited. After provider errors the runner stopped; Main inspected the available diagnostic before resuming only unattempted samples. Only the one user-requested retry repeated an attempted payload. No paid upgrade, alternate account/provider or background retry loop was used.

| Measure | Existing baseline | Frozen model pipeline pass 1 | Frozen model pipeline pass 2 |
| --- | ---: | ---: | ---: |
| Exact purchases | 57/65 | 0/65 | 17/65 |
| Correct totals | 3/5 | 0/5 | 1/5 |
| Correct checked subtotals | 4/4 | 0/4 | 1/4 |
| Exact adjustments | 4/8 | 0/8 | 0/8 |

These are **end-to-end pipeline results**, including rejected/missing outputs, not claims that the vision model read no words. The first pass's official score keeps its original rate-limited attempt; the authorized retry is reported separately. Token usage across all real returned outputs was 38,884; per-request elapsed time includes Keychain access, network and validation, not iPhone performance.

### What the rejected outputs show

Offline diagnostic projection assumed a single invalid image identifier meant the only supplied image, without accepting or rewriting the stored response. It still enforced the remaining shape/geometry checks. It reached only 6/65 and 23/65 exact purchases under the frozen source/reference comparator, with unresolved or unverified source positions explicitly retained. These are conditional diagnostics, not improved official scores, and not proof that every unmatched row was hallucinated.

Raw summary readings are a separate signal: all five first-pass returned responses (including the user-authorized retry) had the correct total and all four checked subtotals. But dates were only two correct, one wrong and two missing; merchant names were three correct and two different. This signal is worth investigating, but cannot justify replacing the existing recognition path. Only three second-pass calls returned output, so no complete repeated summary success is claimed.

Observed failure categories:

- The schema allowed arbitrary image identifiers, and the model repeatedly supplied a different one. One identical request produced different source-contract validity across passes. Restrict identifiers in the request schema instead of repairing them silently afterward.
- A response omitted most product codes from descriptions even though its source quotes retained them. This is output transformation loss, not proof the pixels were unreadable. Preserve literal transcription separately from cleaned display text.
- Costco responses emitted no negative amounts and mislabeled discount rows as purchases. Passing a simple fictional prefix-minus coupon did not cover the real discount notation/association problem. More faithful fictional sign/role cases are needed before another private test.
- Some model boxes were invalid; another response cited multiple unexpected sources. Fixing a single identifier alone is insufficient.
- Date interpretation and literal merchant-name differences also require source-preserving handling, not answer-specific aliases.
- The first checked raw total improvement did not carry through a safe accepted receipt.

Rate-limit diagnostics remain unresolved: headers reported 8,000 tokens/minute, while the final error classifier recorded a tokens-per-minute limit of 1,000 and a requested count of 3,339. Do not infer the cause from a header alone, upgrade the account or claim longer waits solve an oversized-request constraint. Full error bodies and organization/account identifiers were intentionally not retained.

### Validation and evidence

19 experiment tests, 33 existing lab tests and two redaction-rule tests passed. Checks include exact money/no rounding, duplicate source ambiguity, tile transforms, incomplete output rejection, payload isolation, approved-export tamper rejection, bounded request reservations, masked-text exclusion from native Vision OCR hints and sanitized quota diagnostics. The Phase 7 baseline verifier passed. No app source changed, so no new app build/device validation is claimed.

Public aggregate-only evidence: `docs/evidence/p8-02/aggregate.json` and `fictional.json`. Originals, approved images, exact requests/responses, reference hashes, source diagnostics and ledgers remain ignored and owner-only. Existing labels were not edited. Quantities/units/unit prices still lack verified real-corpus labels. Five exposed receipts, zero held-out receipts.

## Proposed next task: P8-02B — correct the contract before another benchmark

**Not implemented or approved by this report. Do not advance to P8-03.**

1. Constrain source IDs to the exact supplied image IDs in the request schema; validate optional boxes without guessing replacements.
2. Separate literal product/amount transcription from interpretation. Retain codes and measurement lines as source data; normalize explicitly printed trailing/prefix minus signs deterministically. Never infer a discount or amount just to balance the total.
3. Build six focused fictional cases covering dense codes and coupons, weighted multiline purchases, repeated products with discounts, ambiguous dates/digits, untrusted instructions/source identity and multilingual text. Reuse existing checks locally. Select one revision before private evaluation.
4. Investigate the contradictory quota diagnostics and preflight request/output sizes against the effective account limits. Keep the account free. If a usable limit cannot be established, stop before further private transfers and propose the local-Mac route separately.
5. Only if fictional checks and quota feasibility pass, run two new passes on the same approved redacted five receipts with unchanged references. Report this new configuration separately from P8-02. Treat summary-field assistance as a possible limited outcome, not permission to replace correct local items.

Proposed additional budget: at most six fictional requests and ten real requests; no automatic retries, provider changes, paid tier or application integration. This is a new bounded test budget requiring Main/user approval, rather than quietly extending the exhausted fictional comparison.

Final offline verification passed: all 23 attempt records and payload hashes agree, each real request reproduces from the approved export, frozen references/scorer are unchanged, and both published reports reproduce. No network calls were made by verification.
