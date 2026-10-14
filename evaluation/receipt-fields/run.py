#!/usr/bin/env python3
"""P4-04 app import + verified literal replay. Private evidence, safe aggregates."""
import argparse,collections,json,os,plistlib,statistics,sys,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'));import lab
sys.path.insert(0,str(ROOT/'evaluation/receipt-regions'));import experiment
BASE=ROOT/'private-receipts/evaluation/p4-02-automatic-v2'

def device(device):
    data=json.loads(lab.run_tool(['xcrun','simctl','list','devices','available','-j']))
    d=next(({**v,'runtimeIdentifier':k} for k,values in data['devices'].items() for v in values if v['udid']==device),None)
    if not d or d['name']!='Sliplet P4-04 Field Lab':raise ValueError('dedicated_device_required')
    runtimes=json.loads(lab.run_tool(['xcrun','simctl','list','runtimes','-j']))['runtimes'];r=next(r for r in runtimes if r['identifier']==d['runtimeIdentifier'])
    return {**d,'runtimeVersion':r['version'],'runtimeBuild':r['buildversion']}

def prepare(a):
    # Reuse staging only, not the historical baseline scorer or unchanged-conversion assumptions.
    lab.check_device=device;lab.prepare(a)
    out=lab.private(a.run);m=lab.read(out/'manifest.json')
    m['task']='P4-04';m['extra_sources']={str(p.relative_to(ROOT)):lab.digest(p) for p in (ROOT/'evaluation/receipt-fields').glob('*.py')}
    export=lab.read(BASE/'human-export.json');slots=[{'slot':r['slot'],'humanVerified':True,'observations':r['observations']} for r in export['receipts'] if r['humanVerified']]
    assert len(slots)==2
    m['human_export_hash']=lab.digest(BASE/'human-export.json');m['baseline_manifest_hash']=lab.digest(BASE/'manifest.json')
    container=Path(lab.run_tool(['xcrun','simctl','get_app_container',a.device,lab.BUNDLE,'data']).strip());inbox=container/'Documents/P402Lab'/m['nonce'];inbox.mkdir(parents=True,mode=0o700)
    lab.write(inbox/'transcripts.json',{'nonce':m['nonce'],'slots':slots})
    data=plistlib.loads((out/'private.xctestrun').read_bytes());targets=[t for c in data.get('TestConfigurations',[]) for t in c['TestTargets']] if 'TestConfigurations' in data else [data['SlipletTests']]
    targets[0]['EnvironmentVariables'].update(SLIPLET_P402_PRIVATE='YES',SLIPLET_P402_NONCE=m['nonce'],SLIPLET_P402_CHECKED_TEXT='YES')
    (out/'private.xctestrun').write_bytes(plistlib.dumps(data));lab.write(out/'manifest.json',m)

def collect(a):
    out=lab.private(a.run);m=lab.read(out/'manifest.json');device(m['device'])
    container=Path(lab.run_tool(['xcrun','simctl','get_app_container',m['device'],lab.BUNDLE,'data']).strip());captures=out/'captures';captures.mkdir(exist_ok=True,mode=0o700)
    for slot in range(5):
        for repeat in (1,2):
            for kind in ('attempt','capture'):
                name=f'{kind}-{slot}-{repeat}.json';source=container/'Documents/P401Lab'/m['nonce']/name
                if source.exists():lab.write(captures/name,lab.read(source))
                elif kind=='attempt':lab.write(captures/name,{'status':'not_attempted'})
    for slot in (0,1):
        name=f'capture-{slot}-checked-text.json';lab.write(captures/name,lab.read(container/'Documents/P402Lab'/m['nonce']/name))
    report=evaluate(out);lab.write(out/'aggregate.json',report);print(json.dumps(report))

def evaluate(out):
    m=lab.read(out/'manifest.json')
    for p,h in {**m['sources'],**m['extra_sources']}.items():
        if lab.digest(ROOT/p)!=h:raise ValueError('source_changed')
    for p,h in [(m['label_path'],m['label_hash']),(out/'reference-v2.json',m['reference_hash']),(BASE/'human-export.json',m['human_export_hash'])]:
        if lab.digest(p)!=h:raise ValueError('reference_changed')
    if lab.digest(ROOT/'Sliplet.xcodeproj/project.pbxproj')!=m['project_hash']:raise ValueError('project_changed')
    labels=lab.layout.validated_labels(Path(m['label_path']),ROOT/'private-receipts/evaluation/real-final',m['groups']);refs=lab.read(out/'reference-v2.json')['receipts']
    report={'task':'P4-04','development_purchases':5,'held_out':0,'attempts':10,'successful':0,'stable_repeats':0,'draft_roundtrips':0,'legacy':{},'structured_counts':{},'verdicts':{},'regressions':{},'stores':{},'checked_text':{},'currency_defaults':0,'unscored_populated_attributes':{}}
    times=[];repeats=[]
    def count(key,values):report[key]=dict(collections.Counter(report[key])+collections.Counter(values))
    for slot,g in enumerate(m['groups']):
        for image in g['images']:
            if lab.digest(image['path'])!=image['sha256']:raise ValueError('original_changed')
        rs=[]
        for repeat in (1,2):
            status=lab.read(out/'captures'/f'attempt-{slot}-{repeat}.json')['status']
            if status!='ok':raise ValueError('incomplete_attempt')
            r=lab.read(out/'captures'/f'capture-{slot}-{repeat}.json');assert r['nonce']==m['nonce'] and r['slot']==slot and r['pass']==repeat
            lab.layout.verify_membership(r);assert collections.Counter(o['id'] for o in r['observations'])==collections.Counter(i for row in r['interpretedRowIDs'] for i in row)
            assert r['replayEqual'] and r['originalBytesEqual'] and not r['draftCanFinalize'] and r['storeRoundtripEqual'] and r['reviewInputEqual']
            report['successful']+=1;rs.append(r);(times if repeat==1 else repeats).append(r['importToReviewMS'])
        r=rs[0];report['stable_repeats']+=int(lab.stable(rs[0])==lab.stable(rs[1]));report['draft_roundtrips']+=1
        expected=labels[g['purchase_id']];score=lab.legacy.amount_score(lab.legacy.normalize(r),expected);count('legacy',score)
        report['stores'].setdefault(g['store'],{});report['stores'][g['store']]=dict(collections.Counter(report['stores'][g['store']])+collections.Counter(score))
        actual=lab.fields_actual(r['draftFields'])
        for line,item in zip(actual['lines'],r['draftFields']['items']):line['unit']=item.get('unit')
        populated=collections.Counter()
        for item in r['draftFields']['items']:
            for key in ('sku','unit','unitPrice','taxMarker','quantity'):
                if item.get(key) is not None:populated[key]+=1
        populated['rate']=sum(item.get('rate') is not None for item in r['draftFields']['adjustments'])
        count('unscored_populated_attributes',populated)
        scored=lab.score(actual,refs[slot],r['observations']);count('structured_counts',scored['counts']);count('verdicts',{scored['verdict']:1})
        before=lab.read(BASE/'captures'/f'capture-{slot}-1-baseline.json');count('regressions',experiment.regressions(before,r,expected))
        count('regressions',{'new_wrong_summary_values':sum(expected.get(k) is not None and r['parsed'].get(k) is not None and r['parsed'].get(k)!=expected[k] and r['parsed'].get(k)!=before['parsed'].get(k) for k in ('subtotal','total'))})
        count('regressions',{'lost_or_changed_printed_currency':int(before['parsed'].get('currency') is not None and before['parsed'].get('currency') != r['parsed'].get('currency'))})
        if r['parsed'].get('currency') is None and r['draftFields'].get('currency') is not None:report['currency_defaults']+=1
        if slot in (0,1):
            checked=lab.read(out/'captures'/f'capture-{slot}-checked-text.json');previous=lab.read(BASE/'captures'/f'capture-{slot}-checked-text.json')
            assert checked['observations']==previous['observations']
            score=lab.legacy.amount_score(lab.legacy.normalize(checked),expected);report['checked_text'][str(slot+1)]={'legacy':score,'regressions':experiment.regressions(previous,checked,expected)}
    report['first_median_ms']=statistics.median(times);report['repeat_median_ms']=statistics.median(repeats);report['repeat_max_ms']=max(repeats)
    return report

def main():
    p=argparse.ArgumentParser();p.add_argument('command',choices=['prepare','collect','verify']);p.add_argument('--run',required=True);p.add_argument('--device');p.add_argument('--build');a=p.parse_args()
    if a.command=='prepare':prepare(a)
    elif a.command=='collect':collect(a)
    else:
        out=lab.private(a.run);assert evaluate(out)==lab.read(out/'aggregate.json');print('P4-04 evidence verified')
if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('P4-04 evaluation failed; inspect privately without publishing receipt contents')
