# P7-08 workflow verification

No production changes. Build the current Sliplet scheme for testing into `/tmp/sliplet-p708-build`. Create and boot a dedicated iPhone 15 Pro / iOS 27.0 Simulator named `Sliplet P7-08 Workflow Lab`; save its identifier in `/tmp/sliplet-p708-device`. Never use or reset a normal wallet device.

Compile `evaluation/receipt-independent-ocr/ParseWorker.swift` with the domain dependencies described in `docs/PHASE7_REPRODUCTION.md`. Use the parser from commit `abf4c2a` for `/tmp/sliplet-p708-before`, and current production for `/tmp/sliplet-p708-after`. Keep the baseline source in `/tmp/sliplet-p708-before.swift`.

`run.py prepare` stages five originals with hashes, never references, and writes a private xctestrun. It enables only the ordinary native import lab and explicitly disables adaptive extra reading. Run `ReceiptRecognitionLabTests/testExplicitPrivateSimulatorBaseline` plus the scoped correction, focused-guidance and currency-context test classes. The private test invokes the same workspace import entry point as Files, saves drafts, suspends/reopens the store and verifies fields, original bytes and source evidence.

`run.py collect` captures ten runs and compares both parser versions on identical OCR, using frozen `p7-05-final/reference-v3.json`. `run.py verify` independently replays the captured evidence without the Simulator. Use the `T05Workflow` scheme with Simulator ad-hoc signing (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`) for UI tests; unsigned UI fixtures cannot access their Keychain-backed test wallet. Run fictional UI correction tests separately for cancel/apply, source comparison, explicit Finish and draft reopen. UI tests do not use private receipt images.

Preserve native/UI result bundles and extract actual executed/pass/fail/skip counts. Report observed import-to-review timing and main-actor polling gaps as Simulator diagnostics, not phone timings or frame-rate measurements. These checks do not time a human reviewing receipts or measure native Files-picker taps.

Private evidence stays under `private-receipts/evaluation/p7-08-final`; public output contains only aggregates. Completed output directories are not overwritten. Clean up only the task-created Simulator after collection.
