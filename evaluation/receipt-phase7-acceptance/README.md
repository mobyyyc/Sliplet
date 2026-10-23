# Phase 7 final acceptance audit

Run from the repository root:

```sh
python3 evaluation/receipt-phase7-acceptance/check.py
```

Requires the retained private P7-05 references, P7-08 native imports, source manifests, and before/after ParseWorkers described in the P7-08 reproduction notes. No OCR, Simulator launch, network call or production mutation occurs. Failure details are suppressed to protect private receipt content.

The script verifies the integration evidence and comparator provenance, scores both independent import passes including persisted fields, and compares the derived aggregate, private ledger and input manifest. `write` creates a new private audit directory and aggregate; it refuses existing private output. Keep all private evidence ignored. Results are restricted to five exposed receipts with zero held-out data.
