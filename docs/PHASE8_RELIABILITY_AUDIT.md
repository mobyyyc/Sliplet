# P8-06 — Reliability, privacy and device-readiness audit

2026-10-30. Scope: approved optional Gemini import route, native lifecycle, secrets, backup boundaries and Simulator usability. No live API calls, private receipt uploads or physical-device installation.

## Findings and fixes

| Finding | Resolution | Evidence |
| --- | --- | --- |
| A transport-originated cancellation could leave the active import reading indefinitely. | Move that current operation to recoverable failure, preserving the original; cancelled/replaced/background operations cannot touch new state. | Independent-cancellation regression; existing late-response regression. |
| A result could be applied after its connection was disabled or changed. | Cancel a visible upload when readiness disappears; recheck credential identity/readiness before applying a completed result. | Disabled-before-completion, background and identity-change checks. Requests already transmitted cannot be recalled. |
| Keychain replacement could leave the displayed connection ready until a later reload. | Reload readiness immediately if the send-time identity check fails. No credential fallback. | Changed-Keychain-identity regression. |
| 100 drawn covers plus two broad covers exceeded the 100-cover preparation limit. | Reserve two slots; cap drawn covers at 98 and explain when reached. | Maximum-drawn-plus-broad-covers test. |
| Horizontal bottom controls could crowd large accessibility text. | Use vertical controls for accessibility sizes; retain native button styles and hit targets. | Simulator accessibility-size walkthrough. |
| Clearing prepared bytes on every disappearance risked a blank preview after temporary presentation. | Keep state for the view lifetime, clear consent on disappearance/privacy covering, and cancel preparation through the view task. The existing lock/background path removes the view and its unsaved state. | Original-sheet return walkthrough. |

## Audited boundaries

- Camera, Photos and Files enter the same local preparation/choice boundary. Upload is explicit, model is fixed to the evaluated enum, provider endpoint is fixed, redirects are refused. No custom endpoint, automatic model upgrade, developer key or account fallback.
- Keychain reads require the verified credential identity. Replacement resets provider acknowledgment and enablement. Invalid credentials/access/model invalidate readiness; quota, offline and timeout failures preserve the valid connection and original, without an application retry. Status is historical verification, not a guaranteed live quota/availability claim.
- Keychain items use WhenUnlockedThisDeviceOnly, synchronization disabled. Defaults hold nonsecret connection preferences. Portable backup serializes receipt records, images and wallet settings, not API keys or AI connection preferences. Restore cannot import an AI credential or its upload approval. Existing connection/restart/identity tests cover mismatched restored metadata.
- Request JPEG preparation bakes orientation, creates new RGB pixels, flattens covers, discards original metadata and enforces byte/dimension limits. Request equality is tested against preview bytes. No OCR hints or original-image fallback is transmitted. The app creates no upload temporary file. URLSession disables persistent caches, cookies and credential storage; every request session invalidates on exit. This is an app-level audit, not a guarantee of provider retention or forensic RAM erasure.
- Success and error bodies are bounded. The adapter rejects malformed/truncated/unsupported output, preserves duplicates and ambiguity, and does not infer money by totals. Error UI uses safe categories. Untrusted model text cannot trigger tools or other network requests.
- Background/protected-data loss synchronously revoke the wallet session and cancel pending work; Face ID/passcode policy remains unchanged. The existing privacy cover protects inactive scenes. Per-image acknowledgment is cleared on privacy covering. An upload already sent is not recalled.
- The same draft editor, original source review, CAD-default provenance and exact reconciliation gates remain. Cancelled/error imports keep their photo while active, but backgrounding still discards unsaved work according to the existing app policy.

## Verification result

71 unique checks passed: 16 upload/preparation/lifecycle checks, 16 connection/key
checks, five intercepted transport checks, nine model adapter/workflow checks,
ten lock checks, twelve backup/restore checks and three UI walkthroughs. One
optional private-replay check skipped because its local fixture was absent.
The Release Simulator build passed. Private images, keys and responses were not
used or committed. User signing changes remain outside this milestone.

Logs: `/tmp/sliplet-p806-native.log`, `/tmp/sliplet-p806-followup.log`,
`/tmp/sliplet-p806-lock-backup.log`, `/tmp/sliplet-p806-timing.log`,
`/tmp/sliplet-p806-ui.log`, `/tmp/sliplet-p806-release.log`.

## Measurement and limits

Synthetic 1200×4000 image preparation was measured separately from a five-tick main-actor heartbeat on Simulator: preparation 0.012098833 seconds; largest heartbeat interval 0.011352333 seconds (10 ms requested sleeps). This is one scheduling sample, not p95, frame-time profiling, real-photo latency or a zero-lag claim. Network waiting was tested using intercepted pending/offline/timeout responses; no live Gemini latency was measured.

Dark default consent, light-mode Original return, and accessibility text are checked in Simulator. These do not substitute for physical Face ID, camera, VoiceOver, device thermal/memory behavior or a live user's-key request. Only one model/provider is offered, so arbitrary provider/model switching is not an exposed flow. No new receipt accuracy score or human correction-effort result is claimed; P8-07 owns acceptance on the existing references.

## Optional iPhone check after separate installation approval

Update the existing app without deleting its wallet. Configure the user's personal key locally on the phone (never in chat); the Mac Keychain key is not automatically copied. Verify with the fictional image, review provider terms and enable AI only if desired. Check a preview/cover in light and dark mode, cancel before Send, then check lock/background recovery. Any real upload requires the on-screen image approval. Inspect/edit/save/reopen the resulting draft if an upload is chosen. A physical installation is not included in this milestone.
