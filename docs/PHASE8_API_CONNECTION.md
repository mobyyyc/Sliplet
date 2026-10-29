# P8-04 — Personal Gemini connection

Completed 2026-10-29. Settings → AI recognition now provides concealed key entry,
fictional image verification, historical check status, separate privacy acknowledgment,
enable/disable, replacement, disconnect, and official usage/key/policy links.
Only the experimentally tested Gemini 3.6 Flash model is offered; no arbitrary
endpoint, model marketplace or developer-account fallback is available.

## Credential and consent boundaries

Keys are stored using Security.framework in a separate, non-synchronizing,
WhenUnlockedThisDeviceOnly Keychain item. They are never included in receipt records,
Sliplet backup payloads, UserDefaults, source files or application logs. Nonsecret
preferences contain the model, last successful verification, safe last failure,
privacy policy version, enabled choice, and a random credential identity. An identity
mismatch or missing preferences cannot reuse prior verification/consent. Deletion
failures are reported rather than falsely claiming disconnect succeeded.

Replacement is transactional: a candidate remains in memory until its fictional
check passes and Keychain save succeeds. Failure leaves a working key and its
consent unchanged. Successful replacement requires renewed privacy acknowledgment
and leaves AI disabled. Disable preserves the key and cancels pending verification;
disconnect also deletes the credential. Provider-side revocation is a separate
Google AI Studio action. Entry text clears on submission, leaving the screen or
privacy covering. No automatic clipboard access or clearing is performed.

Connection verification does not establish data-retention settings, privacy, a free
tier, current remaining allowance or future availability. The latest successful
check is explicitly historical; a later failure remains a failure after restart.
Privacy acknowledgment is labeled as the user's statement, not provider verification.

## Verification request

One locally rendered fictional image is sent directly to the fixed Google endpoint
with the user's key in the x-goog-api-key header, never the URL. No real receipt,
OCR, stored wallet data, tools or account metadata is sent. The response must contain
correct fictional merchant/item/amount/total fields; HTTP success alone is insufficient.

The session is ephemeral, has no shared cookies/credentials/cache, rejects redirects,
limits the request to 300 KB and response to 64 KiB, and uses bounded 60-second request
and 90-second resource timeouts. There are no automatic retries or provider fallbacks.
Cancel, disable, disconnect, leaving Settings and workspace suspension cancel the
operation and reject late completion before it can save a key or mark a connection ready.

Safe categories distinguish invalid key, permission denial, model unavailable,
rate-or-quota limit, billing requirement, offline, timeout, service failure, invalid
response and secure-storage failure. Raw provider messages are never displayed.
A 429 is not represented as a known exhausted balance or a known reset time.

## Verification evidence

- 15 connection lifecycle/Keychain tests pass, including replacement failure,
  deletion failure, restart, revoked key, identity mismatch, cancellation and disable.
- 5 intercepted-transport tests pass for actual URLSession status handling, no retry,
  oversized data, offline/timeout, valid response and redirect denial. They use only
  fictional keys and do not contact Google.
- 9 existing model integration tests pass; the explicit private corpus replay test
  skips because its temporary fixture is absent (that parity was verified in P8-03).
- A native UI walkthrough verifies concealed entry, explicit test acknowledgment,
  verification, separate privacy acknowledgment, enabling and disconnect, using an
  isolated DEBUG-only in-memory fixture and no network.
- Visual inspection caught white-on-white enabled switches under the parent's
  monochrome tint. They now use the same standard green as existing review/Face ID
  switches. Initial UI failures were keyboard/switch-target automation issues; the
  corrected walkthrough exercises the actual switch controls.

No live provider request, real API key transfer or real-receipt upload was made for
this milestone. The live check is implemented but must be explicitly run by the
user with their own key. No actual account validity, balance or live latency is claimed.
Physical-phone behavior has not been newly checked in this task.

## Product boundary and next task

This milestone connects and verifies an account. Ordinary imports still use local
Vision, even if the user enables the stored AI preference. The Settings footer
states this explicitly. P8-05 must add the prepared-image upload preview, consent,
local/AI import choice, recognition transport and recovery before sending real
receipts. No silent cloud upload or migration of the Mac development key is included.

Next approval: P8-05, private upload preview and one coherent review flow.

## Sources checked

Google's official [pricing/data-use table](https://ai.google.dev/gemini-api/docs/pricing)
explains free versus paid data use and allowances. The app links directly rather
than asserting a verified plan or balance. Google's
[API troubleshooting](https://ai.google.dev/gemini-api/docs/troubleshooting) and
[Generate Content error reference](https://ai.google.dev/gemini-api/docs/generate-content/api-errors)
inform the error categories. Sliplet deliberately uses explicit user retry rather
than automatic retries for this bounded connection test.
