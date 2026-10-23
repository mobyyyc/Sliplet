# P8-01 vision AI evaluation lab

This is an isolated development harness, not app recognition code. The only network command sends the checked-in fictional `smoke.png` to Groq. There is no private-photo path, URL-input option or arbitrary endpoint. The harness does not read private references during requests.

## Local verification

From the repository root:

```sh
python3 evaluation/receipt-vision-ai/lab.py check
python3 -m unittest discover -s evaluation/receipt-vision-ai -p 'test_*.py'
python3 evaluation/receipt-phase7-acceptance/check.py
```

The first two commands use only Python's standard library and make no network requests. The last verifies retained private Phase 7 evidence and prints aggregate results only. Fixtures are fictional; the 27 tests check harness behavior, not model accuracy. Eleven images cover summary/payment separation, repeated purchases, total in a product name, discounts, refunds, weights, missing digits, prompt injection, printed suffixes, bilingual text and long receipts. Only `smoke.expected.json` is a fully structured expected response; remaining cases currently have printed text and challenge descriptions, not completed model evaluations.

`generate_fixtures.py` needs Pillow and the macOS Arial Unicode font. It regenerates fictional assets and their manifest. Existing PNGs are committed for byte-stable requests; no Pillow dependency is required to run a smoke test.

## Private API-key entry

Open `Run-Fictional-Test.command` in Terminal. Confirm FREE only after checking the account plan. Paste a fresh key into the hidden prompt, then type TEST to authorize the single fictional request. Never put the key in chat, command arguments, source files or an environment file. The launcher does not save it to Keychain yet: it is a one-request, in-memory credential. Later app connections use device Keychain.

The endpoint and model are fixed in `lab.py`. Requests use TLS verification, disallow redirects and implicit proxies, and never retry automatically. There is one request per launch and a local UTC-day maximum of three attempts, counting failures. Do not reset the counter to bypass the budget; diagnose first. User confirmation of a free plan is not API verification of billing status.

A status-only report is saved to ignored `private-receipts/evaluation/p8-01-lab/smoke-result.json` with owner-only permissions. It contains no key, image, raw model output or private receipt fields. `credential_accepted` is separate from schema validity and `fictional_exact`. Provider account privacy controls remain unverified by this request. A successful fictional test does not demonstrate real receipt accuracy.

Generic error states suppress response bodies and exception details. `rate_or_quota_limited` intentionally does not guess whether 429 means a short rate limit or exhausted allowance. No automatic model fallback or billing upgrade is permitted. Close the Terminal window to cancel; a request already transmitted cannot be recalled.

## Boundaries

The local schema validator supports only the keywords used in `schema.json`, rejects unknown keywords, and is not a general JSON Schema library. P8-03 must independently validate the production implementation. Quotes and boxes remain model claims; passing schema and arithmetic never sets source-reviewed or Finish.

Mac model installation, private cloud payload preparation, private evaluation runs and production changes have not been performed here. See `docs/PHASE8_AI_LAB.md` for the frozen P8-02 proposal and outstanding account/provider gates.
