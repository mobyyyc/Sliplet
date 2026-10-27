"""Five real receipts explicitly approved for Gemini Free on 2026-10-27."""
import contextlib,importlib.util,io,json,os,sys,time
from pathlib import Path
import diagnose_resolution as pilot
from report_resolution import decode
n=pilot.n
OUT=n.c.OUT/'real-five-01'

def freeze():
    n.c.preflight()
    files=[Path(__file__),Path(pilot.__file__),Path(n.__file__),Path(__file__).parent/'report_resolution.py',n.c.base.HERE/'score.py',n.c.base.HERE/'prompt.txt',n.c.base.HERE/'extract.py']
    config={'model':n.c.MODEL,'endpoint':n.ENDPOINT,'timeout_seconds':60,'max_attempts':5,'real_attempts':5,'authorization':'User explicitly approved actual receipts after Gemini free-tier disclosure on 2026-10-27','input':'existing reviewed redacted real copies; transaction content preserved','reference_sha256':n.c.old.digest((n.c.ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json').read_bytes()),'image_sha256':[n.c.old.digest(x[0]['data']) for x in n.c.old.verified_real_images()],'spacing_seconds':95,'retries':0,'pilot_reused_as_result':False,'files':{str(p.relative_to(n.c.ROOT)):n.c.old.digest(p.read_bytes()) for p in files}}
    path=OUT/'configuration.json'
    if path.exists() and n.c.load(path)!=config:raise n.c.base.lab.LabError('configuration_changed')
    if not path.exists():n.c.write(path,config)

def parse(envelope):
    choices=envelope.get('candidates',[])
    if len(choices)!=1 or choices[0].get('finishReason')!='STOP':raise n.c.base.lab.LabError('incomplete_or_blocked')
    text=''.join(p.get('text','') for p in choices[0]['content']['parts'] if not p.get('thought'))
    value,wrapped=decode(text)
    actual,validation=n.c.base.extract.canonical(value)
    return dict(candidate=value,actual=actual,validation=validation,outer_fence_removed=wrapped)

def run():
    freeze();n.c.old.OUT=OUT;n.c.old.MAX_CALLS={'fictional':0,'real':5};n.c.old.INTERVAL=95
    images=n.c.old.verified_real_images()
    if len(images)!=5 or any(len(x)!=1 for x in images):raise n.c.base.lab.LabError('five_whole_receipts_required')
    for slot,parts in enumerate(images):
        name=f'real-{slot}-1';path=OUT/'responses'/f'{name}.json'
        if path.exists():
            if n.c.load(path).get('diagnostic',{}).get('http_status') in [400,401,402,403,404,429]:return
            continue
        image=parts[0];request=pilot.body(image['data'],True)
        n.c.old.wait_spacing();digest=n.c.old.digest(json.dumps(request,sort_keys=True).encode())
        n.c.old.reserve('real',name,digest);n.c.write(OUT/'requests'/f'{name}.json',request)
        result={'case':slot+1,'payload_sha256':digest};start=time.monotonic()
        try:
            key=n.c.credentials.keychain.read_key()
            if not key:raise n.c.base.lab.LabError('key_missing')
            envelope=n.send(request,key);del key;n.c.write(OUT/'raw'/f'{name}.json',envelope)
            result['usage']=envelope.get('usageMetadata',{})
            result.update(parse(envelope),status='received')
        except n.c.base.lab.LabError as error:
            result.update(status=str(error),diagnostic=error.diagnostic)
        result['elapsed_seconds']=round(time.monotonic()-start,3);n.c.write(path,result)
        print(json.dumps({k:v for k,v in result.items() if k in ['case','status','diagnostic','elapsed_seconds','outer_fence_removed']}),flush=True)
        if result.get('diagnostic',{}).get('http_status') in [400,401,402,403,404,429]:return

if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['run']:run()
        else:raise n.c.base.lab.LabError('bounded_real_run_required')
    except Exception as error:
        sys.exit(str(error) if isinstance(error,n.c.base.lab.LabError) else 'comparison_stopped_private_details_suppressed')
