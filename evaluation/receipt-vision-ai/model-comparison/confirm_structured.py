"""Five-request prospective confirmation on the exposed corpus; no retuning.

The existing prompt, extraction and layout recovery are frozen before dispatch.
Previous fictional gates are reused only with their unchanged frozen source.
No new fictional/model-selection requests and no automatic retries.
"""
from collections import Counter
import copy
import json
import math
import os
from pathlib import Path
import sys
import time
import structured_trial as trial
import structured_layout_v2 as layout
import repair_reference as repair

OUT=trial.OUT.parent/'structured-confirmation-01'
ADAPTED=OUT/'adapted'
THRESHOLDS={'core_purchases_min':60,'expected_purchases':66,'exact_adjustments_min':8,
            'expected_adjustments':9,'correct_totals_min':5,'correct_dates_min':4,
            'usable_real_receipts':5}


def freeze():
    images=trial.freeze()
    previous=trial.load(trial.OUT/'summary.json')
    if previous.get('statuses')!={'received':7} or not previous.get('complete'):
        raise ValueError('prior_gate_incomplete')
    for name in ('fictional-dense-coupons','fictional-weighted'):
        if trial.load(trial.OUT/'responses'/f'{name}.json').get('fictional_pass') is not True:
            raise ValueError('fictional_gate_failed')
    files=[Path(__file__),Path(layout.__file__),Path(trial.__file__),Path(trial.extract.__file__),
           trial.HERE/'structured_prompt.txt',trial.HERE/'corrected_extract.py',
           trial.HERE/'repair_reference.py',trial.HERE/'duplicate_groups.py',
           trial.HERE/'native.py',trial.n.c.base.HERE/'extract.py',
           trial.HERE.parent/'correction/contract.py',trial.REFERENCE,
           trial.ROOT/'evaluation/receipt-lab/lab.py',trial.OUT/'configuration.json',
           trial.OUT/'summary.json',trial.OUT/'layout-replay-02/summary.json']
    files += [repair.audit.PRIVATE/f'p7-08-final/captures/capture-{i}-1.json' for i in range(5)]
    config={'task':'frozen structured confirmation','model':trial.n.c.MODEL,'endpoint':trial.n.ENDPOINT,
            'maximum_requests':5,'automatic_retries':0,'spacing_seconds':95,
            'timeout_seconds':trial.n.TIMEOUT,'thresholds':THRESHOLDS,
            'input':'same five complete images as structured-full-01; no OCR or reference answers in requests',
            'image_hashes':[trial.hash_bytes(image) for image in images],
            'files':{str(p.relative_to(trial.ROOT)):repair.digest(p) for p in files},
            'authorization':'User approved fresh bounded confirmation with current logic frozen before inference.',
            'scope':'exposed-corpus repeatability only; not held-out validation'}
    OUT.mkdir(parents=True,exist_ok=True,mode=0o700)
    repair.write_once(OUT/'configuration.json',config)
    return images


def calls():
    return trial.load(OUT/'calls.json') if (OUT/'calls.json').exists() else []


def choose_next(history,results):
    names=[c['name'] for c in history]
    allowed={f'real-{i}-1' for i in range(5)}
    if len(names)!=len(set(names)) or not set(names)<=allowed or len(names)>5:
        raise ValueError('invalid_request_inventory')
    if any(results.get(name,{}).get('status')!='received' for name in names):
        return None,'stopped_after_failed_or_interrupted_request'
    if len(names)==5:return None,'complete'
    return next(i for i in range(5) if f'real-{i}-1' not in names),'ready'


def next_call():
    images=freeze();history=calls()
    results={c['name']:trial.load(OUT/'responses'/f"{c['name']}.json") for c in history if (OUT/'responses'/f"{c['name']}.json").exists()}
    slot,status=choose_next(history,results)
    if slot is None:return {'status':status,'requests':len(history)}
    seconds=math.ceil(95-(time.time()-history[-1]['time'])) if history else 0
    if seconds>0:return {'status':'spacing','seconds':seconds,'requests':len(history)}
    trial.n.c.preflight()
    name=f'real-{slot}-1';request=trial.body(images[slot]);digest=trial.hash_bytes(json.dumps(request,sort_keys=True).encode())
    old=trial.n.c.old;old.OUT=OUT;old.MAX_CALLS={'real':5,'fictional':0};old.INTERVAL=95
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
    return {k:v for k,v in result.items() if k in ('name','status','elapsed_seconds','diagnostic')}


def acceptance(comparison):
    candidate=comparison['gemini'];core=candidate['core'];adj=candidate['adjustments'];fields=candidate['fields']
    return {'purchase_target':core['expected_purchases']==66 and core['core_correct_purchases_including_groups']>=60,
            'adjustment_benefit_repeated':adj['expected']==9 and adj['exact']>=8,
            'all_totals_correct':fields.get('total',{}).get('correct',0)==5,
            'date_result_retained':fields.get('date',{}).get('correct',0)>=4}


def score_folder(folder):
    previous=repair.audit.RUN
    try:
        repair.audit.RUN=folder
        return repair.evaluate(trial.load(trial.REFERENCE),repair.scorer())
    finally:repair.audit.RUN=previous


def report():
    images=freeze();history=calls();statuses=Counter();times=[];reviews=Counter();decoded_results={}
    ADAPTED.mkdir(mode=0o700,exist_ok=True);(ADAPTED/'responses').mkdir(mode=0o700,exist_ok=True)
    for call in history:
        name=call['name'];slot=int(name.split('-')[1]);request=trial.load(OUT/'requests'/f'{name}.json')
        result=trial.load(OUT/'responses'/f'{name}.json');decoded_results[name]=result
        assert request==trial.body(images[slot])
        assert call['payload_sha256']==result['payload_sha256']==trial.hash_bytes(json.dumps(request,sort_keys=True).encode())
        if result['status']=='received':
            parsed=trial.parse(trial.load(OUT/'raw'/f'{name}.json'))
            assert all(result[k]==v for k,v in parsed.items())
            actual,validation=layout.canonical(result['candidate'])
            adapted=copy.deepcopy(result);adapted.update(actual=actual,validation=validation,adapter_frozen_before_inference=True)
            repair.write_once(ADAPTED/'responses'/f'{name}.json',adapted)
            reviews['boundary_rows']+=len(validation['boundary_review'])
            reviews['receipts_with_boundary_review']+=bool(validation['boundary_review'])
            reviews['invalid_numeric_or_unit_fields']+=len(validation['invalid_fields'])
            reviews['receipts_requiring_review']+=validation['review_required']
        statuses[result['status']]+=1;times.append(result['elapsed_seconds'])
    _,status=choose_next(history,decoded_results)
    summary={'task':'frozen structured confirmation','requests':len(history),'statuses':dict(statuses),
             'complete':status=='complete','seconds':times,'review_flags':dict(reviews),
             'adapter_frozen_before_inference':True,'held_out_receipts':0,'app_changed':False}
    if status=='complete':
        raw,raw_ledger=score_folder(OUT);adapted,adapted_ledger=score_folder(ADAPTED)
        repair.write_once(OUT/'raw-score-ledger.json',raw_ledger);repair.write_once(OUT/'adapted-score-ledger.json',adapted_ledger)
        gates=acceptance(adapted)
        summary.update(raw_comparison=raw,adapted_comparison=adapted,gates=gates,all_gates_passed=all(gates.values()),
                       prior_adapted=trial.load(trial.OUT/'layout-replay-02/summary.json')['comparison']['gemini'],
                       limitations=['Same five exposed receipts, not independent held-out accuracy.',
                                    'Name boundaries reconstructed from model transcription still require review.',
                                    'Unreviewed quantity/unit-price/tax fields do not count as verified accuracy.'])
    trial.write(OUT/'summary.json',summary)
    return summary


if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['prepare']:freeze();result={'status':'frozen','new_requests':0}
        elif sys.argv[1:]==['next']:result=next_call()
        elif sys.argv[1:]==['report']:result=report()
        else:raise ValueError('explicit_command_required')
        print(json.dumps(result,indent=2))
    except Exception as error:
        sys.exit(str(error) if isinstance(error,trial.extract.lab.LabError) else 'confirmation_stopped_private_details_suppressed')
