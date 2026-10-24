# P8-02 bounded vision evaluation

This is an isolated developer experiment, not a production recognition change. Run with the bundled Python that provides Pillow. `ocr.swift` builds a local Vision OCR helper; its output is captured privately. No additional model/runtime installation is required.

## Commands

- `runner.py preflight`: verify the exact approved export against the private approval digests, corrected masks, dimensions and original upright pixels. Prepare geometry in memory, check request sizes and freeze configuration. No network.
- `runner.py fictional`: eleven image-only challenges and one repeat of the weighted challenge with raw Vision OCR from the same prepared image. Maximum twelve calls total, including failed or interrupted attempts. Completed calls are not repeated on resume.
- `score.py fictional`: compare all five summary fields and ordered kind/description/amount rows; additionally score quantity, unit and unit price on the weighted case. Preserve repeated occurrences. Missing printed values must remain null. The fixed selection rule chooses OCR only if it fixes the weighted case without new errors; otherwise image-only. This one paired case is a narrow comparison, not proof about OCR assistance in general.
- `runner.py real`: requires selection and the approved exact five-image export. Two passes, maximum twenty real requests. Current five inputs each fit one image and require ten total requests. No labels, old OCR, source hashes or local filenames enter requests. The OCR-assisted variant, if selected, runs fresh local Vision OCR on only those prepared redacted images.
- `score.py real`: reuse the frozen P7-05 reference and Phase 7 scoring implementation. Write full output and errors privately; print only aggregate counts. Quantities/units/unit prices lack human-verified labels in this corpus and cannot be advertised as accurate from these results.

## Fixed inputs and limits

Image-only is the default. No prompt tuning against private outputs. Use the P8-01 prompt v2 and schema unchanged, temperature zero, 6,000 maximum output tokens (increased from the short smoke's 3,000 before any challenge call to accommodate longer ledgers). The model's documented output limit is 16,384; actual Free account limits remain provider-controlled. Space requests 65 seconds apart, stop on provider errors, never upgrade the account or automatically retry. Reservations are locked and persisted before sending, so an interrupted request consumes its allowance.

Remove metadata by decoding the user-reviewed flattened PNG. Never unmask or recrop it. Downscale to maximum width 1,200, never upscale; tile at height 1,600 with 160 overlap, at most four tiles/two requests, no overview. Encode JPEG quality 95 with no chroma subsampling. This preserves already-redacted input; it cannot restore covered pixels. Retain private transform metadata. The long fictional receipt tests two overlapping tiles in one request. Current real inputs all fit one tile. Multi-request merge scoring is fail-closed, not guessed by names/amounts.

Exact approved PNG hashes and export digest are verified before real calls. Export approval does not approve other receipts or different masks. API credentials come only from the existing macOS Keychain entry and are never written to request/response files. HTTPS goes directly to the fixed Groq endpoint using the existing no-proxy/no-redirect transport. Raw responses, exact derived payloads, source claims, error ledger and hashes stay in ignored owner-only `private-receipts/evaluation/p8-02`. Public evidence must contain aggregate statistics only. User confirmation of Free plan and inference ZDR is not API verification.

## Scoring and limits

Summary/line scoring reuses the frozen labels and original normalization. No amount-assisted pairing. A unique candidate description can anchor an occurrence in raw original OCR; ambiguous descriptions are not arbitrarily assigned. Otherwise map the model's optional source box through the tile transform and report it as an unverified model claim. Source identities with neither method remain unresolved. Existing reference rows without source regions use the unchanged baseline comparator's unique kind/description matching, so this is not universal independent source verification.

Report raw candidate, validation warnings and canonical score separately. Payment/change are counted separately because the frozen corpus does not annotate them, rather than automatically treating them as invented purchases. Unmatched accounting rows require audit; they are not automatically proof of hallucination. Wrong amounts, unresolved source associations and transport/truncation failures retain the full five-receipt denominator. Compare losses against the retained baseline for each previously correct field/row. Balanced totals alone cannot pass source review.

Five exposed receipts, zero held-out receipts. No unseen-accuracy, all-field, device-performance or production-readiness claim. A failure can justify stopping before P8-03. Any integration decision requires Main review and the user's next milestone approval.

## Retained result

P8-02 is closed with a rejected candidate; see `docs/PHASE8_ACCURACY_EXPERIMENT.md`. No new calls are authorized by the existence of these commands. `diagnose.py` is an explicitly conditional, post-hoc offline report; it never changes the frozen primary score or stored responses. The first authorized retry is counted separately, not silently substituted into the primary score. Real usage across rejected and valid outputs comes from retained raw envelope metadata; primary per-pass usage originally counted only validated envelopes and is labeled accordingly in public evidence.

Run `verify.py` to reproduce the retained aggregate reports offline, check the original frozen scorer/reference hashes, account for all 23 requests and verify each real request against the approved redacted-image derivatives. It makes no API calls.
