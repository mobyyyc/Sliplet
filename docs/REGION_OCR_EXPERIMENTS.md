# P4-02 — Reading experiments

Approved in Main. The bounded automatic matrix and two user-verified literal transcript comparisons are complete. User-marked region comparison was not run because the export contains no rectangles; this limitation does not block the interpretation-first decision below. Production recognition remains unchanged.

## Frozen automatic matrix

Five previously exposed purchases, zero held-out purchases. Dedicated iPhone 15 Pro Simulator, iOS 27.0 build 24A434, hosted Debug tests; same production image decoding, language list, recognition level, parser and field adapter. The test implementation mirrors production OCR and captures up to three candidates. Its baseline exactly matches all five P4-01 semantic captures. Each variant runs twice per purchase: 70 successful attempts and 35 stable repeat pairs.

| Variant | Exact purchase amounts / 66 | Previously exact lines lost | New unmatched line proxies | Repeat median / maximum |
| --- | ---: | ---: | ---: | ---: |
| Current baseline | 53 | 0 | 0 | 746 / 806 ms |
| Language correction off (no-op control) | 53 | 0 | 0 | 743 / 805 ms |
| Language correction on | 54 | 0 | 0 | 754 / 809 ms |
| English only | 53 | 0 | 0 | 747 / 802 ms |
| Padded automatic text bounds | 52 | 2 | 4 | 1421 / 1557 ms |
| Three overlapping full-width strips | 47 | 8 | 7 | 1869 / 1908 ms |
| Second-ranked candidate, when available | 53 | 0 | 0 | 776 / 843 ms |

These are legacy parser-level amount recovery counters, not full-field accuracy. All five receipts remain incorrect under the stricter structured-field evaluation. Currency availability and incomplete expanded labels remain separate issues. Amounts are never inferred from arithmetic or expected answers.

Automatic bounds use the union of baseline OCR boxes with fixed 0.03 padding, not reference labels. Strips have fixed overlapping thirds and exclusive center ownership. All raw strip candidates, including excluded overlaps, remain captured. This rule is experimental and does not prove that every wrapped row or seam was preserved. Its measured regressions reject blanket strip integration.

The second-candidate diagnostic has no effect because the baseline produced only one candidate per observation on this runtime. Language correction on produced multiple alternatives for 326 observations, but no answer-guided selection was performed. No combinatorial search or receipt-specific configuration tuning took place.

Timing includes OCR and parser/field conversion; automatic bounds include the initial baseline pass, and the second-candidate diagnostic includes its shared baseline cost. It excludes Files UI, draft conversion/persistence and user review. It is therefore a diagnostic cost comparison, not an exact repetition of P4-01 handler-to-review latency or a phone-performance result. Both regional strategies exceed the previously proposed approximately 1.14-second median budget. Fixed variant order and a warm process limit timing interpretation.

## Geometry and provenance

The first fictional runtime gate caught a wrong assumption: this installed runtime returns ROI-local coordinates. The evaluation code now maps them once to normalized lower-left coordinates of the full oriented original. A generated upright fixture is encoded in each of eight pixel/orientation combinations; full-image and cropped marker locations must agree. The native gate passes for all eight orientations before any private-image experiment starts. Half-open band center ownership also passes its boundary checks.

The first private attempt stopped at this gate before processing private originals; it is retained as failed setup evidence. The accepted automatic run is `private-receipts/evaluation/p4-02-automatic-v2`. It passes three native tests; two explicitly assisted paths skip until verified input is supplied. Ten fictional Python tests cover regression multiplicity, source membership and assisted-input validation. Independent multiset counting reproduces all seven exact-line scores. Existing private evidence, originals, production app source and signing settings are unchanged.

Apple's [text recognition documentation](https://developer.apple.com/documentation/vision/recognizing-text-in-images) and installed SDK headers informed configuration and coordinate checks. Actual runtime fixtures determine the mapping used here. Perspective rectification was not evaluated: no verified corner transform is available in this experiment, and a geometric rewrite must retain an inverse source transform before it can enter an accuracy comparison.

## Human-assisted comparison

`evaluation/receipt-regions/annotation.py` generates a private local-only page from original images and the immutable P4-01 observations. Confirmations begin unchecked. Users correct literal text and location, add missing rows, and independently mark a reading region. It exports source/capture identities and explicit confirmations. Semantic ground-truth labels are never reconstructed into a supposed literal transcript.

`assisted.py` validates matching source identities, typed confirmations, unique row IDs, bounded original-coordinate boxes and nonempty text. Human text and regions are staged separately from automatic requests. The native checked-text path uses the unchanged parser without OCR. The region path preserves surrounding whole-image context, replaces enclosed evidence, conservatively suppresses overlaps, and retains candidates for audit. The literal transcript path has now run on two user-verified Costco receipts. The user-region path has compiled but remains untested on real receipts.

The user chose a visible, editable **CAD default** for future app behavior when currency is missing. This is explicitly user-provided context, never a claim that CAD was printed or recognized. Production integration belongs to an approved implementation task. The review page separately asks whether a currency identifier is actually printed; a dollar sign alone does not establish CAD.

## Final diagnostic decision

Keep current production recognition. Do not ship automatic bounds or strips. Language correction on is a small promising development result (+1 checked purchase amount, no lost checked line), requiring later integration approval and broader validation. Propose P4-04 (interpretation and field conversion) before P4-03 (adaptive OCR integration). P4-02 is complete as a bounded diagnostic milestone; P4-03 and later implementation tasks remain unstarted and require approval.

## Verified-text results and next-task rationale

The user checked two Costco transcripts and made three literal text edits in total, with no added/deleted observations or geometry changes. Native replay preserves those verified observations exactly and uses the unchanged parser. Purchase amount recovery remains **33/37**, all-kind line amount recovery **37/44**, and totals **0/2**. Merchant/date/subtotal stay **2/2** each. No new lost exact lines or unmatched output proxies occur. Both structured receipts remain incorrect. Independent multiset counting reproduces the purchase result, and the explicit checked-text native test passes (one method covering two transcripts).

These results establish that the remaining failures on these two checked transcripts persist after human text verification; they do not establish that every failure on the other stores is a parser error. They support prioritizing interpretation/field conversion rather than requiring users to crop every receipt. Correcting three text observations did not by itself recover any additional checked monetary lines.

Both exports explicitly report no printed currency identifier. Keep the existing printed-currency reference coverage unchanged for historical comparability; the new human evidence is stored separately. The approved visible, editable CAD default should be applied as explicit context in future draft conversion, with its origin distinguished from extracted evidence. It must never invent tax amounts or correct arithmetic automatically.

Although region confirmation boxes were ticked, both region values were null. The original export is preserved unchanged. A documented private derivative disables only those unsupported region confirmations while retaining text/currency verification. No user crop was guessed or labeled measured. A future targeted reread can revisit this if interpretation-first work leaves a specific OCR failure.

P4-04 proposal: preserve printed rows and provenance while improving interpretation of verified item/adjustment/summary context; represent extracted numeric evidence until currency is supplied; apply the user's editable default visibly; retest the five original images plus the two checked transcripts, source conservation, exact amounts, ambiguity, transactional review and storage. Do not promote +1 language-correction or regional OCR changes as part of this task without explicit scope approval. Full-field targets and unseen receipt validation remain unachieved.
