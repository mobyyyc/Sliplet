# P11-03 · Navigation, gestures and responsiveness

November 8, 2026. Approved in Main. Fictional isolated Simulator fixtures only.

## Result and scope

Investigated wallet/detail return, opposing swipe actions, search/history return, keyboard-driven edits, discard confirmation and Reduce Motion. No production transition change is justified by the reproduced paths. The accepted paper/wallet appearance and navigation remain intact. This task improves regression coverage and fixes misleading performance instrumentation rather than inventing an animation defect.

## Findings

- Repeated detail visits in 13- and 30-receipt wallets preserve the selected paper's screen position. Pixel-text checks confirm only the selected merchant appears in detail, including after scrolling. A visit to the newest receipt preserves the scrolled wallet position on return.
- One-, two- and three-receipt stacks return tucked into the wallet without a corrective swipe; wallet position stays stable and discarded-draft text does not appear.
- Reverse swipe closes the existing action before a new swipe opens the opposite one. The disabled-opposite-action test initially failed before exercising the gesture: its settings row was virtualized below the viewport. The test now scrolls to that existing row.
- A real edit clears source confirmation, disables Finish and requires explicit discard. Search → history → receipt → back preserves the query at large text size with Reduce Motion.
- Added a dedicated Reduce Motion journey that opens the newest receipt in a 30-receipt wallet, returns to the same position and reverses a revealed action.

## Performance measurement limits

The prior XCTest hitch metric produced no useful measurements. An explicit Animation Hitches trace now explains why: Instruments reports `Hitches is not supported on this platform.` The Simulator test is renamed to `testCrowdedWalletRoundTripResourceBaseline` and uses CPU and clock metrics instead. Clock samples include XCTest taps, idle waits and assertions; they are not animation duration, frame rate or user-perceived latency. CPU measurements describe the Simulator process, not the physical phone.

A separate scoped Time Profiler attempt produced CPU samples, but captured only 5.34 seconds of an edit/discard journey before the process exited. It is not a wallet-transition profile and is not used to justify optimization. Its missing-input-source warning is retained locally. Do not claim zero lag or a successful frame/hitch benchmark from these runs. Hardware animation tracing remains part of P11-08 acceptance.

## Verification

Eight current scenarios have passing outcomes across two scoped runs: search/history return, edit/discard, ordinary reverse swipe, disabled-opposite reverse swipe, repeated selected-only detail/return, short tucked stacks, resource baseline, and Reduce Motion scrolled return. The initial run also passed the old hitch test functionally, but supplied no usable hitch metric; it is replaced, not counted as additional performance evidence. The one initial offscreen-setting harness failure is retained in the baseline bundle; the corrected method passes in the final bundle.

The new baseline exported three measurements: average Simulator app CPU time 0.436 seconds and average automated round trip 1.781 seconds (including automation waits). No prior baseline exists, and no speedup is claimed. See [retained fictional screenshots and metrics](evidence/p11-03/README.md). Final screenshot inspection confirms the settled stack is tucked into the wallet and the newest detail shows only its own paper. No production files changed. No phone installation or real-receipt upload is included.
