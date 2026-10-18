#!/usr/bin/env python3
"""P6-02B isolated Simulator probe. Semantic labels never enter recognition."""
import argparse,collections,json,plistlib,statistics,sys,re
from decimal import Decimal
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-fields'))
import run as fields
lab=fields.lab
BASE=ROOT/'private-receipts/evaluation/p5-06-final'
def device(identifier):
    data=json.loads(lab.run_tool(['xcrun','simctl','list','devices','available','-j']))
    d=next(({**v,'runtimeIdentifier':k} for k,vs in data['devices'].items() for v in vs if v['udid']==identifier),None)
    if not d or d['name']!='Sliplet P6-02B Total Lab':raise ValueError('isolated_device_required')
    rs=json.loads(lab.run_tool(['xcrun','simctl','list','runtimes','-j']))['runtimes'];r=next(r for r in rs if r['identifier']==d['runtimeIdentifier'])
    return {**d,'runtimeVersion':r['version'],'runtimeBuild':r['buildversion']}
fields.device=device
def prepare(a):
    fields.prepare(a);out=lab.private(a.run);m=lab.read(out/'manifest.json');m['task']='P6-02B'
    m['extra_sources'].update({str(p.relative_to(ROOT)):lab.digest(p) for p in Path(__file__).resolve().parent.glob('*.py')})
    data=plistlib.loads((out/'private.xctestrun').read_bytes())
    ts=[t for c in data.get('TestConfigurations',[]) for t in c['TestTargets']] if 'TestConfigurations' in data else [data['SlipletTests']]
    ts[0]['EnvironmentVariables']['SLIPLET_P602B_PRIVATE']='YES'
    (out/'private.xctestrun').write_bytes(plistlib.dumps(data));lab.write(out/'manifest.json',m)
def stable(c):
    positions={o['id']:i for i,o in enumerate(c['observations'])}
    def clean(v):
        if isinstance(v,dict):return {k:sorted(positions[x] for x in a) if k=='sourceLineIDs' else clean(a) for k,a in v.items() if k!='id'}
        if isinstance(v,list):return [clean(a) for a in v]
        return v
    return clean(c['draftFields'])
def evaluate(out):
    report=fields.evaluate(out);report['task']='P6-02B';counts=collections.Counter();timings=[];cases=[]
    refs=lab.read(out/'reference-v2.json')['receipts']
    for slot in range(5):
        c=lab.read(out/'captures'/f'capture-{slot}-1.json');old=lab.read(BASE/'captures'/f'capture-{slot}-1.json')
        assert stable(c)==stable(old);counts['unchanged_baseline_fields_and_sources']+=1
        probes=lab.read(out/'captures'/f'anchored-probe-{slot}.json');assert len(probes)==2
        desired=refs[slot]['fields']['total']['value'];base=c['parsed'].get('total')
        def semantic(v):
            if isinstance(v,dict):return {k:semantic(a) for k,a in v.items() if k!='id'}
            if isinstance(v,list):return [semantic(a) for a in v]
            return v
        assert all(semantic(p['baseline'])==semantic(c['parsed']) for p in probes)
        assert probes[0].get('proposedTotal')==probes[1].get('proposedTotal');counts['stable_proposed_totals']+=1
        for probe in probes:
            if probe['decision']=='anchored_literal_with_digit_corroboration':
                ids=probe['supportingObservationIDs'];assert len(ids)==3
                assert ids[0] in {o['id'] for o in c['observations']}
                supporting=[]
                for reading,identifier in zip(probe['reads'],ids[1:]):
                    supporting.append(next(o['text'].strip() for o in reading['observations'] if o['id']==identifier))
                assert all('-' not in t and '−' not in t for t in supporting)
                assert re.sub(r'\D','',supporting[0])==re.sub(r'\D','',supporting[1])
                values=[]
                for t in supporting:
                    if re.fullmatch(r'\$?\d+\.\d{2}',t):values.append(int(Decimal(t.lstrip('$'))*100))
                    elif re.fullmatch(r'\$?\d+,\d{2}',t):values.append(int(Decimal(t.lstrip('$').replace(',','.'))*100))
                assert values and all(v==probe['proposedTotal'] for v in values)
                counts['literal_source_support_verified']+=1
        candidate=probes[0].get('proposedTotal');counts['baseline_totals_correct']+=int(base==desired)
        counts['proposed_totals_correct']+=int(candidate==desired)
        counts['recovered_totals']+=int(base!=desired and candidate==desired)
        counts['lost_correct_totals']+=int(base==desired and candidate!=desired)
        counts['new_wrong_totals']+=int(candidate is not None and candidate!=desired and candidate!=base)
        methods={}
        for p in probes:
            for r in p['reads']:
                counts['region_reads']+=1;timings.append(r['milliseconds'])
                methods.setdefault(r['mode'],[]).append(r['parsed'].get('total')==desired)
                for o in r['observations']:
                    box=o['boundingBox'];roi=p['region']
                    # The renderer rounds outward by at most one source pixel.
                    for key,extent in [('x','width'),('y','height')]:
                        assert box[key]>=roi[key]-0.001
                        assert box[key]+box[extent]<=roi[key]+roi[extent]+0.001
        cases.append({'case':slot+1,'baseline_correct':base==desired,'proposed_correct':candidate==desired,
                      'decision':probes[0]['decision'],'read_correctness_by_mode':methods})
    report['probe']={'counts':dict(counts),'cases':cases,'median_read_ms':statistics.median(timings) if timings else None,
                     'max_read_ms':max(timings) if timings else None,'production_integrated':False,
                     'scope':'proposed total substitution only; baseline fields unchanged; no candidate draft saved'}
    report['proof_gate_passed']=counts['recovered_totals']>=1 and counts['lost_correct_totals']==0 and counts['new_wrong_totals']==0
    return report
def main():
    p=argparse.ArgumentParser();p.add_argument('command',choices=['prepare','collect','verify']);p.add_argument('--run',required=True);p.add_argument('--device');p.add_argument('--build');a=p.parse_args();out=lab.private(a.run)
    if a.command=='prepare':prepare(a)
    elif a.command=='collect':
        fields.collect(a);m=lab.read(out/'manifest.json')
        c=Path(lab.run_tool(['xcrun','simctl','get_app_container',m['device'],lab.BUNDLE,'data']).strip())/'Documents/P401Lab'/m['nonce']
        for slot in range(5):lab.write(out/'captures'/f'anchored-probe-{slot}.json',lab.read(c/f'anchored-probe-{slot}.json'))
        report=evaluate(out);lab.write(out/'probe.json',report);print(json.dumps(report))
    else:
        assert evaluate(out)==lab.read(out/'probe.json');print('P6-02B frozen probe verified')
if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('P6-02B evaluation failed; private content suppressed')
