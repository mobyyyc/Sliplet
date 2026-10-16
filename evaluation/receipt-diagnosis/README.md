# P5-01 diagnostic replay

Read-only analysis of frozen P4-06 captures; no new OCR, simulator or production changes. Requires local private evidence. Outputs a public aggregate and a private indexed field ledger without copying receipt strings into either output. The private ledger includes input hashes and receipt/row indices and must not be published.

```sh
python3 evaluation/receipt-acceptance/run.py verify --run private-receipts/evaluation/p4-06-final
python3 evaluation/receipt-diagnosis/map.py --public docs/evidence/p5-01/aggregate.json --private private-receipts/evaluation/p5-01/failure-ledger.json --verify
python3 -m unittest discover -s evaluation/receipt-lab -p 'test_*.py'
```

Omit `--verify` only to generate new, nonexistent output paths; the script refuses overwriting. Historical evidence and references are never rewritten. The recorded report is tied to production `71d4ded`; source hash checks should fail after future changes rather than silently repurposing old captures as current behavior.

Uses strict pairing with verified geometry or unique kind/description, without amount-based disambiguation. Text containment and expected-amount presence are diagnostic clues only, not independent identity evidence. Every non-correct field outcome is inventoried; unresolved categories are not claims of a proven cause. Legacy checked-text counters are reported separately. See the report for units, duplicate ambiguity and annotation coverage limits.
