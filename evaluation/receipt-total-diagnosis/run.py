#!/usr/bin/env python3
"""P6-01 frozen total-failure trace. No OCR, parser edits, or reference changes."""
import argparse, hashlib, json, re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'private-receipts/evaluation/p5-06-final'
def read(p): return json.loads(p.read_text())
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def digit_string(t): return re.sub(r'\D', '', t)
def total_label(t): return bool(re.match(r'^\W*TOTAL(?:\s*[\d$]|\s*$)', t, re.I))
def run():
    m = read(BASE/'manifest.json'); refs = read(BASE/'reference-v2.json')['receipts']
    assert digest(BASE/'reference-v2.json') == m['reference_hash']
    assert digest(Path(m['label_path'])) == m['label_hash']
    for name, h in {**m['sources'], **m['extra_sources']}.items(): assert digest(ROOT/name) == h
    cases = []; ledger = []; inputs = {}
    for slot, ref in enumerate(refs):
        path = BASE/'captures'/f'capture-{slot}-1.json'; c = read(path)
        desired = ref['fields']['total']['value']
        if c['parsed'].get('total') == desired: continue
        cp = BASE/'captures'/f'capture-{slot}-checked-text.json'; checked = read(cp)
        images = m['groups'][slot]['images']
        for im in images: assert digest(Path(im['path'])) == im['sha256']
        for p in (path, cp): inputs[str(p.relative_to(ROOT))] = digest(p)
        assert c['storeRoundtripEqual'] and c['draftFields'] == c['reloadedFields']
        raw = c['observations']; edited = checked['observations']
        assert len(raw) == len(edited)
        assert all(a.get('boundingBox') == b.get('boundingBox') for a,b in zip(raw,edited))
        wanted = str(abs(desired)); indexed = {o['id']:i for i,o in enumerate(raw)}
        rows = [r for r in c['interpretedRows'] if total_label(r['text'])]
        assert len(rows) == 1
        row = rows[0]; row_indices = [indexed[sid] for sid in row['ids']]
        signed = [i for i in row_indices if digit_string(raw[i]['text']) == wanted and raw[i]['text'].rstrip().endswith('-')]
        public = {
            'case': chr(65+len(cases)),
            'parser_total_missing': c['parsed'].get('total') is None,
            'total_label_recognized_in_rows': True,
            'expected_digits_present_anywhere_raw': any(wanted in digit_string(o['text']) for o in raw),
            'expected_digits_present_in_total_row': wanted in digit_string(row['text']),
            'expected_digits_present_anywhere_checked': any(wanted in digit_string(o['text']) for o in edited),
            'checked_transcript_total_correct': checked['parsed'].get('total') == desired,
            'negative_summary_guard_triggered': any(x['code']=='negative_summary_check_source' for x in c['parsed']['issues']),
            'total_source_fragment_count': len(row_indices),
            'matching_digit_fragment_has_trailing_minus': bool(signed),
            'checked_total_fragment_edit_only_removes_trailing_minus': bool(signed) and all(raw[i]['text'].rstrip()[:-1] == edited[i]['text'].rstrip() for i in signed),
            'original_and_checked_geometry_equal': True,
            'storage_preserved_fields': True,
        }
        if not public['expected_digits_present_anywhere_raw']:
            public['first_confirmed_failure'] = 'amount_absent_from_saved_ocr'
            assert not public['expected_digits_present_anywhere_checked']
        else:
            assert signed and public['negative_summary_guard_triggered']
            assert public['checked_total_fragment_edit_only_removes_trailing_minus']
            assert public['checked_transcript_total_correct']
            public['first_confirmed_failure'] = 'spurious_sign_in_saved_total_ocr_confirmed_by_checked_text_and_visual_inspection'
        cases.append(public)
        ledger.append({'case':public['case'],'slot':slot,'image_paths':[im['path'] for im in images],
                       'image_hashes':[im['sha256'] for im in images], 'total_observation_indices':row_indices,
                       'signed_total_observation_indices':signed,'total_source_ids':row['ids']})
    assert len(cases)==2
    return {'task':'P6-01','mode':'frozen_evidence_diagnosis','failed_totals':2,'new_ocr_runs':0,
            'production_changes':False,'reference_changes':False,'new_accuracy_claim':False,'cases':cases}, {'inputs':inputs,'cases':ledger}
def main():
    p=argparse.ArgumentParser();p.add_argument('--verify',action='store_true');a=p.parse_args()
    public,private=run()
    paths=[(ROOT/'docs/evidence/p6-01/aggregate.json',public),(ROOT/'private-receipts/evaluation/p6-01/total-trace.json',private)]
    for path,value in paths:
        if a.verify: assert read(path)==value
        else:
            assert not path.exists()
            path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')
            if 'private-receipts' in path.parts:path.chmod(0o600)
    print('P6-01 two-total trace verified' if a.verify else 'P6-01 two-total trace recorded')
if __name__=='__main__':
    try: main()
    except Exception: raise SystemExit('P6-01 diagnosis failed; private contents suppressed')
