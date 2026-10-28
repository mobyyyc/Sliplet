"""Approved bounded image-only trial: two fictional gates, five full real photos.

One request per 'next' invocation, 95 seconds apart, no retries. No OCR or labels
in requests. Existing stateless Gemini transport and personal Keychain credential.
"""
import base64
from collections import Counter
import copy
import io
import json
import math
import os
from pathlib import Path
import sys
import time
from PIL import Image
import structured_extract as extract
import repair_reference as repair
import native as n

HERE=Path(__file__).resolve().parent
ROOT=repair.ROOT
OUT=repair.audit.PRIVATE/'p8-02e/structured-full-01'
REFERENCE=repair.RESULT/'reference-v4.json'
INTERVAL=95
CAP=6500
load=n.c.load
write=n.c.write
hash_bytes=n.c.old.digest


def body(data):
    prompt=(HERE/'structured_prompt.txt').read_text()+'\nFollow this JSON schema:\n'+json.dumps(extract.SCHEMA)
    return {'contents':[{'role':'user','parts':[{'inlineData':{'mimeType':'image/jpeg','data':base64.b64encode(data).decode()}},{'text':prompt}]}],
            'generationConfig':{'maxOutputTokens':CAP,'thinkingConfig':{'thinkingLevel':'low'}}}


def input_image(slot):
    path=repair.audit.PRIVATE/f'p8-01-redaction-review/receipt-{slot+1}-local.png'
    with Image.open(path) as original:
        image=original.convert('RGB')
        image.thumbnail((1200,1600),Image.Resampling.LANCZOS)
        buf=io.BytesIO();image.save(buf,format='JPEG',quality=95,subsampling=0)
    data=buf.getvalue()
    with Image.open(io.BytesIO(data)) as decoded:
        if decoded.getexif() or decoded.mode!='RGB':raise ValueError('unexpected_metadata_or_mode')
    if len(json.dumps(body(data)).encode())>1500000:raise ValueError('payload_size_exceeded')
    return data


def freeze():
    repair.audit.main()
    files=[Path(__file__),HERE/'structured_extract.py',HERE/'structured_prompt.txt',HERE/'corrected_extract.py',Path(n.__file__),REFERENCE,
           n.c.base.HERE/'extract.py',HERE.parent/'correction/contract.py',HERE/'duplicate_groups.py',ROOT/'evaluation/receipt-lab/lab.py']
    images=[input_image(slot) for slot in range(5)]
    config={'model':n.c.MODEL,'endpoint':n.ENDPOINT,'timeout_seconds':n.TIMEOUT,
            'maximum_requests':{'fictional':2,'real':5},'spacing_seconds':INTERVAL,'retries':0,
            'authorization':'User approved structured fields and bounded complete actual-receipt experiment after reference repair.',
            'input':'Complete original-local photos, whole-frame resize only, metadata-free JPEG, no redaction or OCR.',
            'max_output_tokens':CAP,'source_images':{str(p.relative_to(ROOT)):repair.digest(p) for p in [repair.audit.PRIVATE/f'p8-01-redaction-review/receipt-{i+1}-local.png' for i in range(5)]},
            'sent_images':[hash_bytes(x) for x in images],
            'files':{str(p.relative_to(ROOT)):repair.digest(p) for p in files}}
    OUT.mkdir(parents=True,exist_ok=True,mode=0o700)
    repair.write_once(OUT/'configuration.json',config)
    for slot,data in enumerate(images):
        path=OUT/f'input-{slot}.jpg'
        if path.exists():
            if path.read_bytes()!=data:raise ValueError('input_changed')
        else:path.write_bytes(data);path.chmod(0o600)
    return images


def parse(envelope):
    choices=envelope.get('candidates',[])
    if len(choices)!=1 or choices[0].get('finishReason')!='STOP':raise extract.lab.LabError('incomplete_or_blocked')
    text=''.join(p.get('text','') for p in choices[0].get('content',{}).get('parts',[]) if not p.get('thought')).strip()
    wrapped=text.startswith('```json\n') and text.endswith('```')
    if wrapped:text=text[8:-3]
    candidate=extract.lab.parse_json(text)
    actual,validation=extract.canonical(candidate)
    return {'candidate':candidate,'actual':actual,'validation':validation,'outer_fence_removed':wrapped}


def fictional_pass(actual,expected):
    # Fixed fixtures predate this trial; numeric/string exactness, no fuzzy names.
    def equal(a,b,key):
        if key in ('description','merchant'):
            return ' '.join((a or '').upper().split())==' '.join((b or '').upper().split())
        if key=='quantity':
            from decimal import Decimal
            return (Decimal(a) if a is not None else None)==(Decimal(b) if b is not None else None)
        return a==b
    return all(equal(actual.get(k),v,k) for k,v in expected.items() if k!='lines') and len(actual['lines'])==len(expected['lines']) and all(
        all(equal(a.get(k),v,k) for k,v in e.items()) for a,e in zip(actual['lines'],expected['lines']))


def next_call():
    images=freeze()
    fixtures=load(n.c.base.FIXTURES/'manifest.json')[:2]
    tasks=[('fictional','fictional-'+f['id'],n.c.fixture_image(f)['data'],f['expected']) for f in fixtures]
    tasks += [('real',f'real-{i}-1',image,None) for i,image in enumerate(images)]
    calls=load(OUT/'calls.json') if (OUT/'calls.json').exists() else []
    attempted={c['name'] for c in calls}
    for call in calls:
        path=OUT/'responses'/f"{call['name']}.json"
        if not path.exists():raise ValueError('interrupted_request_no_automatic_retry')
        result=load(path)
        if result.get('status')!='received':
            return {'status':'stopped_after_failure','requests':len(calls)}
        if call['kind']=='fictional' and not result.get('fictional_pass'):
            return {'status':'stopped_fictional_gate','requests':len(calls)}
    todo=next((t for t in tasks if t[1] not in attempted),None)
    if todo is None:return {'status':'complete','requests':len(calls)}
    remaining=math.ceil(INTERVAL-(time.time()-calls[-1]['time'])) if calls else 0
    if remaining>0:return {'status':'spacing','seconds':remaining,'requests':len(calls)}
    # Read key only when ready to send; no credential output or logging.
    n.c.preflight()
    kind,name,data,expected=todo
    request=body(data);digest=hash_bytes(json.dumps(request,sort_keys=True).encode())
    n.c.old.OUT=OUT;n.c.old.MAX_CALLS={'fictional':2,'real':5};n.c.old.INTERVAL=INTERVAL
    n.c.old.reserve(kind,name,digest);write(OUT/'requests'/f'{name}.json',request)
    result={'name':name,'payload_sha256':digest,'status':'not_sent'};start=time.monotonic()
    try:
        key=n.c.credentials.keychain.read_key()
        if not key:raise extract.lab.LabError('key_missing')
        try:envelope=n.send(request,key)
        finally:del key
        write(OUT/'raw'/f'{name}.json',envelope)
        result.update(parse(envelope),status='received',usage=envelope.get('usageMetadata',{}))
        if expected is not None:result['fictional_pass']=fictional_pass(result['actual'],expected)
    except extract.lab.LabError as error:
        result.update(status=str(error),diagnostic=error.diagnostic)
    result['elapsed_seconds']=round(time.monotonic()-start,3);write(OUT/'responses'/f'{name}.json',result)
    return {k:v for k,v in result.items() if k in ('name','status','fictional_pass','elapsed_seconds','diagnostic')}


def report():
    images=freeze();calls=load(OUT/'calls.json');statuses=Counter();latencies=[]
    fixtures=load(n.c.base.FIXTURES/'manifest.json')[:2]
    task_images={'fictional-'+f['id']:n.c.fixture_image(f)['data'] for f in fixtures}
    task_images.update({f'real-{i}-1':x for i,x in enumerate(images)})
    for call in calls:
        name=call['name'];result=load(OUT/'responses'/f'{name}.json');request=load(OUT/'requests'/f'{name}.json')
        assert request==body(task_images[name])
        assert call['payload_sha256']==result['payload_sha256']==hash_bytes(json.dumps(request,sort_keys=True).encode())
        if result['status']=='received':
            decoded=parse(load(OUT/'raw'/f'{name}.json'))
            assert all(result[k]==v for k,v in decoded.items())
        statuses[result['status']]+=1;latencies.append(result['elapsed_seconds'])
    real_calls=[c for c in calls if c['kind']=='real']
    summary={'task':'structured complete-image trial','requests':len(calls),'real_requests':len(real_calls),'statuses':dict(statuses),'seconds':latencies,
             'complete':len(real_calls)==5,'reference_version':'v4','held_out_receipts':0,'app_changed':False}
    if len(real_calls)==5 and all(load(OUT/'responses'/f"{c['name']}.json")['status']=='received' for c in real_calls):
        previous=repair.audit.RUN
        try:
            repair.audit.RUN=OUT
            totals,ledger=repair.evaluate(load(REFERENCE),repair.scorer())
        finally:repair.audit.RUN=previous
        summary['comparison']=totals
        write(OUT/'score-ledger.json',ledger)
        summary['prior_saved_gemini']=load(repair.RESULT/'comparison-summary.json')['revised_v4']['gemini']
        summary['caveat']='Prompt, schema and source visibility changed together; no isolated prompt-effect or unseen accuracy claim.'
    write(OUT/'summary.json',summary)
    return summary


if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['prepare']:
            freeze();result={'status':'prepared','images':5,'new_requests':0}
        elif sys.argv[1:]==['next']:result=next_call()
        elif sys.argv[1:]==['report']:result=report()
        else:raise ValueError('explicit_command_required')
        print(json.dumps(result,indent=2))
    except Exception as error:
        sys.exit(str(error) if isinstance(error,extract.lab.LabError) else 'structured_trial_stopped_private_details_suppressed')
