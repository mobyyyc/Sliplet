# P8-05 — Explicit image upload and coherent review

2026-10-30. Approved implementation milestone. P8-04 personal Gemini connection remains the prerequisite for AI; local reading remains available without a key.

## Import experience

Camera, Photos and Files converge on a recognition choice after local image decoding. Read on device invokes Apple Vision without an upload. Preview for Gemini requires a verified, enabled personal connection and independent provider-privacy acknowledgment. AI Settings is available from the choice screen.

The AI preparation screen renders the selected image locally. Draw mode adds opaque rectangular covers; Scroll mode lets long images move normally. The persistent bottom controls keep mode switching and Review upload reachable. Undo/reset and optional broad top/bottom covers support corrections without compulsory multi-crop steps. No automatic redaction is claimed. Names, quantities, weights and unit prices stay visible unless the user explicitly covers them.

Review upload displays the actual flattened JPEG. It names Google and the selected model, links data-use terms, discloses API allowance use, and requires a fresh per-image acknowledgment before Send. Editing covers clears acknowledgment. The original is never replaced by redaction. The provider does not receive OCR text, filenames, other receipts, labels or developer keys.

## Image and request boundary

`ReceiptUploadImage` uses ImageIO to bake source orientation, preserves the entire aspect ratio, limits the long side to 1600 pixels, paints covers into RGB pixels, and creates a new JPEG at quality 0.95. No source metadata dictionaries are copied. JPEG encoding may generate harmless dimension properties. The prepared in-memory bytes are both displayed and base64-encoded into the request; no separate hidden full-resolution image is sent. No temporary image file or Files API upload is used. Long narrow receipts may lose legibility at this size: inspect the preview and use a clearer image or on-device/manual reading if needed. This change does not claim new accuracy on long unseen receipts.

`GeminiReceiptTransport` embeds the previously evaluated structured prompt/schema, uses the approved `gemini-3.6-flash` model, 6500 output-token bound and low thinking setting. It has an ephemeral, cache/cookie/credential-store-free session, refuses redirects, caps input JPEGs at 8 MB and responses at 256 KiB, and makes one explicit request with no automatic retry or provider fallback. The request timeout is 120 seconds; the resource bound is 150 seconds. The native adapter rejects incomplete/unsupported output and treats model text as data.

Keychain is read again at send time and the credential identity must match the verified connection. Permanent access/key/model failures invalidate readiness. Provider details and raw error bodies are not displayed or logged. Keys are not added to receipt storage or backups. The raw successful response remains local encrypted evidence through the existing adapter/store.

## Recovery and review

Progress distinguishes local reading from Gemini. Cancelling an AI request stops waiting and retains the original; the screen explains that Google may already have received the image. Failures offer local reading, manual entry or a new preview (and new explicit send). No failed request silently resends. Backgrounding follows the app's existing policy: cancel work, clear unsaved state and protect the wallet. A late reply cannot overwrite the next import or edits.

The same receipt editor handles both sources. Original review is not checked automatically. CAD is a visible editable default when no currency was recognized; the original recognized currency remains absent. Finish still requires source review and exact reconciliation. Save draft/save/reopen keeps the original image and model evidence.

## Validation scope

37 native checks and one fictional UI walkthrough passed. The Release Simulator build also succeeded. One optional private replay test skipped because its fixture was absent.

Focused native tests exercise orientation, removal of source metadata, opaque redaction pixels, undo from original, long-image aspect ratio, invalid rectangles, byte-for-byte preview/request identity, request bounds, safe errors/no retry, preparation without upload, explicit fictional send, cancellation, background/disabled gates, original preservation, CAD provenance and review gates. Existing model/connection/transport regression checks are included. The isolated UI walkthrough uses only fictional data and intercepts networking with URLProtocol; it does not call Google.

No live provider requests or actual receipt uploads were made for this milestone. No new >95% accuracy measurement, physical-phone check, latency guarantee or human correction-time measurement is claimed. The previous 65/66 result remains a post-hoc saved-response result on five exposed receipts, not new end-to-end validation. P8-06 audits reliability/device readiness; P8-07 owns final acceptance.

## Primary sources checked

- [Google API terms](https://ai.google.dev/gemini-api/terms), checked 2026-10-30: unpaid-service data use and potential human review; no sensitive/personal information should be submitted. The app does not claim a free-tier privacy exemption.
- [Gemini image input documentation](https://ai.google.dev/gemini-api/docs/image-understanding), checked 2026-10-30: inline image input. This implementation keeps the already evaluated model and does not automatically adopt newer examples/models.
