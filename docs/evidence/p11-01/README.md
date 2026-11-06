# P11-01 evidence · fictional data only

Audit baseline: app source at `1b793bb` (production behavior unchanged from the prior import milestone). Screenshots are reduced-size copies for review; full PNGs and accessibility trees remain in the local result bundles. Images contain only generated fixtures. No API calls or owner receipts were used.

## Selected visual evidence

| Screenshot | Finding |
| --- | --- |
| [Search first screen](P11-light-search-large.png) | U05: filters consume much of the result viewport. |
| [Large-text split](P11-large-dark-split.png) | U01-U03: explanation precedes participant creation and item assignment. |
| [Row details](P11-row-details.png) | U06/U13: history is reachable, but the surface mixes viewing with correction tools. |
| [Match actions](P11-match-actions.png) | U07/U08: match actions follow two full purchase sections. |
| [Reread first screen](P11-reread-top.png) | U13: fixed photo/tool area; investigate compact/large text before changing. |
| [Identical amount choices](P405-fictional-reading-choice.png) | U15: two displayed 1.00 candidates need clearer provenance presentation. |
| [AI setup](P11-light-ai-settings.png) | U09: setup and explanations compete for attention. |
| [Backup mismatch](P11-backup-mismatch-keyboard.png) | U11: mismatching fictional passwords disable the action without a specific explanation. Secure values are not visible in the capture; hardware-keyboard configuration means this is not an onscreen-keyboard coverage claim. |
| [System accessibility model label](P11-system-accessibility-model.png) | U16: actual system text sizing truncates the model identity; this is not merely a preview-flag result. |

## Local reproducible results

- `/tmp/sliplet-p1101-audit.xcresult`: 10 methods executed; 9 passed and one inventory-harness failure (offscreen query), corrected subsequently.
- `/tmp/sliplet-p1101-followup.xcresult`: 4 methods passed, including the corrected inventory, price/history screenshots, utility screenshots and camera alternatives.
- `/tmp/sliplet-p1101-compact.xcresult`: 5 methods passed on an isolated iPhone 13 mini; 2 inventory repeats and 3 wallet scenarios.
- `/tmp/sliplet-p1101-system-ax.xcresult`: additional nested-screen capture using actual system accessibility-extra-extra-extra-large, not only preview flags. One inventory method passed; final screenshots inspected November 6. The model label truncation is recorded as U16.
- `/tmp/sliplet-p1101-metrics.json`: empty exported metric list. Do not infer a numerical performance result from the hitch test name.

The audit harness is `SlipletUITests/Phase11AuditUITests.swift`. It captures current behavior; its assertion that unnamed Add person is disabled records the old baseline and must be revised with P11-05. Use scheme T05Workflow, isolated fictional preview stores and the exact selected method names. Wallet methods belong to WalletInteractionTests, not the other test classes in ReceiptUIWorkflowTests.swift. Native test result bundles are not committed.

Run paths may be cleaned by the OS. The selected screenshots and source-level findings are retained here. Phone acceptance and VoiceOver speech remain distinct from Simulator evidence.
