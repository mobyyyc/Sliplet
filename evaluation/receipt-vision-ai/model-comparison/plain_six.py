"""Six approved fictional receipts; fixed plain-JSON prompt, no retries."""
import contextlib,importlib.util,io,json,os,sys,time
from pathlib import Path
import diagnose_resolution as pilot
from report_resolution import decode
n=pilot.n
OUT=n.c.OUT/'plain-six-01'

def freeze():
    n.c.preflight()
    files=[Path(__file__),Path(pilot.__file__),Path(n.__file__),Path(__file__).parent/'report_resolution.py',n.c.base.HERE/'score.py',n.c.base.HERE/'prompt.txt',n.c.base.HERE/'extract.py']
    config={'model':n.c.MODEL,'endpoint':n.ENDPOINT,'timeout_seconds':60,'max_attempts':6,'real_attempts':0,'spacing_seconds':95,'retries':0,'pilot_reused_as_result':False,'files':{str(p.relative_to(n.c.ROOT)):n.c.old.digest(p.read_bytes()) for p in files}}
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
    freeze();n.c.old.OUT=OUT;n.c.old.MAX_CALLS={'fictional':6,'real':0};n.c.old.INTERVAL=95
    for fixture in n.c.load(n.c.base.FIXTURES/'manifest.json'):
        name='fictional-'+fixture['id'];path=OUT/'responses'/f'{name}.json'
        if path.exists():
            if n.c.load(path).get('diagnostic',{}).get('http_status') in [400,401,402,403,404,429]:return
            continue
        image=n.c.fixture_image(fixture);request=pilot.body(image['data'],True)
        n.c.old.wait_spacing();digest=n.c.old.digest(json.dumps(request,sort_keys=True).encode())
        n.c.old.reserve('fictional',name,digest);n.c.write(OUT/'requests'/f'{name}.json',request)
        result={'case':fixture['id'],'payload_sha256':digest};start=time.monotonic()
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

def report():
    freeze();calls=n.c.load(OUT/'calls.json')
    assert len(calls)<=6 and len({c['name'] for c in calls})==len(calls)
    fixtures={f['id']:f for f in n.c.load(n.c.base.FIXTURES/'manifest.json')}
    timings=[];statuses={};wrapped=0
    for call in calls:
        assert call['kind']=='fictional'
        name=call['name'];fixture=fixtures[name.removeprefix('fictional-')]
        request=pilot.body(n.c.fixture_image(fixture)['data'],True)
        assert request==n.c.load(OUT/'requests'/f'{name}.json')
        result=n.c.load(OUT/'responses'/f'{name}.json')
        assert call['payload_sha256']==result['payload_sha256']==n.c.old.digest(json.dumps(request,sort_keys=True).encode())
        if result['status']=='received':
            replay=parse(n.c.load(OUT/'raw'/f'{name}.json'))
            for key,value in replay.items():assert result[key]==value
            wrapped+=result['outer_fence_removed'];timings.append(result['elapsed_seconds'])
        statuses[result['status']]=statuses.get(result['status'],0)+1
    previous=n.c.base.OUT
    try:
        n.c.base.OUT=OUT
        spec=importlib.util.spec_from_file_location('unchanged_scorer',n.c.base.HERE/'score.py')
        scorer=importlib.util.module_from_spec(spec);spec.loader.exec_module(scorer)
        with contextlib.redirect_stdout(io.StringIO()):score=scorer.fictional()
    finally:n.c.base.OUT=previous
    baseline=n.c.load(n.c.ROOT/'private-receipts/evaluation/p8-02d/fictional-score.json')
    score.update(task='P8-02E plain six',model=n.c.MODEL,baseline_exact=baseline['passed_cases'],attempt_statuses=statuses,real_uploads=0,comparison_complete=len(calls)==6 and statuses.get('received')==6,outer_fences_removed=wrapped,successful_request_seconds=timings,pilot_included=False)
    n.c.write(OUT/'comparison.json',score)
    n.c.write(OUT/'verification.json',{'verified':True,'requests_and_candidates_reproduced':True,'unchanged_reference_scorer':True,'attempts':len(calls),'real_uploads':0})
    print(json.dumps(score,indent=2))
    return score

if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['run']:run()
        elif sys.argv[1:]==['report']:report()
        else:raise n.c.base.lab.LabError('fictional_only_command_required')
    except Exception as error:
        sys.exit(str(error) if isinstance(error,n.c.base.lab.LabError) else 'comparison_stopped_details_suppressed')
