#!/usr/bin/env python3
"""P7-02 bounded frozen-source proof. Emit aggregates only; retain evidence privately."""
import collections, hashlib, json, subprocess, sys, uuid
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'evaluation/receipt-lab'))
import lab
BASE = ROOT / 'private-receipts/evaluation/p5-06-final'
OUT = ROOT / 'private-receipts/evaluation/p7-02-final'
WORKER = '/tmp/sliplet-p702-proof'

def read(p): return json.loads(p.read_text())
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(lines):
    p = subprocess.run([WORKER], input=json.dumps(lines), text=True, capture_output=True)
    if p.returncode: raise ValueError('worker_failed')
    return json.loads(p.stdout)
def actual(c):
    a = lab.fields_actual(c['draftFields'])
    for item, field in zip(a['lines'], c['draftFields']['items']): item['unit'] = field.get('unit')
    return a

def fictional():
    def observations(tail='2 @ $3.00 6.00', head='(2)123456 OAT CRACKERS', gap=.025, retailer='NO FRILLS', geometry=True, intervening=False):
        specs = [(retailer,.1,.95), (head,.1,.80)]
        if intervening: specs.append(('UNRELATED PRODUCT',.1,.79))
        specs.append((tail,.3,.80-gap))
        return [dict(id=str(uuid.uuid4()).upper(),text=t,**({'boundingBox':dict(x=x,y=y,width=.5,height=.025)} if geometry else {})) for t,x,y in specs]
    passed = 0
    cases = [({},1),({'tail':'2 @ $3.00'},0),({'tail':'2 @ $3.00 7.00'},0),
        ({'tail':'2 @ $3.00 6.00-'},0),({'tail':'2 @ $3.00 6.00 1.00'},0),
        ({'tail':'3 @ $2.00 6.00'},0),({'gap':.15},0),({'retailer':'UNFAMILIAR MARKET'},0),
        ({'geometry':False},0),({'head':'123456 OAT CRACKERS'},0),({'intervening':True},0)]
    for kwargs, expected in cases:
        obs=observations(**kwargs); result=run(obs); recovered=[l for l in result['parsed']['lines'] if l['description']==obs[1]['text']]
        assert len(recovered)==expected
        if expected:
            line=recovered[0]; assert line['amount']==600 and line['unitPrice']==300
            assert set(line['sourceLineIDs'])=={obs[1]['id'],obs[2]['id']}
            assert result['observations']==obs
        passed+=1
    return passed

def main():
    assert not OUT.exists(), 'new_run_required'
    checks=collections.Counter(fictional_tests_passed=fictional())
    refs=read(BASE/'reference-v2.json')['receipts']; reports=[]; outputs={}; hashes={}
    for slot,ref in enumerate(refs):
        path=BASE/f'captures/capture-{slot}-1.json'; old=read(path); new=run(old['observations'])
        hashes[str(path.relative_to(ROOT))]=digest(path)
        before=lab.score(actual(old),ref,old['observations']);after=lab.score(actual(new),ref,new['observations'])
        checks['exact_pairs_before']+=before['counts']['exact_purchase_pairs']
        checks['exact_pairs_after']+=after['counts']['exact_purchase_pairs']
        checks['raw_observations_preserved']+=int(new['observations']==old['observations'])
        for a,b in zip(before['line_results'],after['line_results']):
            for key,value in a['outcomes'].items():
                checks['lost_correct_line_fields']+=int(value in ('correct','correct_absence') and b['outcomes'].get(key)!=value)
        for key,label in ref['fields'].items():
            checks['lost_correct_summary_fields']+=int(lab.field_result(label,actual(old).get(key),key) in ('correct','correct_absence') and lab.field_result(label,actual(new).get(key),key) not in ('correct','correct_absence'))
        strip=lambda lines:[{k:v for k,v in l.items() if k!='id'} for l in lines]
        assert strip(new['parsed']['lines'][:len(old['parsed']['lines'])])==strip(old['parsed']['lines'])
        added=new['parsed']['lines'][len(old['parsed']['lines']):]
        checks['source_linked_candidate_lines_added']+=len(added)
        for line in added:
            matches=[r for r in ref['lines'] if r['fields']['description'].get('value') in line['description']]
            # Diagnostic only: containment is NOT accepted item identity or a strict recovered pair.
            checks['added_line_amount_equals_unique_contained_reference']+=int(len(matches)==1 and matches[0]['fields']['amount'].get('value')==line['amount'])
        repeat=run(old['observations'])
        assert strip(new['parsed']['lines'])==strip(repeat['parsed']['lines'])
        assert new['parsed']['issues']==repeat['parsed']['issues']
        checks['repeat_parser_runs_equal']+=1
        outputs[f'candidate-{slot}.json']=new
        reports.append({'before':before,'after':after})
    # The previously checked transcripts are additional no-regression checks.
    for slot in (0,1):
        path=BASE/f'captures/capture-{slot}-checked-text.json'
        if not path.exists(): continue
        old=read(path);new=run(old['observations']);hashes[str(path.relative_to(ROOT))]=digest(path)
        assert strip(new['parsed']['lines'])==strip(old['parsed']['lines'])
        checks['checked_transcripts_unchanged']+=1
    hashes[str((BASE/'reference-v2.json').relative_to(ROOT))]=digest(BASE/'reference-v2.json')
    for folder in ('Sliplet','evaluation/receipt-item-proof'):
        for p in (ROOT/folder).rglob('*'):
            if p.is_file() and p.suffix in ('.swift','.py'):hashes[str(p.relative_to(ROOT))]=digest(p)
    aggregate=dict(task='P7-02',receipts=5,held_out=0,checks=dict(checks),
        strict_gain=checks['exact_pairs_after']-checks['exact_pairs_before'],
        promotion='rejected' if checks['exact_pairs_after']<=43 or checks['lost_correct_line_fields'] or checks['lost_correct_summary_fields'] else 'requires_actual_app_comparison',
        actual_app_candidate_run=False,production_changed=False)
    OUT.mkdir(parents=True)
    for name,data in outputs.items(): (OUT/name).write_text(json.dumps(data))
    (OUT/'scores.json').write_text(json.dumps(reports))
    (OUT/'manifest.json').write_text(json.dumps(hashes,indent=2))
    (OUT/'aggregate.json').write_text(json.dumps(aggregate,indent=2)+'\n')
    assert all(digest(ROOT/p)==h for p,h in hashes.items())
    print(json.dumps(aggregate,indent=2))
if __name__=='__main__':
    try:main()
    except Exception: raise SystemExit('Item proof failed; private contents suppressed')
