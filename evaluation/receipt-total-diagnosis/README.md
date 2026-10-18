# P6-01 frozen total trace

Run `python3 evaluation/receipt-total-diagnosis/run.py --verify` in the repository. Generation without `--verify` refuses existing outputs. It reads frozen P5-06 captures and references, checks source/reference/image integrity, and records public boolean findings plus private source indices/hashes in `private-receipts/evaluation/p6-01/total-trace.json`. No new OCR or parser execution occurs.

Original-image visual inspection is separately documented in `docs/PHASE6_TOTAL_DIAGNOSIS.md`; the script cannot automatically certify what is printed in pixels. It checks preserved observations/geometry and the specific checked-text sign edit. Do not turn diagnostic expected-digit searches into production recognition rules. No private values are printed. Successful diagnosis does not establish a recovery.
