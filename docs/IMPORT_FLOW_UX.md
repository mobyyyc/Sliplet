# Guided receipt import

November 3, 2026. Approved priority UX work while P10-05 physical-device acceptance remains pending.

## Flow

Camera, Photos and Files enter the same preparation flow:

1. Check photo: inspect the capture, rotate or reset, or enter explicit Crop mode. Apply crop returns to the same check screen. Camera captures enter this page directly, with Retake available; there is no separate camera confirmation page.
2. Choose reading method: On-device or AI reading. AI connection setup opens in place.
3. AI only: hide sensitive details using drawn, movable and resizable rectangles, with Undo and Delete.
4. AI only: confirm the upload using a compact, expandable preview of the exact flattened payload, provider summary and per-upload consent.
5. Reading leads to the existing receipt review and save process.

Each preparation step has a persistent progress strip labeled Photo, Method, Privacy and Upload, with the current page title below. The AI-specific segments appear when AI is selected. Primary actions occupy a consistent bottom bar. Forward/back navigation slides horizontally; Reduce Motion substitutes a fade. Photo guidance, reading-method explanations, privacy guidance and upload data-use information are visible by default. Copy is concise and grouped under clear headings. Fixed top/bottom percentage cover controls are removed. The Original viewer remains available during preparation without replacing the prepared image. The reading screen shows an animated system progress indicator, status and relevant explanatory text; its only action is cancellation.

Back preserves edits. Changing crop/rotation clears incompatible covers. Returning to consent clears acknowledgment. An interrupted upload returns to its existing covers and requires a new confirmation. There are no automatic uploads or retries. Setup and expanded-image sheets retain session state. Leaving an in-flight preparation cancels it and rejects stale completions.

## Image and source integrity

The original asset remains unchanged and is saved using the existing encrypted store. Crop/rotation operates on a separate image, normalized for source orientation. Local OCR parses the adjusted image; its source boxes and optional reading-pass evidence are mapped back into the original oriented coordinate space before saving. Original source IDs and parser bytes are retained. The AI transport receives only the reviewed prepared payload after covers are flattened and metadata is stripped.

Transform work is off the main actor, bounded to a 4096-pixel long edge when an adjustment is applied. Display previews are limited to 1600 pixels. Existing AI payload limits remain unchanged. Image edits are static; screen transitions do not reprocess pixels each animation frame.

## Verification

Native upload suite: 21 tests passed. This includes crop/rotation dimensions, inverse coordinate mapping, preservation of original bytes and source IDs, reading-evidence consistency, metadata removal, flattened covers, transport payload identity, cancellation and failure recovery.

Simulator walkthroughs use fictional photos and an intercepted transport, with no provider requests. Coverage includes the AI path and consent reset, Original-sheet return, offline recovery, large text, and rotation/reset/back navigation followed by actual local Vision reading. The large-text run initially found an editor-tool overlap; responsive canvas sizing and compact tool labels resolved it. Final cover Undo and expandable-preview checks are included in the AI walkthrough. Light and dark screenshots were inspected.

Simulator results do not establish physical-phone gesture feel or camera acceptance. No phone installation is part of this change. P10-05 remains open.


## Phone-feedback refinement

The owner installed the initial redesign and requested a combined photo check/editor, explicit Crop action, visible guidance and named progress segments. Crop mode now fits the whole photo inside a larger charcoal canvas with 32-point surrounding space at its initial zoom, white right-angle guides and 44-point corner targets. The enlarged image hit area makes the outside portion of each guide draggable. Check mode has no crop overlay. Retake from the shared check screen opens the camera, and cancelling a retake leaves the existing import available.

The camera-specific confirmation UI was removed. Capture still does not trigger recognition or upload: the user continues from Check photo and explicitly chooses a reading method. Existing source-image and consent protections remain in place. The loading screen exposes status and explanation directly and removes unrelated navigation controls.

Refinement verification: seven focused Simulator UI tests passed across light, dark and accessibility text configurations. Coverage includes explicit crop entry, inset handle dragging, Apply and Back, local reading, AI consent and cover Undo, camera retake/save/reopen, discard/background cancellation, and visible reading status with Stop. Final copy and Crop-mode Back changes were rechecked. Crop and loading screenshots were inspected. Physical camera quality and device gesture feel still require the next phone check.
