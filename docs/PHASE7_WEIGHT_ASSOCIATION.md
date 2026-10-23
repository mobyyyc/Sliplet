# P7-06 — source-backed weighted-item association

Production candidate `p7-06-weight-extensions-0.7.1` recognizes an unpriced description immediately followed by an indented, spatially adjacent weight/rate row containing its own printed extension. Explicit matching weight units, exact monetary syntax and corroborating rounded arithmetic are required. All source observations remain unchanged; the printed extension is copied, never calculated to fill a missing price.

The rule uses relative geometry and layout syntax, not receipt identities, product names or checked amounts. It is restricted to existing recognized merchant formats. Unknown merchants and ambiguous layouts retain current behavior. It cannot consume source IDs already used by another parsed line. It preserves repeated purchases, source order, printed suffixes and all independent review gates. Total/payment footer and section-label guards prevent those contexts from becoming purchases. Intermediate single-letter annotations are retained in raw evidence, not asserted as verified tax markers.

## Measured effect

Two weighted purchases are recovered in each of the two retained native OCR passes. Exact purchase pairs rise from 56/65 to **57/65 (87.7%)**. One recovered item retains a printed suffix absent from the frozen expected description; it does not count as an exact recovery. We preserve the text and keep the frozen score rather than silently rewrite labels or strip the suffix. Two more exact recoveries are needed for the 59/65 target.

All ten private frozen-OCR replays preserve existing parsed lines and their ordering, every previously correct line/summary field, raw observations and source-review requirements. No source IDs are consumed by two purchases. Merchant/date, subtotal and total outcomes remain unchanged; the two missing totals are not fixed by this task.

31 fictional checks cover three recognized merchants, alternate names/prices/units, repeated occurrences, relative geometry transforms, exact source association, missing/mismatched/negative/extra extensions, mismatched units, section/summary labels, footer boundaries, unknown merchants, missing geometry and distant/non-indented rows.

## Other hypotheses and stopping decisions

Description-boundary inspection found printed three-letter suffixes contributing to mismatches. They are not safe to delete globally, especially given the user's instruction to retain printed trailing codes. No score-driven suffix-stripping rule is introduced. The existing frozen reference remains unchanged for this milestone.

The wrong-amount case's checked magnitude is absent from nearby retained OCR observations. No association change can safely manufacture those digits; route it to P7-07's OCR candidate experiment.

The discount's magnitude exists in source text, but a numeric promotion row by itself does not prove a globally valid adjustment classification or parent link. User confirmation of this specific receipt is not enough to turn every adjacent negative/numeric row into an item-linked discount. Preserve the separate reviewed discount reference and leave automatic linkage unresolved. A future candidate must establish sign/role evidence and counterexamples rather than infer tax or parent from proximity alone.

P7-06 therefore ships only the independently measured weighted-layout improvement. No unrelated parser rewrite, speculative merchant tax assumption or neutral candidate is integrated. Fresh OCR and full app-flow integration remain P7-07/P7-08 work. Five exposed receipts, zero held-out; synthetic transformations are not unseen purchases.

## Reproduction

Compile the production ParseWorker with domain dependencies as documented in `PHASE7_REPRODUCTION.md`, output `/tmp/sliplet-p706-parse`. Run `evaluation/receipt-weight-association/check.py`; it requires a new private output directory and refuses overwrite. Inputs use frozen `p7-05-final/reference-v3.json` and retained replay observations. Private P7-06 evidence includes both passes and source hashes. Public evidence includes only aggregate counters.

Native regression verification: 46/46 tests passed, zero skipped or failed, across ReceiptRetailerParserTests, ReceiptSummaryParserTests and ReceiptCountExtensionTests in a dedicated iPhone 15 Pro Simulator. The production app compiled successfully. Normal Simulator and phone wallets were not modified.
