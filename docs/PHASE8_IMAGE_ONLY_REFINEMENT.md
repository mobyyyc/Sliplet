# P8-02D — image-only field contract refinement

Approved 2026-10-26. Fictional experiment complete; acceptance gate not met. Production recognition is unchanged. This is the focused refinement of P8-02C, not a provider change or OCR reintroduction.

## What changed

The prompt and schema now define quantity as a decimal without a unit, unit as a label without numbers or price expressions, and unit price as a printed numeric amount without its suffix. A generic measurement example differs from the fictional test inputs. Zero-value tax/adjustment rows must be retained. Unprinted currency and ambiguous dates remain null.

The response retains a literal `date_raw` and `currency_raw`. Existing deterministic date parsing rejects ambiguous date interpretations, and a currency claim must match an explicit ISO token in the model's literal transcription. These are internal consistency checks, not independent image verification: a model can still misread or invent both fields. They use no OCR, no verified answers and no original private text. Raw responses remain available privately, including rejected values. Local arithmetic only flags conflicts; it never creates or changes a price.

Descriptions in the JSON schema guide the model; the established local validator receives the same schema with only annotation descriptions removed. All validation constraints and the actual `description` property remain intact. The historical transport and previous frozen experiments are unchanged.

## Frozen procedure

At most six fictional requests and, only after all six meet their checked-field gate, ten real requests (two passes over the same five approved redacted receipts). No automatic retry, new provider, account upgrade or paid fallback. Keep the existing model and image preparation, 95-second spacing, user Keychain credential, approved masks and manually confirmed inference ZDR. One full image per request; no OCR hints, source coordinates or reference answers.

The six fictional variations preserve the prior challenge categories while changing dates, the ambiguous date, the weighted product/measurement, and the explicit currency. Expected answers are fixed before inference and never enter the prompt. These are developer-designed exposed cases, not held-out real receipts or a claim of generalization. The normalizer and prompt are frozen before the first call. Local validation failures remain failures while unattempted fictional cases can continue; a provider error stops the run. No failed request is retried.

Real evaluation, if permitted by the gate, uses the P8-02C coordinate-free unique kind/description matcher for both baseline and candidate. No amount-assisted pairing. Duplicate identities remain ambiguous. References are not edited; only an in-memory scoring copy drops geometry. All five receipts remain in the denominator, including failed/unattempted responses. Any real claims exclude unchecked quantities/weights/unit prices and unseen purchases. No app integration in this task.

## Validation and evidence

Twenty local tests cover literal signed money, no forced reconciliation/default quantities, repeated occurrences, zero tax, date ambiguity, currency transcription requirements, unit/quantity rejection, payment separation, image-only requests, immutable labels and conservative matching. Private inputs, requests, hashes and responses remain ignored and owner-only. Only fictional or aggregate evidence may be committed. A provider connection success does not establish model accuracy or available quota for larger real images.

## Observed results

Six requests returned usable structured responses, with zero provider errors and zero real uploads. **4/6 cases passed every checked field.** The weighted, repeated-purchase, ambiguous-information and multilingual/zero-tax variations passed. All tested currency fields were correct. The weighted units were properly separated; the model itself left the ambiguous ISO date null, and the zero tax row was retained.

The dense case omitted its nonzero tax row, although all products/coupons and summary values matched. Reconciliation flagged that omission. The printed-instruction case did not follow the malicious text and read the purchase/total correctly, but supplied a subtotal not printed on the image. That extra field cannot be detected merely by checking arithmetic. Thus image-only field extraction is not yet reliable enough for promotion.

Across the six fictional responses, 23/24 expected accounting rows matched. This is a diagnostic on exposed synthetic fixtures, not a real-receipt accuracy percentage. The prior P8-02C result was 2/6 on related but different fixture images; because this run changed test dates/measurements/currency, it is not an identical-input causal comparison. The four targeted failure patterns passed here, while omissions and unsupported fields remain. No claim about unseen receipts or beating the real local-OCR baseline follows.

The model did not trigger the local `date_claim_not_supported` or `currency_claim_not_supported` corrections in this run. Ambiguous date and missing total warnings in the ambiguity case are expected abstentions. All raw output remains retained; no private labels were changed, no failed case removed and no normalization/prompt change made after freezing.

## Disposition and next proposal

Do not integrate into the app or upload the real corpus: the six-case gate failed. Preserve this image-only prompt/schema as a comparison candidate. Recommend a separate P8-02E task to evaluate another vision model on these identical fictional fixtures, with the prompt, field contract and scoring held fixed. First check the candidate's current availability, genuinely free usage and image/structured-output support. No paid fallback. Any new provider's real-receipt use still requires its privacy review and user approval. A comparison can distinguish model suitability from repeated prompt changes more clearly than another unpaired prompt tweak.

This comparison is proposed, not executed or approved. Current phase remains blocked from app integration by measured extraction failures, not by the existence of an OCR dependency.

## Reproduction

Use the bundled Python runtime with `-m unittest discover -s evaluation/receipt-vision-ai/image-only-refined -p 'test_*.py'` (20 passing), `score.py fictional` and `verify.py`. Verification reproduces all six retained request bodies and canonical results, confirms no OCR or coordinates entered requests, checks frozen configuration and fixture hashes, and reports zero real attempts. Historical P8-02C files remain unchanged. Public evidence is fictional scores and aggregate verification only.
