"""Local byte inventory supporting manual visual findings; no network or scoring.

Record once with --record, then verify without arguments. Hashes remain private.
This verifies evidence identity, not the correctness of visual interpretations.
"""
import argparse
import base64
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
PRIVATE = ROOT / 'private-receipts/evaluation'
OUT = PRIVATE / 'p8-02e/source-audit-01'
RUN = PRIVATE / 'p8-02e/real-five-correction-01'
# One-based frozen reference positions. Categories overlap; no relabeling.
NOTES = {
    'model_price_column_marker_in_name': [(1,1),(1,2),(1,3),(1,5),(1,6),(1,12),(2,13),(2,22)],
    'model_quantity_prefix_in_name': [(3,9),(3,10)],
    'reference_transcription_conflict': [(1,1),(5,2)],
    'reference_heading_or_fragment_as_name': [(4,3),(4,5)],
    'reference_omits_printed_name_suffix': [(3,8),(4,15),(4,16)],
    'reference_omits_printed_coupon_code': [(1,21),(2,20),(2,21),(2,22)],
    'reference_includes_price_column_marker': [(5,1),(5,2)],
}
DATES = ['correct', 'model_digit_error', 'redacted_out', 'redacted_out',
         'visible_ambiguous_numeric_date']
EXTRA = {'reference_missing_printed_purchase': [1],
         'reference_missing_printed_tax': [4],
         'model_loyalty_row_as_purchase': [3],
         'model_zero_identifier_row_as_purchase_needs_role_confirmation': [5]}


def inventory():
    paths = [PRIVATE / 'p7-05-final/reference-v3.json']
    for slot in range(5):
        request = RUN / f'requests/real-{slot}-1.json'
        sent = OUT / f'sent-{slot+1}.jpg'
        body = json.loads(request.read_text())
        images = [p['inlineData'] for c in body['contents']
                  for p in c['parts'] if 'inlineData' in p]
        if len(images) != 1 or images[0]['mimeType'] != 'image/jpeg':
            raise ValueError('unexpected_image_layout')
        if base64.b64decode(images[0]['data'], validate=True) != sent.read_bytes():
            raise ValueError('sent_image_mismatch')
        paths += [request, sent, RUN / f'responses/real-{slot}-1.json',
                  PRIVATE / f'p8-01-redaction-review/receipt-{slot+1}-local.png']
    paths += [RUN / 'error-ledger.json', RUN / 'supplementary-audit.json',
              Path(__file__).resolve()]
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in paths}


def main(record=False):
    before = inventory()
    path = OUT / 'source-audit.json'
    evidence = {'method': 'manual_visual_inspection', 'input_hashes': before,
                'dates': DATES, 'reference_row_notes': NOTES, 'extra_rows': EXTRA}
    # Normalize tuples to JSON arrays for exact replay comparison.
    evidence = json.loads(json.dumps(evidence))
    if record:
        with path.open('x') as stream:
            json.dump(evidence, stream, indent=2)
        path.chmod(0o600)
    elif json.loads(path.read_text()) != evidence:
        raise ValueError('audit_evidence_changed')
    if before != inventory():
        raise ValueError('inputs_changed_during_audit')
    return {'receipts': 5, 'held_out_receipts': 0,
            'date_categories': dict(Counter(DATES)),
            'description_category_counts': {k: len(v) for k,v in NOTES.items()},
            'distinct_reference_rows_inspected': len({r for rows in NOTES.values() for r in rows}),
            'extra_output_categories': {k: len(v) for k,v in EXTRA.items()},
            'existing_scores_unchanged': True, 'labels_unchanged': True,
            'new_network_requests': 0, 'evidence_inventory_verified': True,
            'interpretation': 'Manual findings; overlapping categories; no revised accuracy claim.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--record', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(main(args.record), indent=2))
    except Exception:
        sys.exit('source_audit_failed_private_details_suppressed')
