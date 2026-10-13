# P4-02 private reading experiments

No production changes. Run only on a dedicated Simulator named `Sliplet P4-02 Recognition Lab`. Never use a normal app container. Originals and results stay under ignored `private-receipts/`; no receipt contents in stdout, commits or screenshots.

1. Build the shared Sliplet scheme for testing into a dedicated derived-data directory with explicit Xcode `DEVELOPER_DIR`.
2. Run `python3 -m unittest discover -s evaluation/receipt-regions -p 'test_*.py'`.
3. `experiment.py prepare --run PRIVATE_NEW_RUN --device DEVICE --build BUILD` freezes original/reference/source/build identity and installs only images plus a label-free request.
4. Run the generated `private.xctestrun`, selecting `SlipletTests/ReceiptRegionExperimentTests` with parallel testing disabled. Redirect logs and result bundle to the private run.
5. `experiment.py collect --run RUN`, then `experiment.py verify --run RUN`. Collect prints aggregate counters only. Failed/absent attempts remain explicit. Do not edit source after the frozen capture and claim it verified that source.
6. `annotation.py --output PRIVATE_NEW_REVIEW` prepares source checking. Keep literal text and geometry, not normalized semantic-label reconstructions. All confirmations start unchecked. Never promote assistant-generated text into human-verified input.
7. Once the user exports checked work, `assisted.py --run RUN --export EXPORTED_JSON --review REVIEW` validates identity and stages separate assisted requests. Use `assisted.xctestrun` and select only `testExplicitCheckedTranscript` and `testExplicitVerifiedRegions`; keep new logs/results separate. Independently score assisted captures without adding their inputs to automatic accuracy.

A new export needs a new evidence context; do not overwrite frozen assistance. Regional output coordinates are gated by eight fictional orientation cases on the installed runtime. All candidate sets and original observations remain retained. The current center-based strip merge is experimental and has measured regressions. No confidence-based or answer-guided acceptance is deployed.

The current five purchases are exposed development data, never held-out validation. Checked currency absence, item attributes and rates remain unknown until independently reviewed. A user-selected CAD default is context and cannot establish printed-currency OCR accuracy.
