# P4-05 — Targeted help in review

2026-10-16. Explicit, on-device assistance in the focused correction editor. Automatic imports still use the existing single read; P4-03 automatic promotion remains disabled.

## User flow

Open a Check first correction and choose **Reread an area**. The original photo opens with a suggested region based on that check's source observations. Select area allows a one-finger rectangle; two fingers pan and pinch zooms. Zoom controls and labeled precision sliders provide alternatives. The original bytes are never cropped or replaced.

Choose **Read selected area**, compare the photo and retained text, then select a literal reading for the desired field. No candidate is preselected. Each row shows both the exact token and the proposed value, which matters when, for example, a whole-number token and a decimal amount normalize to the same value. **Use reading** changes only the focused editor's working copy. Its outer **Apply / Cancel** still commits or discards the edit. Date assistance also updates the native date selector. Full source review and exact reconciliation remain required to finish.

Supported targets are merchant, year-first date, item/adjustment description, quantity, line amount, subtotal and total. The current check determines the offered targets. Existing line selection or Add purchase remains necessary for a missing item; rereading cannot silently append items. Ambiguous date order, rate/unit tokens and unclear monetary syntax remain manual corrections. Currency is explicit user context, never inferred from a reread amount.

## Evidence and boundaries

One accurate Vision text request reads the selected region with language correction enabled and the existing supported language list. It preserves EXIF orientation and maps ROI-local boxes once into oriented original coordinates. Boundary-crossing observations are omitted without discarding fully contained rows. Drawing accounts for the pan-recognition threshold when locating the initial touch. A three-second acceptance budget discards late results and requests cooperative cancellation; it is not a guaranteed wall-clock return deadline. Changing the region, closing, locking or changing sessions cancels pending work and prevents stale publication.

An accepted event retains the original asset digest, selected region, OCR revision, observations, exact UTF-16 token range, previous value, target and currency context. Events live inside the encrypted draft review input and survive encrypted save/reopen and password backup/merge. Original OCR, parser output and existing source IDs remain unchanged. Later manual edits or deleted lines do not rewrite historical evidence. Validation rejects wrong-image evidence, invalid geometry/tokens, duplicate IDs and oversized histories. Limits: 32 events, 128 observations per event and 256 KiB of retained history text. On failure the working copy is unchanged and manual entry remains available.

## Validation and limits

Final native run on Xcode 27.1 / iOS 27.0: 94 methods executed, 93 passed, one hardware-only skip, zero failures. This includes the clipped-boundary regression and all eight EXIF orientations. Both final Simulator UI methods passed on Xcode 27 / iOS 27.0 after the boundary fix; their fictional light/dark screenshots were inspected. The intervening Xcode update initially blocked the final native rerun until first-launch setup completed; that infrastructure failure did not execute tests. See [validation record](evidence/p4-05/validation.json) for source fingerprints. Native tests cover exact literal conversion, transactional edits, malformed evidence, legacy decoding, persistence/backup and all eight EXIF orientations with real Vision. Focused Simulator UI checks exercise actual region reading, explicit selection, nested cancellation, Apply and independent review gates. Fictional fixtures are used throughout.

Early UI attempts exposed an offscreen lazy Form row in the test driver and an actual missing full-row hit target. The driver now scrolls to candidates; candidate rows now accept taps throughout their bounds. The drawing check also exposed boundary-crossing OCR observations; these are now omitted while valid contained rows remain available. All 4,211 preexisting private/signing files remain byte-identical. No private receipt text or images are included in public evidence.

This task does not establish an accuracy improvement on real receipts, a reduction in human correction time, phone latency, VoiceOver acceptance or complete large-text usability. Existing five receipts remain exposed development data; zero held-out purchases were evaluated. No phone or normal Simulator wallet update was performed.

## Next proposed task

P4-06 requires separate approval: freeze the candidate, compare automatic and assisted recognition, and exercise review/save/search/split/backup through the Simulator. Untouched purchases are needed for genuinely independent accuracy claims. If none are supplied, report the existing development set separately and leave the held-out gate unmet. Human correction effort must be measured separately from automated test duration.
