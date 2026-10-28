# Phase 8: frozen confirmation of structured receipt extraction

The user approved a fresh bounded confirmation following the structured-field
experiment and post-hoc layout recovery. This task does not change the prompt,
schema, numeric handling, local recovery rule, scoring matcher or reference-v4.
It does not integrate the model into the app.

## Frozen before dispatch

`confirm_structured.py` records hashes for extraction/recovery/scoring code,
reference-v4, all five saved local baseline captures, prior experiment configuration
and evidence, and the exact complete-image bytes. Each request is identical in
content/configuration to the previous experiment's corresponding request, except
that it is a fresh provider invocation. No OCR or human answers are in the payload.
The adapter is fixed before this run, unlike the preceding post-hoc replay.

The same personal Gemini Free-tier account, stateless endpoint, 6500-token cap,
60-second timeout and 95-second spacing apply. There are at most five requests,
one for each actual receipt, with no retry or fallback. Prior passing fictional
gates are reused only under the unchanged frozen source configuration. Failed or
interrupted reservations stop dispatch rather than silently sending again.

Predeclared acceptance checks for adapted output:
- At least 60/66 exact core purchases, including exact indistinguishable duplicate
  groups, which is the first integer count above the 90% purchase target.
- At least 8/9 exact adjustments, preserving the prior benefit.
- All five totals correct.
- At least four canonical dates correct, preserving the prior result while
  allowing the previously identified ambiguous numeric date to remain unresolved.

Every receipt remains a review-required draft. Recovered boundaries are flagged;
marker tax meaning is not inferred. Independent unit-price/quantity coverage is
still absent from the reference and does not become verified because a field is
populated. Human correction time, physical-phone performance and unseen accuracy
are not measured by this confirmation.

## Evidence and validation

Private requests/raw responses/frozen configuration are retained in
`structured-confirmation-01`. Raw and adapted outputs have separate score ledgers;
adapted results do not overwrite model results. The report reconstructs every
request from the same pixels, decodes every provider response again, and checks
input/code hashes before evaluating. Only safe aggregates are committed.

Five new fictional protocol tests cover failed/interrupted reservations, duplicate
or out-of-range calls, the five-request stopping condition, next-unattempted
selection, and rejection of 59/66 as below 90%. The existing extraction/layout tests
also pass: 30 local tests in total. No app or phone changes were made.


## Execution stopped at provider error — 2026-10-28

Two of at most five permitted requests were attempted. The first returned a usable
response in 11.565 seconds. The second returned HTTP 503 UNAVAILABLE in 9.675
seconds. Dispatch stopped as declared: no retry, fallback or remaining-receipt
uploads. This is a provider availability failure, not evidence of a parsing failure.

The report reproduces the first request, original response and frozen adapter
output, and verifies the failed request's retained payload and safe diagnostic.
The confirmation is incomplete; there is no five-receipt score or acceptance pass.
The prior post-hoc 62/66 result remains historical evidence, not a confirmed result
from this run. Both successful and failed attempts remain in the private ledger.

Proposed continuation, requiring the user's next approval: at most four further
requests using the identical frozen payload/adapter/reference. Retry only the
unavailable second receipt once, then attempt the three not-yet-sent receipts.
Retain the successful first receipt without resending it. This would total six
attempts across the confirmation and continuation, for five receipt results if all
four additional requests succeed. Stop again on any failure, retain the failed
attempt in reliability counts, and do not tune the extraction or scoring rules.
This proposal has not been dispatched and is not an automatic retry policy.

## Approved continuation — 2026-10-28

The user approved the four-request continuation. `resume_structured_confirmation.py`
verifies the original frozen configuration, successful first response and failed
second response before dispatch. It sends only receipt slots two through five,
with at most four new attempts and no further automatic retry. The retry payload
must exactly match the original failed request. The original successful receipt
is reused without sending it again. Original records remain unchanged.

Four additional protocol tests check exclusion of the first receipt, stopping after
failed/interrupted retry, the four-request completion cap and rejection of duplicate
or out-of-scope requests. The retry of receipt two succeeded. Remaining execution
and the combined raw/adapted acceptance report are pending.

### Continuation stopped at request timeout

Three of the four approved continuation attempts were made. The retry of receipt
two succeeded in 11.629 seconds; receipt three succeeded in 19.750 seconds;
receipt four returned the transport's network_or_timeout category after 60.122
seconds. The fifth receipt was not sent. No further retry was attempted.

Across the original confirmation and continuation, five attempts have produced
three usable receipt responses, one HTTP 503 and one network/timeout failure.
The extraction/schema/adapter/reference hashes remain unchanged. This still does
not produce a five-receipt confirmation or justify reusing the earlier 93.9% as a
new result. The first successful receipt was not resent. Thirty-four local tests
pass, but they do not establish provider reliability.

Next proposed approval: at most two requests, retrying only receipt four and
sending the unsent fifth receipt, with a 120-second transport timeout and the same
frozen extraction rules and acceptance gates. Preserve the three successes and
both failed attempts. This would total seven attempts if both new requests are
made. Explicitly record the timeout change as a transport difference; do not claim
identical latency conditions. Stop again on any failure. This proposal has not
been dispatched and is not an automatic retry policy.
