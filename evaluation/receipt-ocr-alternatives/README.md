# P7-07 bounded OCR alternatives experiment

Predeclared before reading candidate outputs: accurate Apple Vision with production languages and language correction off; retain up to five candidates per observation instead of one. Run two independent passes over all five original images on an isolated Simulator. No expected text, amounts or human regions enter the recognizer.

Per full-image pass, derive at most eight tight full-width row bands from OCR geometry. Prioritize total-label rows, then rows named by unpriced/ambiguous amount parser issues, then low-confidence observations (<0.8). Sort ties by original reading order. Band height = three times observed row height, minimum 0.012, clipped to image. Recognize original pixels only, no inversion, no resizing, no sign changes. Retain all five alternatives, timing and original-coordinate mapping. This differs from prior broad summary crops and tests candidate availability, not validated selection.

Availability checks occur only after output capture, using frozen P7-05 references and verified source regions. A correct candidate among alternatives is not a correct automatic output. Never choose by expected values, matching totals or human coordinates. A production change requires a label-independent selection rule, negative sign/ambiguity tests and no loss of correct fields. If no safe measured improvement exists, preserve production unchanged and report the failed gate. No model installation, Apple Intelligence or cloud.

Execution note: the first private run completed two passes before failing. Retain it separately. Retry with a 30-second per-request harness ceiling (originally 8 seconds) and numeric error diagnostics; this is not an app latency budget or a change to candidate selection.

The second attempt identified an invalid Vision bounding box, not a demonstrated timeout. The final harness retains unmappable raw boxes/candidates separately and excludes them from parsed readings; it no longer aborts the entire run. Both failed attempts are retained. No answer-driven crop or text-selection changes.

A completed rendered-full-image run scored 56/65 rather than the retained production 57/65. Preserve it as a rendering diagnostic. The final run uses the exact production ImageIO decode/orientation path for full-image OCR; only regional rereads render cropped original pixels. Candidate counts and selection rules remain unchanged.
