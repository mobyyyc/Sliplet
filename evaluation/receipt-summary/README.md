# P5-02 summary recognition evaluation

Use only a disposable Simulator named `Sliplet P5-02 Summary Lab`. This runner reuses the production Files-import test and two checked-text replays; reference labels never enter automatic recognition. Retains five exposed purchases, zero held-out purchases.

Build the Sliplet scheme for testing with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, a dedicated derived-data folder and this device. Boot the device before preparation. Do not modify sources after preparation: manifests bind code, binaries, originals and references to each run.

```sh
python3 evaluation/receipt-summary/run.py prepare --run private-receipts/evaluation/NEW-RUN --device TASK-UUID --build /tmp/sliplet-p502-build
# Run the generated private.xctestrun, parallel testing disabled, with only:
# SlipletTests/ReceiptRecognitionLabTests/testExplicitPrivateSimulatorBaseline
# SlipletTests/ReceiptRegionExperimentTests/testExplicitCheckedTranscript
# Keep the log and xcresult in NEW-RUN, never print raw private output.
python3 evaluation/receipt-summary/run.py collect --run private-receipts/evaluation/NEW-RUN
python3 evaluation/receipt-summary/run.py verify --run private-receipts/evaluation/NEW-RUN
```

`p502-aggregate.json` includes the inherited P4-02 comparison plus a separate P4-06 comparison; use the latter to assess this task. Legacy counters use amount-preferred duplicate matching; strict structured pairs never use amounts to resolve identity. Neither is OCR character accuracy. Unmatched output proxies are not proven invented purchases. Raw-observation IDs change on import; `same_raw_text_geometry` is the meaningful reading comparison.

Archive failed/intermediate runs rather than overwriting them. After collecting and verifying final captures, shut down/delete only the dedicated test device. Do not update a normal Simulator wallet or physical phone as part of this evaluation.
