#!/usr/bin/env python3
"""Post-hoc explanation only; never modifies the frozen selection or proof gate."""
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
    root=(ROOT/sys.argv[1]).resolve();assert root.is_relative_to(ROOT/'private-receipts/evaluation')
    refs=json.loads((root/'reference-v2.json').read_text())['receipts'];cases=[]
    for slot in range(2):
        wanted=refs[slot]['fields']['total']['value'];digits=str(abs(wanted));fmt=f'{abs(wanted)//100}.{abs(wanted)%100:02d}'
        probes=json.loads((root/'captures'/f'total-probe-{slot}.json').read_text());modes=[]
        for read in probes[0]['reads']:
            matches=[o for o in read['observations'] if digits in re.sub(r'\D','',o['text'])]
            label=[o for o in read['observations'] if re.search(r'\bTOTAL\b',o['text'])]
            modes.append({'mode':read['mode'],'reference_digits_present':bool(matches),
                          'exact_reference_money_token_present':any(re.search(r'(?<![\d.,-])'+re.escape(fmt)+r'(?![\d.,-])',o['text']) for o in matches),
                          'total_word_present':bool(label),
                          'total_word_has_unaccepted_prefix':any(not re.match(r'^[\s*:=#•·_]*TOTAL\b',o['text']) for o in label),
                          'total_word_linked_as_purchase':any(l['kind']=='purchase' and any(o['id'] in l['sourceLineIDs'] for o in label) for l in read['parsed']['lines']),
                          'parsed_total_missing':read['parsed'].get('total') is None})
        cases.append({'case':slot+1,'modes':modes})
    print(json.dumps({'scope':'post-hoc first-pass explanation; no rule tuning or recovery claim','cases':cases},indent=2,sort_keys=True))
if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('Probe diagnosis failed; private content suppressed')
