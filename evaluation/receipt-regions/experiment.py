#!/usr/bin/env python3
"""Bounded private P4-02 Simulator experiments; stdout contains aggregates only."""
import argparse, collections, copy, importlib.util, json, math, os, plistlib, statistics, sys, uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'))
import lab
MODES=('baseline','correction-off','correction-on','english-only','auto-bounds','strips','candidates-second')
BASE=ROOT/'private-receipts/evaluation/p4-01-final-baseline'
read,write,digest=lab.read,lab.write,lab.digest

def device_info(device):
    data=json.loads(lab.run_tool(['xcrun','simctl','list','devices','available','-j']))
    found=next(({**d,'runtime':r} for r,ds in data['devices'].items() for d in ds if d['udid']==device),None)
    if not found or found['name']!='Sliplet P4-02 Recognition Lab':raise ValueError('dedicated_simulator_required')
    runtimes=json.loads(lab.run_tool(['xcrun','simctl','list','runtimes','-j']))['runtimes']
    runtime=next(r for r in runtimes if r['identifier']==found['runtime'])
    return {'device_type':found['deviceTypeIdentifier'],'runtime':found['runtime'],'version':runtime['version'],'build':runtime['buildversion']}

def sources():
    return {str(p.relative_to(ROOT)):digest(p) for folder in ('Sliplet','SlipletTests','evaluation/receipt-regions','evaluation/receipt-lab','evaluation/receipt-audit','evaluation/receipt-layout','evaluation/receipt-eval') for p in sorted((ROOT/folder).rglob('*')) if p.is_file() and p.suffix in {'.swift','.py'}}

def prepare(args):
    out=lab.private(args.run)
    if out.exists():raise ValueError('new_run_required')
    environment=device_info(args.device); old=read(BASE/'manifest.json')
    # Verify immutable reference and original identity before staging. No labels in app request.
    if digest(old['label_path'])!=old['label_hash'] or digest(BASE/'reference-v2.json')!=old['reference_hash']:raise ValueError('baseline_reference_changed')
    for g in old['groups']:
        for image in g['images']:
            if digest(image['path'])!=image['sha256']:raise ValueError('original_changed')
    out.mkdir(parents=True,mode=0o700);nonce=str(uuid.uuid4())
    app=Path(args.build)/'Build/Products/Debug-iphonesimulator/Sliplet.app'
    lab.run_tool(['xcrun','simctl','install',args.device,str(app)])
    container=Path(lab.run_tool(['xcrun','simctl','get_app_container',args.device,lab.BUNDLE,'data']).strip())
    inbox=container/'Documents/P402Lab'/nonce;inbox.mkdir(parents=True,mode=0o700)
    slots=[]
    for i,g in enumerate(old['groups']):
        original=g['images'][0];name=f'input-{i}'+Path(original['path']).suffix.lower()
        (inbox/name).write_bytes(Path(original['path']).read_bytes());(inbox/name).chmod(0o600)
        slots.append({'slot':i,'image':name,'sha256':original['sha256']})
    write(inbox/'request.json',{'nonce':nonce,'slots':slots})
    xct=next((Path(args.build)/'Build/Products').glob('*.xctestrun'));data=plistlib.loads(xct.read_bytes())
    targets=[t for c in data.get('TestConfigurations',[]) for t in c['TestTargets']] if 'TestConfigurations' in data else [v for k,v in data.items() if k=='SlipletTests']
    if len(targets)!=1:raise ValueError('unexpected_targets')
    targets[0].setdefault('EnvironmentVariables',{}).update(SLIPLET_P402_PRIVATE='YES',SLIPLET_P402_NONCE=nonce)
    def resolve(v):
        if isinstance(v,dict):return {k:resolve(x) for k,x in v.items()}
        if isinstance(v,list):return [resolve(x) for x in v]
        return v.replace('__TESTROOT__',str(xct.parent)) if isinstance(v,str) else v
    (out/'private.xctestrun').write_bytes(plistlib.dumps(resolve(data)))
    write(out/'manifest.json',{'nonce':nonce,'device':args.device,'environment':environment,'groups':old['groups'],'label_path':old['label_path'],'label_hash':old['label_hash'],'reference_hash':old['reference_hash'],'sources':sources(),'project_hash':digest(ROOT/'Sliplet.xcodeproj/project.pbxproj'),'app_hash':digest(app/'Sliplet'),'test_hash':digest(app/'PlugIns/SlipletTests.xctest/SlipletTests'),'modes':list(MODES),'repeats':2,'baseline_manifest_hash':digest(BASE/'manifest.json')})
    write(out/'reference-v2.json',read(BASE/'reference-v2.json'))
    print(json.dumps({'status':'prepared','purchases':5,'variants':len(MODES),'attempts':5*2*len(MODES),'labels_supplied_to_automatic_recognition':False}))

def semantic(response):
    # Canonical source identity by exact observation values, preserving row membership.
    obs=response['observations']; ids={o['id']:i for i,o in enumerate(obs)}
    def clean(v):
        if isinstance(v,dict):return {k:clean(x) for k,x in v.items() if k!='id'}
        if isinstance(v,list):return [clean(x) for x in v]
        return ids.get(v,v) if isinstance(v,str) else v
    return clean({k:response[k] for k in ('observations','parsed','fields','groupedRowIDs','interpretedRowIDs')})

def exact_multiset(response):
    return collections.Counter((l['kind'],lab.legacy.e.norm(l['description']),l['amount']) for l in response['parsed']['lines'])

def regressions(before,after,expected):
    ref=collections.Counter((l['kind'],lab.legacy.e.norm(l['description']),l['amount']) for l in expected['lines'])
    b,a=exact_multiset(before),exact_multiset(after)
    lost=sum(((b&ref)-(a&ref)).values());gained=sum(((a&ref)-(b&ref)).values())
    extra_before=b-ref;extra_after=a-ref
    new_unmatched=sum((extra_after-extra_before).values())
    summaries=sum(before['parsed'].get(k)==expected.get(k) and expected.get(k) is not None and after['parsed'].get(k)!=expected[k] for k in ('merchant','subtotal','total'))
    return {'lost_previously_exact_lines':lost,'gained_exact_lines':gained,'new_unmatched_line_proxies':new_unmatched,'lost_correct_summary_fields':summaries}

def collect(args):
    out=lab.private(args.run);m=read(out/'manifest.json');device_info(m['device'])
    container=Path(lab.run_tool(['xcrun','simctl','get_app_container',m['device'],lab.BUNDLE,'data']).strip())
    inbox=container/'Documents/P402Lab'/m['nonce'];request=read(inbox/'request.json')
    if set(request)!={'nonce','slots'} or request['nonce']!=m['nonce'] or any(set(s)!={'slot','image','sha256'} for s in request['slots']):raise ValueError('request_changed')
    captures=out/'captures';captures.mkdir(exist_ok=True,mode=0o700);write(captures/'request.json',request)
    for slot in range(5):
        for repeat in (1,2):
            for mode in MODES:
                for prefix in ('capture','attempt'):
                    name=f'{prefix}-{slot}-{repeat}-{mode}.json';p=inbox/name
                    if p.exists():write(captures/name,read(p))
                    elif prefix=='attempt':write(captures/name,{'status':'not_attempted'})
    report=evaluate(out);write(out/'aggregate.json',report);print(json.dumps(report))

def evaluate(out):
    m=read(out/'manifest.json')
    if sources()!=m['sources'] or digest(ROOT/'Sliplet.xcodeproj/project.pbxproj')!=m['project_hash']:raise ValueError('source_changed')
    if digest(m['label_path'])!=m['label_hash'] or digest(out/'reference-v2.json')!=m['reference_hash']:raise ValueError('reference_changed')
    for g in m['groups']:
        for image in g['images']:
            if digest(image['path'])!=image['sha256']:raise ValueError('original_changed')
    labels=lab.layout.validated_labels(Path(m['label_path']),ROOT/'private-receipts/evaluation/real-final',m['groups'])
    refs=read(out/'reference-v2.json')['receipts'];report={'task':'P4-02','development_purchases':5,'held_out_purchases':0,'environment':m['environment'],'variants':{}}
    for mode in MODES:
        totals=collections.Counter();stores={};v2=collections.Counter();verdicts=collections.Counter();reg=collections.Counter();times=[];first=[];stable=0;statuses=collections.Counter();same_old=0;blocked=0
        for slot,g in enumerate(m['groups']):
            passes=[]
            for repeat in (1,2):
                status=read(out/'captures'/f'attempt-{slot}-{repeat}-{mode}.json')['status'];statuses[status]+=1
                if status!='ok':passes.append(None);continue
                r=read(out/'captures'/f'capture-{slot}-{repeat}-{mode}.json')
                if (r['nonce'],r['slot'],r['pass'],r['mode'])!=(m['nonce'],slot,repeat,mode):raise ValueError('capture_identity')
                lab.layout.verify_membership(r)
                ids=[o['id'] for o in r['observations']]
                if len(set(ids))!=len(ids) or collections.Counter(ids)!=collections.Counter(i for row in r['interpretedRowIDs'] for i in row):raise ValueError('source_membership')
                if not math.isfinite(r['elapsedMS']) or r['elapsedMS']<0:raise ValueError('timing')
                (first if repeat==1 else times).append(r['elapsedMS']);passes.append(r)
            a,b=passes
            if a is None:continue
            stable+=int(b is not None and semantic(a)==semantic(b))
            expected=labels[g['purchase_id']];score=lab.legacy.amount_score(lab.legacy.normalize(a),expected);totals.update(score)
            stores.setdefault(g['store'],collections.Counter()).update(score)
            full=lab.score(lab.fields_actual(a['fields']),refs[slot],a['observations']);v2.update(full['counts']);verdicts[full['verdict']]+=1
            if a['parsed'].get('currency') is None:blocked+=len(a['parsed']['lines'])
            baseline=read(out/'captures'/f'capture-{slot}-1-baseline.json')
            reg.update(regressions(baseline,a,expected))
            if mode=='baseline':same_old+=int(semantic(a)==semantic(read(BASE/'captures'/f'capture-{slot}-1.json')))
        report['variants'][mode]={'attempt_statuses':dict(statuses),'repeat_pairs_equal':stable,'legacy':dict(totals),'stores':{k:dict(v) for k,v in stores.items()},'v2_counts':dict(v2),'verdicts':dict(verdicts),'regressions':dict(reg),'blocked_line_amounts':blocked,'repeat_median_ms':statistics.median(times) if times else None,'repeat_max_ms':max(times) if times else None,'first_median_ms':statistics.median(first) if first else None,'first_max_ms':max(first) if first else None,'baseline_full_semantics_equal_p401':same_old if mode=='baseline' else None}
    return report

def main():
    p=argparse.ArgumentParser();p.add_argument('command',choices=['prepare','collect','verify']);p.add_argument('--run',required=True);p.add_argument('--device');p.add_argument('--build');a=p.parse_args()
    if a.command=='prepare':prepare(a)
    elif a.command=='collect':collect(a)
    else:
        out=lab.private(a.run)
        if evaluate(out)!=read(out/'aggregate.json'):raise ValueError('report_changed')
        print('P4-02 evidence verified')
if __name__=='__main__':
    try:main()
    except Exception:print('P4-02 command failed; inspect locally without publishing private data',file=sys.stderr);sys.exit(1)
