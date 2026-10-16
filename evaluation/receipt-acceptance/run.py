#!/usr/bin/env python3
"""P4-06 exposed-set evaluation. References stay in evaluator, never in recognition."""
import argparse,collections,importlib.util,json,plistlib,statistics,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-fields'))
import run as fields
lab=fields.lab
BASE=ROOT/'private-receipts/evaluation/p4-04-accepted'

def device(identifier):
    data=json.loads(lab.run_tool(['xcrun','simctl','list','devices','available','-j']))
    d=next(({**v,'runtimeIdentifier':k} for k,vs in data['devices'].items() for v in vs if v['udid']==identifier),None)
    if not d or d['name']!='Sliplet P4-06 Acceptance Lab':raise ValueError('isolated_device_required')
    rs=json.loads(lab.run_tool(['xcrun','simctl','list','runtimes','-j']))['runtimes'];r=next(r for r in rs if r['identifier']==d['runtimeIdentifier'])
    return {**d,'runtimeVersion':r['version'],'runtimeBuild':r['buildversion']}
fields.device=device

def prepare(a):
    fields.prepare(a)
    out=lab.private(a.run);m=lab.read(out/'manifest.json');m['task']='P4-06';m['candidate_commit']=lab.run_tool(['git','rev-parse','HEAD']).strip()
    m['extra_sources'].update({str(p.relative_to(ROOT)):lab.digest(p) for p in Path(__file__).parent.glob('*.py')})
    data=plistlib.loads((out/'private.xctestrun').read_bytes())
    ts=[t for c in data.get('TestConfigurations',[]) for t in c['TestTargets']] if 'TestConfigurations' in data else [data['SlipletTests']]
    ts[0]['EnvironmentVariables']['SLIPLET_P406_PRIVATE']='YES'
    (out/'private.xctestrun').write_bytes(plistlib.dumps(data));lab.write(out/'manifest.json',m)

def collect(a):
    fields.collect(a)
    out=lab.private(a.run);m=lab.read(out/'manifest.json')
    c=Path(lab.run_tool(['xcrun','simctl','get_app_container',m['device'],lab.BUNDLE,'data']).strip())/'Documents/P401Lab'/m['nonce']
    for slot in range(5):lab.write(out/'captures'/f'reread-{slot}.json',lab.read(c/f'reread-{slot}.json'))
    r=evaluate(out);lab.write(out/'acceptance.json',r);print(json.dumps(r))

def evaluate(out):
    r=fields.evaluate(out);r['task']='P4-06';r['candidate_coverage']={};r['baseline_comparison']={}
    counts=collections.Counter();times=[];refs=lab.read(out/'reference-v2.json')['receipts']; stores={}
    for slot in range(5):
        capture=lab.read(out/'captures'/f'capture-{slot}-1.json');old=lab.read(BASE/'captures'/f'capture-{slot}-1.json')
        before=lab.score(lab.fields_actual(old['draftFields']),refs[slot],old['observations'])['counts']
        after=lab.score(lab.fields_actual(capture['draftFields']),refs[slot],capture['observations'])['counts']
        r['baseline_comparison'][str(slot+1)]={'same_scored_counts':before==after}
        attempts=lab.read(out/'captures'/f'reread-{slot}.json');byid={x['lineID']:x for x in attempts}
        assert len(byid)==len(attempts)
        actual=lab.fields_actual(capture['draftFields'])['lines'];pairs,_,ambiguous=lab.pairing(actual,refs[slot],capture['observations'])
        local=collections.Counter({'attempts':len(attempts),'successful_reads':sum(x['status']=='ok' for x in attempts)})
        times.extend(x['milliseconds'] for x in attempts if x['region'] is not None)
        for i,j in pairs:
            reference=refs[slot]['lines'][i]['fields']
            if reference['kind'].get('value')!='purchase':continue
            local['reference_purchases']+=1
            if j is None:local['unpaired_purchases']+=1;continue
            desired=reference['amount'].get('value');line=actual[j];attempt=byid.get(line['id'])
            if desired is None or attempt is None:local['unscorable_or_no_attempt']+=1;continue
            local['paired_scored_purchases']+=1
            from decimal import Decimal
            scale=capture['draftFields']['currency']['minorUnitScale']
            values={int(Decimal(x['value'])*(10**scale)) for x in attempt['choices']}
            correct=desired in values
            local['correct_amount_available']+=int(correct)
            local['offers_other_amounts']+=int(bool(values-{desired}))
            local['current_amount_incorrect_or_missing']+=int(line['amount']!=desired)
            local['potential_amount_recovery']+=int(line['amount']!=desired and correct)
        counts.update(local);store=lab.read(out/'manifest.json')['groups'][slot]['store'];stores.setdefault(store,collections.Counter()).update(local)
    r['candidate_coverage']={'counts':dict(counts),'stores':{k:dict(v) for k,v in stores.items()},'median_ms':statistics.median(times) if times else None,'max_ms':max(times) if times else None,'human_choices':0,'human_review_seconds':None,'complete_after_human_assistance':None,'scope':'suggested regions for existing purchase amounts; no missing-row recovery; candidates are not applied'}
    return r

def main():
    p=argparse.ArgumentParser();p.add_argument('command',choices=['prepare','collect','verify']);p.add_argument('--run',required=True);p.add_argument('--device');p.add_argument('--build');a=p.parse_args()
    if a.command=='prepare':prepare(a)
    elif a.command=='collect':collect(a)
    else:
        out=lab.private(a.run);assert evaluate(out)==lab.read(out/'acceptance.json');print('P4-06 private evidence verified')
if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('P4-06 evaluation failed; private contents were not printed')
