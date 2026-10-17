#!/usr/bin/env python3
"""P5-04 actual-app imports and checked-text replay. Private inputs, aggregate output."""
import argparse,collections,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-fields'))
import run as fields
lab=fields.lab
BASE=ROOT/'private-receipts/evaluation/p5-03-final'
def device(identifier):
    data=json.loads(lab.run_tool(['xcrun','simctl','list','devices','available','-j']))
    d=next(({**v,'runtimeIdentifier':k} for k,vs in data['devices'].items() for v in vs if v['udid']==identifier),None)
    if not d or d['name']!='Sliplet P5-04 Merchant Lab':raise ValueError('isolated_device_required')
    runtimes=json.loads(lab.run_tool(['xcrun','simctl','list','runtimes','-j']))['runtimes'];r=next(r for r in runtimes if r['identifier']==d['runtimeIdentifier'])
    return {**d,'runtimeVersion':r['version'],'runtimeBuild':r['buildversion']}
fields.device=device

def evaluate(out):
    report=fields.evaluate(out);report['task']='P5-04';report['held_out']=0
    refs=lab.read(out/'reference-v2.json')['receipts'];c=collections.Counter();checks=collections.Counter()
    m=lab.read(out/'manifest.json');labels=lab.read(Path(m['label_path']))['receipts']
    for slot,ref in enumerate(refs):
        old=lab.read(BASE/'captures'/f'capture-{slot}-1.json');new=lab.read(out/'captures'/f'capture-{slot}-1.json')
        checks['same_raw_observations']+=int(old['observations']==new['observations'])
        # IDs vary across imports. Compare raw text and geometry without generated IDs.
        def raw(r):return [{k:v for k,v in o.items() if k!='id'} for o in r['observations']]
        checks['same_raw_text_geometry']+=int(raw(old)==raw(new))
        checks['same_merchant']+=int(old['parsed'].get('merchant')==new['parsed'].get('merchant'))
        def stable_fields(capture):
            positions={o['id']:i for i,o in enumerate(capture['observations'])}
            def clean(value):
                if isinstance(value,dict):
                    return {k:sorted(positions[i] for i in v) if k=='sourceLineIDs' else clean(v)
                            for k,v in value.items() if k!='id'}
                if isinstance(value,list):return [clean(v) for v in value]
                return value
            return clean(capture['draftFields'])
        checks['identical_draft_fields_and_sources']+=int(stable_fields(old)==stable_fields(new))
        expected=next(r['expected'] for r in labels if r['id']==m['groups'][slot]['purchase_id'])
        checks.update(fields.experiment.regressions(old,new,expected))
        for name in ('subtotal','total'):
            desired=expected.get(name)
            if desired is None:continue
            c[name+'_before_correct']+=int(old['parsed'].get(name)==desired)
            c[name+'_after_correct']+=int(new['parsed'].get(name)==desired)
            checks['lost_correct_summary']+=int(old['parsed'].get(name)==desired and new['parsed'].get(name)!=desired)
            checks['new_wrong_summary']+=int(new['parsed'].get(name) not in (None,desired) and new['parsed'].get(name)!=old['parsed'].get(name))
        before=lab.score(lab.fields_actual(old['draftFields']),ref,old['observations'])
        after=lab.score(lab.fields_actual(new['draftFields']),ref,new['observations'])
        for a,b in zip(before['line_results'],after['line_results']):
            for key,value in a['outcomes'].items():
                if value in ('correct','correct_absence') and b['outcomes'].get(key)!=value:checks['lost_correct_strict_line_field']+=1
        if slot in (0,1):
            a=lab.read(BASE/'captures'/f'capture-{slot}-checked-text.json');b=lab.read(out/'captures'/f'capture-{slot}-checked-text.json')
            checks['same_checked_observations']+=int(a['observations']==b['observations'])
            for name in ('subtotal','total'):
                desired=expected.get(name)
                if desired is not None:
                    c['checked_'+name+'_before_correct']+=int(a['parsed'].get(name)==desired)
                    c['checked_'+name+'_after_correct']+=int(b['parsed'].get(name)==desired)
    report['p503_comparison']=dict(checks);report['summary_comparison']=dict(c)
    return report

def main():
    p=argparse.ArgumentParser();p.add_argument('command',choices=['prepare','collect','verify']);p.add_argument('--run',required=True);p.add_argument('--device');p.add_argument('--build');a=p.parse_args();out=lab.private(a.run)
    if a.command=='prepare':
        fields.prepare(a);m=lab.read(out/'manifest.json');m['task']='P5-04'
        m['extra_sources'].update({str(p.relative_to(ROOT)):lab.digest(p) for p in Path(__file__).parent.glob('*.py')})
        lab.write(out/'manifest.json',m)
    elif a.command=='collect':
        # The existing collector validates all ten attempts and two literal replays.
        fields.collect(a);report=evaluate(out);lab.write(out/'p504-aggregate.json',report);print(json.dumps(report))
    else:
        assert evaluate(out)==lab.read(out/'p504-aggregate.json');print('P5-04 private captures and evaluation verified')
if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('P5-04 evaluation failed; private contents suppressed')
