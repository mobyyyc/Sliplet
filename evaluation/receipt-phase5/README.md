# P5-06 exposed-set acceptance

This evaluation uses the five previously checked purchases, as explicitly requested. They are development data, not independent/held-out validation. Freeze production code, native probe and evaluator before preparing a new run. No production recognition changes are part of this milestone.

1. Create a disposable iPhone 15 Pro / iOS 27.0 Simulator named `Sliplet P5-06 Acceptance Lab`. Build the Sliplet scheme for testing into a dedicated build directory.
2. `run.py prepare --run PRIVATE_NEW_RUN --device DEVICE --build BUILD` stages original images and the already verified P4-02 literal transcripts. Semantic labels stay outside the app. The transcript path is a separate diagnostic, never an import input.
3. Run the generated `private.xctestrun` with only `ReceiptRecognitionLabTests/testExplicitPrivateSimulatorBaseline` and `ReceiptRegionExperimentTests/testExplicitCheckedTranscript`. Keep logs/results private, disable parallel tests.
4. After those complete, separately run `ReceiptAcceptanceLabTests/testPrivateSuggestedRegionCandidateCoverage`. It depends on the captured first imports. XCTest class ordering is not dependency ordering: combining all three runs the probe too early.
5. `run.py collect --run RUN`, then `run.py verify --run RUN`. Keep captures/labels/identities private. Only reviewed aggregates are publishable.

The probe rereads the same suggested source-box union and padding used by the focused editor, once per existing purchase line, using the production region reader and amount-choice conversion. It does not consume references, select/apply values, add lines or confirm review. It records unavailable/no-source cases as well as successful reads. The post-run evaluator pairs by unique kind/description or previously verified source region, never by amount; ambiguous/unpaired lines stay unscored. A correct candidate among several possibilities is potential evidence, not a correct user choice or finished receipt. Its scope excludes human-drawn regions and missing-row recovery.

Baseline comparison uses the accepted P4-04 app imports (before Phase 5); verify_details.py additionally compares all field values/source memberships with P5-05. Check full semantic captures independently, including raw observations and source membership, in addition to headline counts. Validate literal UTF-16 ranges and ROI containment of every candidate. Existing private files must remain byte-identical. Run focused fictional workflow checks separately for review/save/search/split/backup and rereading. Automated durations do not measure human correction effort.

The output may be negative. No gain or unmet completeness/held-out gates must be reported explicitly rather than promoting an accuracy release. Phone performance, peak memory and human correction time require separate evidence.

Run `python3 evaluation/receipt-phase5/verify_details.py PRIVATE_RUN` after collection for independent literal-range, region-containment and P5-05 field/source equality checks. Invoke run.py by its absolute path. No private values are printed.
