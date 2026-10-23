# P7-07 — bounded on-device OCR alternatives

Completed 2026-10-23. The experiment failed its improvement gate; production recognition remains unchanged.

## Result

Two fresh native Simulator passes over five original receipts reproduced **57/65 exact purchase pairs (87.7%)**, with **3/5 totals correct**. Each pass contained 331 full-image observations. Although the request asked for up to five text candidates, every retained full-image and regional observation returned only one. There were no alternative strings to select.

The source-derived selection policy ran eight tight row rereads per receipt, 80 across both passes. No single regional substitution recovered another exact purchase or total, even when checked labels were used afterward to measure availability. Fourteen substitutions lost previously correct purchase pairs. These are offline diagnostics, not runtime selections or automatic gains. No retry or selector is promoted to the app.

Coverage matters: automatic row bands covered three of the eight failed purchase-row anchors. The other five had no useful uncertainty trigger under the bounded policy. This experiment does not establish that all remaining errors are irrecoverable, that all crops fail, or that no different on-device model could help. It demonstrates failure of this specific candidate/region policy on the five exposed receipts. Zero held-out data.

## Method and controls

Full-image OCR uses production ImageIO decoding, EXIF orientation, accurate Vision recognition, production supported languages and language correction disabled. Only the requested maximum candidate count changes. Region selection sees original OCR and parser issues, never expected values or human regions. Priority: total labels, unpriced/ambiguous amount issues, then confidence below 0.8; maximum eight regions. Ties follow source order. Full-width bands are three observed row heights, minimum 0.012 of image height, clipped to image edges. Original pixels are cropped without inversion or rescaling.

Region readings preserve geometry in original-image coordinates. Ten invalid regional observations per pass are retained separately rather than admitted to parsing or aborting the whole diagnostic. Native test execution and the fictional region-selection test both passed (two tests, no skips). All ten captures, source hashes, original mapping and repeated candidate/region results verified.

The final native baseline matches P7-06 accuracy. Initial failures and an intermediate rendered-full-image run are preserved privately. The rendered baseline measured 56/65, so it was not used for final comparisons. The corrected full-image path reproduced 57/65. A longer test-only request ceiling was introduced during diagnosis; the confirmed failure was invalid geometry, not a demonstrated timeout. Final individual OCR reads were under one second on this Simulator; roughly 0.30 seconds median per read. These are test-harness read timings, not phone latency or end-to-end import performance.

## Interpretation and next task

Repeated OCR does not reliably identify confidently misread text. A larger requested candidate count is not useful when Vision supplies no additional alternatives. Correcting missing digits/signs from totals or payment values remains disallowed. Removing printed product suffixes to match labels would change the task rather than improve OCR.

P7-08 should verify the proven P7-06 weighted-item change through actual import, review and save/reopen. There is no P7-07 recovery candidate to integrate. This verification is not expected to lift accuracy above 57/65 and must not be described as the remaining path to 90%. Record the unresolved cases and offer existing focused user correction when automatic evidence is insufficient. Additional model evaluation or a new assisted crop experiment requires an explicitly revised hypothesis and approval; do not extend this failed experiment indefinitely.

P7-09 acceptance still requires at least 59/65 and separate total/subtotal/no-regression gates. Those gates have not been met. Report a partial Phase 7 outcome if final verification remains below them.

## Reproduction

Use `ReceiptOCRAlternativeTests` in a dedicated Simulator. Build-for-testing, boot/install the isolated host, then `evaluation/receipt-ocr-alternatives/run.py prepare`. Run the generated private xctestrun with the explicit private environment, followed by `collect`, `analyze.py` and `verify.py`. The runner currently records the task's dedicated device identifier; create a new named device and update it before reproducing after cleanup. Use a new private output directory; never overwrite completed evidence.

The current production ParseWorker must be compiled to `/tmp/sliplet-p706-parse` for scoring. Recognition receives only image filenames and hashes. References, expected text, prices and manual coordinates never enter the app. Private outputs stay under `private-receipts/evaluation/p7-07-final`; safe aggregates are in `docs/evidence/p7-07/aggregate.json`.
