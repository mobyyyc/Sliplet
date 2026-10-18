# P6-02 isolated total-reading experiment

Rules fixed before private results: unchanged production parser; one unique detected total label; full-width source strip centered on its label box, height max(5 label heights, 0.04 image height); original and CIColorInvert views of exactly the same pixel-rounded strip; accurate Vision, language correction disabled. No answer labels, reference amounts, per-receipt coordinates or sum matching in the probe.

Read both modes twice, reversing order on the second pass. Existing totals are preserved. Missing totals with existing sign/conflicting-summary evidence remain unresolved. Otherwise propose a total only when both unchanged-parser crop results agree and neither has summary-conflict issues. Keep source observations and mapping; an empty or ambiguous result fails closed. These rules are an experiment, not a production feature or proof of general safety.

The three fictional native methods test decision/sign preservation, unique-label/full-width geometry and actual Vision on positive, leading/trailing-negative, missing and competing light-on-dark amounts. Run before the private probe. The private method is opt-in and writes only private files.

1. Create disposable iPhone 15 Pro / iOS 27.0 Simulator `Sliplet P6-02 Total Lab`; build Sliplet for testing with `ReceiptTotalProbeTests` included.
2. Invoke this directory's run.py by absolute path with `prepare --run PRIVATE_NEW_RUN --device ID --build BUILD`. It stages originals and a checked-text diagnostic separately; the total probe does not read transcripts or semantic labels.
3. Run generated private.xctestrun with `ReceiptRecognitionLabTests/testExplicitPrivateSimulatorBaseline` and `ReceiptRegionExperimentTests/testExplicitCheckedTranscript`, parallel testing disabled. Preserve logs privately.
4. Only after captures exist, run `ReceiptTotalProbeTests/testPrivateTotalProbe` separately. Never rely on XCTest class ordering.
5. `collect --run RUN`, then `verify --run RUN`. Collection stdout includes aggregates only, but redirect it privately until reviewed. Publish safe selected counts and boolean outcomes, never captures.

Gate: at least one automatic proposed total recovery over the existing 3/5, with no lost correct total or new wrong total and all other baseline fields/source memberships unchanged. This evaluates proposed substitution, not an integrated draft save/reopen; P6-03 would have to prove integration separately. Both passes must agree. Failure stops the implementation sequence. A successful fictional fixture is not a private-receipt recovery. Five exposed receipts, zero held out.
