# P5-03 purchase assembly evaluation

Uses a disposable Simulator named `Sliplet P5-03 Purchase Lab` and the existing Files-import and checked-transcript tests. Five exposed purchases, zero held-out purchases. Freeze production and test sources before preparation; never overwrite a run.

```sh
# Boot the dedicated device and build Sliplet for testing in a separate derived-data folder.
python3 evaluation/receipt-purchases/run.py prepare --run private-receipts/evaluation/NEW-RUN --device TASK-UUID --build /tmp/sliplet-p503-build
# Execute NEW-RUN/private.xctestrun with parallel testing disabled, selecting only:
# SlipletTests/ReceiptRecognitionLabTests/testExplicitPrivateSimulatorBaseline
# SlipletTests/ReceiptRegionExperimentTests/testExplicitCheckedTranscript
# Keep logs/xcresults in the private run.
python3 evaluation/receipt-purchases/run.py collect --run private-receipts/evaluation/NEW-RUN
python3 evaluation/receipt-purchases/run.py verify --run private-receipts/evaluation/NEW-RUN
```

The runner validates all ten imports, two checked-text replays, original/reference/source hashes, stable repeat pairs, and five encrypted draft save/reopen results. The `p502_comparison` counters compare with accepted P5-02; inherited counters also compare with older P4-02 evidence. Strict field identities do not use amounts as a tie-break. Legacy amount-preferred duplicate counts are a separate historical metric. Unmatched proxies are not proven inventions.

Automatic recognition receives only original images. Checked literal text is an explicitly separate parser diagnostic, never input to normal imports. Old labels and receipts remain immutable. Delete only the task-created device after collecting and verifying results. No physical phone update or normal wallet modification is authorized by this procedure.
