# P11-02 · Shared layout and readable settings

November 6–8, 2026. Approved in Main. Scope: audit findings U04 and U16, plus the bounded U13 correction-tool investigation. No splitting, recognition or money behavior changes.

## Changes

The long-paper review baseline reproduced a straight cut across the paper above the source-review switch. The paper ScrollView now uses the same unclipped soft vertical scroll-edge treatment as receipt detail/import. Its confirmation row uses a native bottom safe-area bar without the separate regularMaterial rectangle. The parent Save draft/Finish actions retain their existing shared styling and reserved safe area. The switch remains available; source review, reconciliation and finalization conditions are unchanged.

AI settings no longer presents a picker containing only one model. It displays the current supported model as a labeled value. A shared adaptive labeled-content style keeps normal-size values aligned and stacks label/value at accessibility text sizes; values wrap instead of truncating. Provider and last-check summaries use the same style. There is no provider/model/network behavior change.

At accessibility sizes, the original-comparison toolbar now puts Expand original below the three zoom controls. Screenshot inspection exposed clipping at the outer edges of the previous four-button row even though navigation assertions passed. Standard-size layout stays horizontal.

## Baseline test-driver findings

The existing focused-correction test scrolled downward while searching for Expand original after that earlier form cell had been virtualized away. The driver now returns toward the top before finding it. The long-review helper also queried an absent element's identifier before checking existence, causing XCTest to fail rather than scroll to the field. That order is corrected. Both baseline failures were observed in the initial local result bundles (temporary files were cleared before resuming on November 8); neither is labeled an app regression.

## Verification

Completed November 8: five distinct UI methods passed in `/tmp/sliplet-p1102-final.xcresult`: model identity, fictional connection consent/disconnect, accessibility correction/source access, clean review gating, and long-paper original/edit/finish/bottom reachability. The model method also passed on iPhone 13 mini with actual system accessibility-extra-extra-extra-large in `/tmp/sliplet-p1102-ax-final.xcresult`.

Final inspection exposed a preview-only sizing mismatch: the correction fixture enlarged its text without using that same size for layout decisions. The view now resolves one effective size for both. Its focused accessibility test passed again in `/tmp/sliplet-p1102-tools-verified.xcresult`; the final screenshot confirms all four controls are inside the form. The paper screenshot confirms a soft bottom transition, and the model screenshot shows the full name wrapping. Retained fictional screenshots are in [evidence/p11-02](evidence/p11-02).

These are scoped Simulator checks, not physical-phone acceptance, full VoiceOver evaluation or a latency benchmark. Fictional image transport is intercepted; no real receipts or API credentials are used. Device installation is outside this task. Preserve the unrelated existing Xcode launch-scheme edit.
