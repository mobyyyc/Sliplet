"""Explicitly approved two-request completion. Existing rules stay frozen."""
from collections import Counter
import copy
import json
import math
import os
from pathlib import Path
import sys
import time
import confirm_structured as previous
import resume_structured_confirmation as resumed

trial=previous.trial
repair=previous.repair
OUT=previous.OUT.parent/'structured-confirmation-finish-01'
COMBINED=OUT/'combined'
ADAPTED=OUT/'adapted'


def freeze():
    images=resumed.freeze()
    calls=resumed.history()
    if [c['name'] for c in calls]!=['real-1-1','real-2-1','real-3-1']:raise ValueError('unexpected_prior_inventory')
    outcomes=[trial.load(resumed.OUT/'responses'/f"{c['name']}.json")['status'] for c in calls]
    if outcomes!=['received','received','network_or_timeout']:raise ValueError('unexpected_prior_outcomes')
    files=[Path(__file__),resumed.OUT/'configuration.json',resumed.OUT/'calls.json']
    files += [resumed.OUT/'responses'/f"{c['name']}.json" for c in calls]
    config={'task':'approved frozen confirmation completion','maximum_new_requests':2,
            'receipt_slots':[3,4],'reused_receipt_slots':[0,1,2],'total_possible_attempts':7,
            'automatic_retries':0,'transport_timeout_seconds':120,'previous_timeout_seconds':60,
            'authorization':'User approved two outstanding receipts with 120 second timeout.',
            'unchanged_extraction_verified_by_prior_freeze':True,
            'files':{str(p.relative_to(trial.ROOT)):repair.digest(p) for p in files}}
    OUT.mkdir(parents=True,exist_ok=True,mode=0o700);repair.write_once(OUT/'configuration.json',config)
    return images


def history():
    return trial.load(OUT/'calls.json') if (OUT/'calls.json').exists() else []


def select(calls,results):
    names=[c['name'] for c in calls];allowed={f'real-{i}-1' for i in range(3,5)}
    if len(names)!=len(set(names)) or not set(names)<=allowed or len(names)>2:raise ValueError('invalid_continuation_inventory')
    if any(results.get(n,{}).get('status')!='received' for n in names):return None,'stopped_after_failure'
    if len(names)==2:return None,'complete'
    return next(i for i in range(3,5) if f'real-{i}-1' not in names),'ready'


def next_call():
    images=freeze();calls=history()
    results={c['name']:trial.load(OUT/'responses'/f"{c['name']}.json") for c in calls if (OUT/'responses'/f"{c['name']}.json").exists()}
    slot,status=select(calls,results)
    if slot is None:return {'status':status,'new_requests':len(calls)}
    last=(calls or resumed.history())[-1]['time']
    remaining=math.ceil(95-(time.time()-last))
    if remaining>0:return {'status':'spacing','seconds':remaining,'new_requests':len(calls)}
    trial.n.c.preflight()
    name=f'real-{slot}-1';request=trial.body(images[slot]);digest=trial.hash_bytes(json.dumps(request,sort_keys=True).encode())
    if slot==3 and request!=trial.load(resumed.OUT/'requests'/f'{name}.json'):raise ValueError('retry_payload_changed')
    old=trial.n.c.old;old.OUT=OUT;old.MAX_CALLS={'real':2,'fictional':0};old.INTERVAL=95
    old.reserve('real',name,digest);trial.write(OUT/'requests'/f'{name}.json',request)
    result={'name':name,'payload_sha256':digest,'status':'not_sent'};start=time.monotonic()
    try:
        key=trial.n.c.credentials.keychain.read_key()
        if not key:raise trial.extract.lab.LabError('key_missing')
        original_timeout=trial.n.TIMEOUT
        try:
            trial.n.TIMEOUT=120
            envelope=trial.n.send(request,key)
        finally:
            trial.n.TIMEOUT=original_timeout
            del key
        trial.write(OUT/'raw'/f'{name}.json',envelope)
        result.update(trial.parse(envelope),status='received',usage=envelope.get('usageMetadata',{}))
    except trial.extract.lab.LabError as error:
        result.update(status=str(error),diagnostic=error.diagnostic)
    result['elapsed_seconds']=round(time.monotonic()-start,3);trial.write(OUT/'responses'/f'{name}.json',result)
    return {k:v for k,v in result.items() if k in ('name','status','diagnostic','elapsed_seconds')}


def report():
    images=freeze();resumed.report();calls=history();results={};statuses=Counter();times=[];reviews=Counter()
    for old in previous.calls():
        statuses[trial.load(previous.OUT/'responses'/f"{old['name']}.json")['status']]+=1
    for old in resumed.history():
        statuses[trial.load(resumed.OUT/'responses'/f"{old['name']}.json")['status']]+=1
    for call in calls:
        name=call['name'];slot=int(name.split('-')[1]);request=trial.load(OUT/'requests'/f'{name}.json');result=trial.load(OUT/'responses'/f'{name}.json')
        assert request==trial.body(images[slot])
        assert call['payload_sha256']==result['payload_sha256']==trial.hash_bytes(json.dumps(request,sort_keys=True).encode())
        if result['status']=='received':
            parsed=trial.parse(trial.load(OUT/'raw'/f'{name}.json'))
            assert all(result[k]==v for k,v in parsed.items())
        results[name]=result;statuses[result['status']]+=1;times.append(result['elapsed_seconds'])
    _,status=select(calls,results)
    summary={'task':'frozen confirmation completion','new_requests':len(calls),'total_attempts':5+len(calls),
             'attempt_statuses_including_prior_failure':dict(statuses),'complete':status=='complete',
             'transport_timeout_seconds':120,'previous_timeout_seconds':60,'new_response_seconds':times,'first_receipt_reused_without_resending':True,
             'extraction_and_recovery_unchanged':True,'held_out_receipts':0,'app_changed':False}
    if status=='complete':
        for folder in (COMBINED,ADAPTED):(folder/'responses').mkdir(parents=True,mode=0o700,exist_ok=True)
        results['real-0-1']=trial.load(previous.OUT/'responses/real-0-1.json')
        for slot in (1,2):results[f'real-{slot}-1']=trial.load(resumed.OUT/'responses'/f'real-{slot}-1.json')
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
                                    'One provider 503 and one timeout are retained in reliability counts; timeout increased for the final two requests.'])
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
