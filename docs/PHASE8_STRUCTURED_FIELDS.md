# Phase 8: structured fields and complete-image experiment

## Approved scope

Following human-confirmed reference-v4, the user approved dedicated receipt fields
and a bounded test using complete actual receipt images. Existing Gemini Free-tier,
personal Keychain credential and native stateless endpoint are retained. This is
an isolated lab change, not production recognition or a phone installation.

The experiment allows two fixed fictional cases (dense coupons, then weighted)
and five real receipts, once each. Both fictional core-field gates must pass
before any real upload. Requests are at least 95 seconds apart, with no automatic
retry or model fallback. A failed request stops further dispatch. The output cap
is 6500 tokens to accommodate the expanded literal ledger; timeout remains 60
seconds. An interrupted request reservation is not silently replayed.

## Extraction contract

- Preserve literal row/continuation text alongside full printed descriptions.
- Keep printed product/coupon codes both in the description and a dedicated field.
- Keep name-column suffixes; separate quantity prefixes and price-column markers.
- Retain literal item tax markers, printed tax legend, tax base, percentage and
  charge separately. Never infer tax-free status from an absent marker.
- Retain quantity, unit and unit price separately. Do not infer quantity one or
  calculate missing extensions. Preserve sub-cent unit-price precision separately
  when the canonical cent field cannot represent it; never round it silently.
- Preserve non-accounting loyalty/member/payment rows as evidence, excluding them
  from accounting totals. Zero-priced actual products remain purchases.
- Preserve malformed original fields, mark the working value unknown and require
  review; structural violations or incomplete responses reject the candidate.

The model receives only the full receipt photograph, generic instructions and
schema. No OCR, expected answers, human labels or source coordinates are supplied.

## Inputs and comparison

Complete original-local PNGs are resized as whole frames to at most 1200 by 1600
pixels and encoded as metadata-free RGB JPEGs. No crop or redaction is applied;
this follows the user's explicit authorization to use actual receipts. Source and
sent-image hashes stay private. The configuration is frozen before inference.

Reference-v4 and the unchanged unique kind/description matcher are used for both
saved local OCR and the new model output. Exact indistinguishable duplicate groups
remain a separate supplementary count. Extra output is not silently discarded by
the scorer. Prior model results are reported alongside new results.

Prompt, schema and source visibility change together; results cannot isolate a
prompt effect. Five exposed receipts are calibration data, with zero
held-out receipts. Quantity/unit-price coverage remains unverified in the current
reference, so broad accuracy claims for those fields are out of scope. A field
being populated is not proof that it was read correctly.

## Validation and execution

`structured_extract.py` implements the new contract; `structured_trial.py`
provides prepare, one-request next, and reproducible report commands. Private
requests/responses/configuration are under `p8-02e/structured-full-01`.
Both fixed fictional gates and all five real requests completed successfully.
The final targeted suite has 25 passing tests. Results and limitations follow.

## Completed results — 2026-10-28

All seven requests returned usable output: two fictional gates and five actual
receipts. There were no retries, fallback models or additional live experiments.
Real response times were 7.504–28.319 seconds (median 15.722). All retained requests
reproduce from frozen images/configuration, and canonical output reproduces from
retained provider responses. No malformed numeric fields were isolated in this run.

| Same reference-v4 measure | Prior Gemini | Frozen expanded schema | Local boundary replay v2 | Local OCR |
| --- | ---: | ---: | ---: | ---: |
| Strict exact purchase pairs | 48/66 | 27/66 | 52/66 | 49/66 |
| Exact duplicate-group purchases, additional | 8 | 10 | 10 | 10 |
| Core purchases including groups | 56/66 | 37/66 | **62/66 (93.9%)** | 59/66 (89.4%) |
| Exact adjustments | 7/9 | 8/9 | 8/9 | 4/9 |
| Correct totals | 5/5 | 5/5 | 5/5 | 3/5 |
| Correct canonical dates | 1/5 | 4/5 | 4/5 | 5/5 |

One date remains unresolved because the printed numeric format is ambiguous.
A currency claim unsupported by an explicitly printed ISO token was rejected by
the existing conservative validator. No default currency was counted as reading.

### Why the raw schema score regressed

The model transcribed 26 name-column suffixes but assigned them to `tax_marker`.
This was a field-boundary error, not evidence that those strings vanished from
the reading. The frozen score remains 37/66. The raw result is never replaced by
the improved replay, and unknown tax-marker correctness is not awarded credit.

### Separate post-hoc local recovery

`structured_layout.py` recovers a multi-letter suffix only when the literal
transcription contains the same description, marker, and printed extension in
that order on one line, and no printed legend supports that marker. A single-letter
marker or marker after the price is not moved. This first replay recovered 23
boundaries and scored 59/66 core purchases.

`structured_layout_v2.py` additionally accepts an explicitly attached measurement
line: quantity, unit when present, unit price and printed extension must all match
the candidate's separate fields, and exactly one such continuation must exist.
It never calculates an extension, matches another reference row by price, or uses
merchant/name/suffix lookup tables. Conflicting/missing measurements do not qualify.
This recovered three further boundaries: 26 total, scoring 62/66 core purchases.
The residual purchase failures are four unmatched descriptions under the unchanged
matcher; this alone does not prove four purchases or amounts were unreadable.

All recovered descriptions are **review-required proposals**, not independently
verified image readings. The original candidate and literal text are unchanged;
the original marker is retained separately as a proposed status marker with unknown
tax meaning. Nothing is inferred to be taxable or tax-free. Numeric amounts,
quantities and prices are unchanged. Neither replay sends an API request.

Replay 01 and replay 02 retain separate manifests, ledgers and summaries. The
public `structured-trial-result.json` reports the frozen run;
`structured-layout-result.json` reports replay 02 and explicitly labels it post-hoc.
Do not merge these into a single claim that the frozen model achieved 93.9%.

### Additional field coverage and limits

The raw candidate retained 75 accounting rows and 24 non-accounting rows. It
populated four quantities and four unit prices, one tax base and rate, and literal
text for every accounting row. These are presence counts, not verified accuracy.
Reference quantity/unit-price fields remain unreviewed. Both independently checked
item tax markers match in the new structured output, but that is only two checked
markers. Most proposed markers are not independently verified; 26 are the very
name-boundary issues described above. No printed tax legend was returned.

The result supports moving toward the optional model path, especially for totals,
adjustments and retained semantic detail. It crosses the user's 90% purchase target
only in the post-hoc, review-required replay on these five exposed receipts.
Prompt, schema, input visibility and replay changed; there is no isolated prompt
benefit, repeatability, held-out generalization or physical-phone accuracy claim.
No app behavior, review gate, key-settings flow or installed build changed.

### Next approval

Freeze the v2 boundary adapter before a fresh bounded confirmation run on the same
complete images and reference-v4; evaluate both raw and adapted output, review flags,
extra rows, summaries and retained structured fields. Do not tune that frozen run
in place or claim independence from this exposed corpus. If the benefit repeats,
prepare P8-03 integration as an optional reviewed-draft path while retaining local
OCR. New unseen receipts remain a proposed later validation step, not a prerequisite
silently added to this task. No new complete manual labeling is needed to start.

Validation: 25 targeted tests cover field retention, exact money and sub-cent unit
prices, non-accounting versus zero-priced products, malformed/incomplete responses,
call budget and duplicate reservations, immutable source candidates, price-column
and legend counterexamples, and explicit versus conflicting measurement continuations.
The final run and replay reproduce; private receipt content/credentials are excluded
from committed evidence.
