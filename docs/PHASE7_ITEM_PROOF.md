# P7-02: one-item interpretation proof

## Decision

Do not promote the candidate. The frozen, unchanged five-receipt comparison remains **43/66 exact purchase pairs before and after**, with zero lost correct scored line or summary fields. There are zero held-out receipts. No production source changed, no candidate actual-app run was attempted after this failed preliminary gate, and no phone or normal Simulator data was modified.

## First divergent step

The selected case uses an existing manually checked purchase description and amount. Both are present in the retained observations, but in separate adjacent rows: an unpriced product description with a parenthesized count and long product code, followed by an explicit count × unit price and printed extension. The counts agree, and the two printed monetary values satisfy exact extension arithmetic.

The original row grouping preserves this structure. `purchaseContinuationRows` does not join it: the head's parenthesized prefix fails its leading-SKU guard, and the numeric rate tail is not an alphabetic continuation. `interpretationRows` also rejects the tail as a standalone price because it contains two monetary tokens. The parse loop then treats the tail as pending rate information. The product remains unpriced instead of becoming a purchase. This is a demonstrated interpretation failure, not missing OCR digits in the selected case.

The reference was checked previously; no new human image/region annotation was made in this milestone. Name containment plus source text is used for diagnosis only, not substituted for the strict scorer's identity rule.

## Bounded trial

The evaluation-only worker calls the unchanged production parser and appends a candidate only with:

- a recognized merchant and an immediately adjacent description/rate row pair;
- an explicit parenthesized integer count and long product code;
- a matching integer count followed by `@`, a printed unit price and a printed extension, with no extra tokens or signs;
- valid geometry, a downward gap of at most 1.5 line heights, and an indented rate row;
- exact extension arithmetic and no source already consumed by an existing parsed line.

It copies the printed extension rather than calculating a missing amount. It retains the entire OCR description, all source IDs and every original observation. It does not remove count prefixes, retailer suffixes or other text to match checked labels. Expected labels/amounts are never inputs to the Swift worker. Existing review diagnostics remain; this is a proof harness, not a finished integration.

## Results and limits

| Measure | Result |
|---|---:|
| Exact purchase pairs | 43/66 → 43/66 |
| New source-linked candidate lines | 3 |
| Added lines whose amounts equal a uniquely contained reference | 2 |
| Lost previously correct scored line fields | 0 |
| Lost previously correct scored summary fields | 0 |
| Raw observation arrays preserved | 5/5 |
| Repeat parser runs equal | 5/5 |
| Checked Costco transcript outputs unchanged | 2/2 |
| Fictional positive/negative cases passed | 11 |

The third candidate is not claimed as a verified recovery. The two containment diagnostics also do not count as strict recovered items: the full descriptions contain extra printed/OCR text relative to the checked names. That mismatch remains unresolved. This trial demonstrates a local association mechanism and possible recoverable prices, but **does not demonstrate improved end-to-end recognition**.

Negative cases cover missing extension, wrong extension, trailing minus, additional money, inconsistent counts, excessive distance, unknown merchant, missing geometry, absent count prefix, and an intervening row. No speed, camera, physical-device or unseen-receipt claims follow from this native parser replay. The 43/66 frozen reference is not mixed with the later fresh-Vision 42/66 engine-comparison run.

## Reproduction

Compile `evaluation/receipt-item-proof/ProofWorker.swift` instead of `ParseWorker.swift` using the unchanged domain/parser source list and macOS Swift invocation described in `PHASE7_REPRODUCTION.md`. Output `/tmp/sliplet-p702-proof`.

Run `python3 evaluation/receipt-item-proof/run.py` only with a new private output directory (the script deliberately refuses to overwrite the retained run). It consumes the five `p5-06-final` captures and the two existing checked transcripts; it never re-OCRs or edits them. The retained run is `private-receipts/evaluation/p7-02-final`. Run `python3 evaluation/receipt-item-proof/verify.py` to revalidate source hashes, replay the five captures, check the saved scores and rerun the fictional cases. Only aggregates may leave private storage.

## Proposed next decision

Keep production unchanged. If separately approved, investigate **P7-03: source-verified description boundaries for this same item pattern**. Determine which prefix/suffix characters are product identity versus separately printed quantity/retailer metadata, using existing originals and checked references. Do not simply strip arbitrary codes or loosen scoring. If the evidence does not settle that distinction, ask one targeted question about the source region. Only after a frozen comparison exceeds 43/66 without regression should an actual-app comparison be attempted. This proposal is not approval to start it.
