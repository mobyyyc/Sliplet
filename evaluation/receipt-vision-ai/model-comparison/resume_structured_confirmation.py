"""Explicitly approved four-request continuation. Existing rules stay frozen."""
from collections import Counter
import copy
import json
import math
import os
from pathlib import Path
import sys
import time
import confirm_structured as previous

trial=previous.trial
repair=previous.repair
OUT=previous.OUT.parent/'structured-confirmation-continuation-01'
COMBINED=OUT/'combined'
ADAPTED=OUT/'adapted'


def freeze():
    images=previous.freeze()
    history=previous.calls()
    if [c['name'] for c in history]!=['real-0-1','real-1-1']:raise ValueError('unexpected_previous_calls')
    first=trial.load(previous.OUT/'responses/real-0-1.json')
    failed=trial.load(previous.OUT/'responses/real-1-1.json')
    if first['status']!='received' or failed.get('diagnostic',{}).get('http_status')!=503:
        raise ValueError('unexpected_previous_outcome')
    files=[Path(__file__),previous.OUT/'configuration.json',previous.OUT/'calls.json',
           previous.OUT/'responses/real-0-1.json',previous.OUT/'responses/real-1-1.json']
    config={'task':'approved frozen confirmation continuation','maximum_new_requests':4,
            'receipt_slots':[1,2,3,4],'reused_receipt_slot':0,'total_possible_attempts':6,
            'automatic_retries':0,'authorization':'User approved one retry of unavailable second receipt followed by the three unsent receipts.',
            'unchanged_extraction_verified_by_prior_freeze':True,
            'files':{str(p.relative_to(trial.ROOT)):repair.digest(p) for p in files}}
    OUT.mkdir(parents=True,exist_ok=True,mode=0o700);repair.write_once(OUT/'configuration.json',config)
    return images


def history():
    return trial.load(OUT/'calls.json') if (OUT/'calls.json').exists() else []


def select(calls,results):
    names=[c['name'] for c in calls];allowed={f'real-{i}-1' for i in range(1,5)}
    if len(names)!=len(set(names)) or not set(names)<=allowed or len(names)>4:raise ValueError('invalid_continuation_inventory')
    if any(results.get(n,{}).get('status')!='received' for n in names):return None,'stopped_after_failure'
    if len(names)==4:return None,'complete'
    return next(i for i in range(1,5) if f'real-{i}-1' not in names),'ready'


def next_call():
    images=freeze();calls=history()
    results={c['name']:trial.load(OUT/'responses'/f"{c['name']}.json") for c in calls if (OUT/'responses'/f"{c['name']}.json").exists()}
    slot,status=select(calls,results)
    if slot is None:return {'status':status,'new_requests':len(calls)}
    last=(calls or previous.calls())[-1]['time']
    remaining=math.ceil(95-(time.time()-last))
    if remaining>0:return {'status':'spacing','seconds':remaining,'new_requests':len(calls)}
    trial.n.c.preflight()
    name=f'real-{slot}-1';request=trial.body(images[slot]);digest=trial.hash_bytes(json.dumps(request,sort_keys=True).encode())
    if slot==1 and request!=trial.load(previous.OUT/'requests'/f'{name}.json'):raise ValueError('retry_payload_changed')
    old=trial.n.c.old;old.OUT=OUT;old.MAX_CALLS={'real':4,'fictional':0};old.INTERVAL=95
    old.reserve('real',name,digest);trial.write(OUT/'requests'/f'{name}.json',request)
    result={'name':name,'payload_sha256':digest,'status':'not_sent'};start=time.monotonic()
    try:
        key=trial.n.c.credentials.keychain.read_key()
        if not key:raise trial.extract.lab.LabError('key_missing')
        try:envelope=trial.n.send(request,key)
        finally:del key
        trial.write(OUT/'raw'/f'{name}.json',envelope)
        result.update(trial.parse(envelope),status='received',usage=envelope.get('usageMetadata',{}))
    except trial.extract.lab.LabError as error:
        result.update(status=str(error),diagnostic=error.diagnostic)
    result['elapsed_seconds']=round(time.monotonic()-start,3);trial.write(OUT/'responses'/f'{name}.json',result)
    return {k:v for k,v in result.items() if k in ('name','status','diagnostic','elapsed_seconds')}


def report():
    images=freeze();previous.report();calls=history();results={};statuses=Counter();times=[];reviews=Counter()
    for old in previous.calls():
        statuses[trial.load(previous.OUT/'responses'/f"{old['name']}.json")['status']]+=1
    for call in calls:
        name=call['name'];slot=int(name.split('-')[1]);request=trial.load(OUT/'requests'/f'{name}.json');result=trial.load(OUT/'responses'/f'{name}.json')
        assert request==trial.body(images[slot])
        assert call['payload_sha256']==result['payload_sha256']==trial.hash_bytes(json.dumps(request,sort_keys=True).encode())
        if result['status']=='received':
            parsed=trial.parse(trial.load(OUT/'raw'/f'{name}.json'))
            assert all(result[k]==v for k,v in parsed.items())
        results[name]=result;statuses[result['status']]+=1;times.append(result['elapsed_seconds'])
    _,status=select(calls,results)
    summary={'task':'frozen confirmation continuation','new_requests':len(calls),'total_attempts':2+len(calls),
             'attempt_statuses_including_prior_failure':dict(statuses),'complete':status=='complete',
             'new_response_seconds':times,'first_receipt_reused_without_resending':True,
             'extraction_and_recovery_unchanged':True,'held_out_receipts':0,'app_changed':False}
    if status=='complete':
        for folder in (COMBINED,ADAPTED):(folder/'responses').mkdir(parents=True,mode=0o700,exist_ok=True)
        results['real-0-1']=trial.load(previous.OUT/'responses/real-0-1.json')
        for name,result in results.items():
            repair.write_once(COMBINED/'responses'/f'{name}.json',result)
            actual,validation=previous.layout.canonical(result['candidate'])
            adapted=copy.deepcopy(result);adapted.update(actual=actual,validation=validation,adapter_frozen_before_inference=True)
            repair.write_once(ADAPTED/'responses'/f'{name}.json',adapted)
            reviews['boundary_rows']+=len(validation['boundary_review'])
            reviews['receipts_with_boundary_review']+=bool(validation['boundary_review'])
            reviews['invalid_numeric_or_unit_fields']+=len(validation['invalid_fields'])
            reviews['receipts_requiring_review']+=validation['review_required']
        raw,rl=previous.score_folder(COMBINED);adapted,al=previous.score_folder(ADAPTED)
        repair.write_once(OUT/'raw-score-ledger.json',rl);repair.write_once(OUT/'adapted-score-ledger.json',al)
        gates=previous.acceptance(adapted)
        summary.update(raw_comparison=raw,adapted_comparison=adapted,review_flags=dict(reviews),gates=gates,
                       all_gates_passed=all(gates.values()),
                       prior_adapted=trial.load(trial.OUT/'layout-replay-02/summary.json')['comparison']['gemini'],
                       limitations=['Same five exposed receipts; confirmation is not held-out accuracy.',
                                    'Human review still required, including recovered name boundaries.',
                                    'Quantity and unit-price coverage is insufficient for accuracy claims.',
                                    'One provider 503 is retained in reliability counts.'])
    trial.write(OUT/'summary.json',summary);return summary


if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['prepare']:freeze();result={'status':'frozen','new_requests':0}
        elif sys.argv[1:]==['next']:result=next_call()
        elif sys.argv[1:]==['report']:result=report()
        else:raise ValueError('explicit_command_required')
        print(json.dumps(result,indent=2))
    except Exception as error:
        sys.exit(str(error) if isinstance(error,trial.extract.lab.LabError) else 'continuation_stopped_private_details_suppressed')
