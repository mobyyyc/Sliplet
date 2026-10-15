# P4-03 adaptive import validation

The production default remains one read. This harness explicitly opts the real import handler into the bounded adaptive engine on a task-created Simulator named `Sliplet P4-03 Field Lab`. It never installs into a user wallet.

Build for testing using a dedicated derived-data directory and explicit Xcode developer directory. Run `run.py prepare --run PRIVATE_NEW_RUN --device DEVICE --build BUILD`; run the private.xctestrun with only `SlipletTests/ReceiptRecognitionLabTests/testExplicitPrivateSimulatorBaseline`, parallel testing disabled. Run `run.py collect --run RUN` and `run.py verify --run RUN`. Keep logs and result bundles private. Do not reuse a frozen run after source changes.

Five exposed original images run twice through import, review conversion, encrypted draft save and reload. Check selected-pass source membership and parser replay, retained baseline observations against P4-04, unchanged originals, repeated semantics and no lost correct fields or currency. Report second-pass outcomes and end-to-end Simulator timing separately from accuracy. A cooperative Vision cancellation request cannot guarantee exact wall-clock return; results exceeding the retry acceptance deadline must be discarded.

The strict selector requires concrete additions while preserving all known fields, numeric and currency syntax, line multiplicity, metadata and source locations. No answer labels, matching-total search, automatic cropping or cross-pass merging. Private references do not enter the app. Zero held-out purchases and no phone timings; no gain means no automatic promotion.
