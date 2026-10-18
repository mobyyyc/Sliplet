# P6-02B isolated anchored-total experiment

Fixed before private results: reuse the P6-02 crop/render/OCR settings, but retain the original total label as the semantic anchor. No production code is changed. No semantic answer labels, expected amounts or manually measured receipt coordinates enter the probe.

Policy:
- Preserve an existing total. Abstain on baseline sign or summary conflicts.
- Require one original total label with geometry. An amount observation must lie to its right, within 1.5 maximum text heights vertically, and closer to it than to another original summary/payment/tax label.
- Each read must provide exactly one aligned numeric observation. Reject aligned signs/parentheses, multiple amounts and conflicting digits. Keep full-width crop margins.
- Require equal digits across original and inverted views and at least one complete, literal money token. Any other corroboration must be digits/whitespace only: do not ignore a malformed separator, insert a decimal, strip a sign or calculate an amount. If both are valid money tokens their values must agree.
- Retain original label ID and both reread observation IDs. The output is a proposed total, never a changed/saved production draft.

Read each mode twice, reversing order. Safety tests include nearby tax amounts, amounts left of the label, competing numbers, detached/trailing signs, malformed decimals, original conflicts, and actual fictional light-on-dark images. Same-image repeated agreement is not independent general validation.

Create a disposable iPhone 15 Pro / iOS 27.0 Simulator named `Sliplet P6-02B Total Lab`. Build Sliplet for testing including `ReceiptAnchoredTotalProbeTests`. Run its three non-private tests first. Invoke run.py by absolute path:
1. `prepare --run PRIVATE_NEW_RUN --device ID --build BUILD`
2. Generated private.xctestrun: run `ReceiptRecognitionLabTests/testExplicitPrivateSimulatorBaseline` and `ReceiptRegionExperimentTests/testExplicitCheckedTranscript` first, parallel testing disabled.
3. After imports complete, separately run `ReceiptAnchoredTotalProbeTests/testPrivateTotalProbe`.
4. `collect --run RUN`, redirect stdout until reviewed; then `verify --run RUN`.

Semantic references remain in the evaluator. The probe does not read staged checked transcripts. The evaluator requires identical baseline field/source memberships with P5-06, repeated proposed values, mapped coordinates, literal support for recoveries, at least one newly correct total, and zero lost correct/new wrong totals. Acceptance is at least 4/5 on these five exposed purchases, not independent accuracy or completed app integration. P6-03 still requires separate approval and actual app-flow evidence. Failure stops implementation.
