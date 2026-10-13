# P4-01 Simulator recognition lab

The hosted XCTest calls production `ReceiptWorkspace.importFile`, waits for editable review, captures unchanged Vision/parser output and field conversions, then saves/reopens the unedited draft in an isolated encrypted store with an ephemeral key. No labels reach the app. No production source or recognition setting is changed. The lab needs a dedicated Simulator named `Sliplet P4-01 Recognition Lab`; never stage it in a normal user device/container.

Build the shared Sliplet scheme with `build-for-testing`, explicit Xcode `DEVELOPER_DIR`, and a dedicated derived-data path. The test file is automatically included in the existing synchronized test group; no project/signing edits are required. The private test skips in ordinary runs and on physical devices.

1. Run the fictional protocol tests: `python3 -m unittest discover -s evaluation/receipt-lab -p 'test_*.py' -v`.
2. `python3 evaluation/receipt-lab/lab.py prepare --run private-receipts/evaluation/NEW-RUN --device TASK_DEVICE --build /tmp/sliplet-p401-build`.
3. Run `xcodebuild test-without-building -xctestrun PRIVATE_RUN/private.xctestrun -destination 'platform=iOS Simulator,id=TASK_DEVICE' -only-testing:SlipletTests/ReceiptRecognitionLabTests -parallel-testing-enabled NO -resultBundlePath PRIVATE_RUN/native.xcresult`. Redirect all stdout/stderr to the private run. Do not use XCTest parallel device clones.
4. `python3 evaluation/receipt-lab/lab.py collect --run PRIVATE_RUN` captures available attempts, including explicit first-attempt failures rather than silently shrinking denominators.
5. Run `lab.py verify --run PRIVATE_RUN` and `independent_verify.py --run PRIVATE_RUN`. The latter independently checks essential legacy counts, coverage, baseline incorrectness, conversion and storage; it is deliberately not described as a second complete v2 scorer.
6. Preserve private run evidence, then shut down/delete only the task-created device. Remove its input copies with that device. Never publish private results, screenshots, logs, paths, hashes or references.

Every run must be new. The manifest freezes original/label/app/test/source hashes, Simulator ID/runtime, nonce and input slots. Reference-v2 is a private versioned sidecar: the historical checked labels remain unchanged. Future user-reviewed annotations create another sidecar and run; never change a frozen run's references.

## Field/reference contract

Receipt fields: merchant, date, currency, subtotal and total. Purchase fields: kind, printed description, printed line amount, quantity, unit, unit price, SKU and tax marker. Adjustment fields: kind, printed label, amount and printed rate. Metadata carries stable reference-line identities, optional original regions and explicit line/summary completeness. Quantity, SKU, unit, unit price, tax markers, rates and printed currency from the older corpus remain unreviewed until specifically checked. Historical free-text quantity transcription is retained without silently normalizing it.

Each field has exactly one state: `printed_verified` (typed value), `not_printed_verified` (no value), `unreadable` (no value), or `unreviewed` (no value). Money uses integer minor units; zero is distinct from absence. Decimal quantities/rates use canonical decimal strings. Regions use original normalized Vision coordinates: origin at bottom left. A legacy null cannot establish that a field is not printed. Original regions are optional; without them, unique kind/description matching is a proxy and repeated identities remain ambiguous. Price is never used to resolve that ambiguity.

The private read-only `review.html` links each original and shows pending coverage/investigation. Main requests only specific gaps in ordinary language; the user checks them locally and Main records explicitly supplied annotations in a new sidecar with verification provenance. There is no requirement to complete all expanded labels to finish this bounded diagnostic milestone. An interactive region-annotation/re-recognition UI is outside P4-01; do not ask the user to edit JSON.

Full receipt verdict is incorrect when a verified discrepancy exists, indeterminate when no known discrepancy exists but evidence/coverage is incomplete, and correct only with full checked field/line coverage and no discrepancies. Legacy amount/reconciliation counters remain separate. Hypotheses use captured Swift grouped/interpreted rows; amount text anywhere on the page does not prove item association. Source-region annotation and checked-text/region experiments are P4-02 proposals, not performed here.

## Measurement limits

Hosted app import is the production Files-handler path; it does not measure picker interaction, camera capture or user correction seconds. First/repeat imports run in one process; neither is advertised as a controlled cold-cache benchmark. Timing has 20 ms polling resolution. Maximum main-actor polling gap is a coarse diagnostic, not a frame-rate/hitch benchmark. A 120-second watchdog is a test limit, not the desired product wait. Five exposed purchases have zero held-out validation.

`stable` removes generated IDs while preserving source membership, geometry, currency, quantities and all captured semantic fields. Original and parser outputs are immutable; labels are not installed or compiled. All runtime test logs/results are private. Public evidence is an explicit reviewed aggregate allowlist only.
