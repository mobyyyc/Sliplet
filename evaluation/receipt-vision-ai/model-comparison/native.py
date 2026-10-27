"""Approved P8-02E continuation: native stateless Gemini, six fictional cases only."""
import base64,contextlib,importlib.util,io,json,os,ssl,sys,time,urllib.request,urllib.error
from pathlib import Path
import compare as c
OUT=c.OUT/'native';ENDPOINT='https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent'
TIMEOUT=180;MAX_RESPONSE=262144

def body(image):
    previous=c.base.body(image)
    return {'systemInstruction':{'parts':[{'text':previous['messages'][0]['content']}]},'contents':[{'role':'user','parts':[{'inlineData':{'mimeType':'image/jpeg','data':base64.b64encode(image['data']).decode()}}]}],'generationConfig':{'maxOutputTokens':3500,'thinkingConfig':{'thinkingLevel':'low'},'responseFormat':{'text':{'mimeType':'APPLICATION_JSON','schema':previous['response_format']['json_schema']['schema']}}}}

def freeze():
    c.source_configuration()
    config={'task':'P8-02E-native','endpoint':ENDPOINT,'model':c.MODEL,'max_attempts':6,'real_attempts':0,'timeout_seconds':TIMEOUT,'thinking_level':'low','max_output_tokens':3500,'temperature':'omitted_per_Google_docs','spacing_seconds':95,'baseline_configuration_sha256':c.old.digest((c.ROOT/'private-receipts/evaluation/p8-02d/configuration.json').read_bytes()),'files':{str(p.relative_to(c.ROOT)):c.old.digest(p.read_bytes()) for p in [Path(__file__),c.HERE/'compare.py',c.HERE/'credentials.py',c.HERE.parent/'lab_keychain.py']}}
    path=OUT/'configuration.json'
    if path.exists() and c.load(path)!=config:raise c.base.lab.LabError('native_configuration_changed')
    if not path.exists():c.write(path,config)

def send(request,key):
    encoded=json.dumps(request).encode()
    if len(encoded)>1500000:raise c.base.lab.LabError('request_too_large')
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),c.base.lab.NoRedirect(),urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    req=urllib.request.Request(ENDPOINT,data=encoded,headers={'x-goog-api-key':key,'Content-Type':'application/json','Accept':'application/json','User-Agent':'SlipletReceiptLab/0.2'},method='POST')
    try:
        with opener.open(req,timeout=TIMEOUT) as response:raw=response.read(MAX_RESPONSE+1)
    except urllib.error.HTTPError as error:
        diagnostic={'http_status':error.code}
        try:
            obj=json.loads(error.read(16384));status=obj.get('error',{}).get('status')
            if status in ['INVALID_ARGUMENT','UNAUTHENTICATED','PERMISSION_DENIED','RESOURCE_EXHAUSTED','UNAVAILABLE','INTERNAL','NOT_FOUND']:diagnostic['provider_status']=status
        except Exception:pass
        raise c.base.lab.LabError(c.base.lab.http_state(error.code),diagnostic) from None
    except (urllib.error.URLError,TimeoutError,OSError):raise c.base.lab.LabError('network_or_timeout') from None
    if len(raw)>MAX_RESPONSE:raise c.base.lab.LabError('response_too_large')
    try:return c.base.lab.parse_json(raw.decode('utf-8'))
    except UnicodeError:raise c.base.lab.LabError('invalid_response_encoding') from None

def candidate(envelope):
    choices=envelope.get('candidates',[])
    if len(choices)!=1:raise c.base.lab.LabError('missing_or_blocked_candidate')
    choice=choices[0]
    if choice.get('finishReason')!='STOP':raise c.base.lab.LabError('incomplete_completion')
    parts=choice.get('content',{}).get('parts',[])
    text=''.join(p['text'] for p in parts if isinstance(p.get('text'),str) and not p.get('thought',False))
    if not text:raise c.base.lab.LabError('missing_candidate_text')
    return c.base.lab.parse_json(text)

def run():
    c.preflight();freeze();c.old.OUT=OUT;c.old.MAX_CALLS={'fictional':6,'real':0};c.old.INTERVAL=95
    for fixture in c.load(c.base.FIXTURES/'manifest.json'):
        name='fictional-'+fixture['id'];path=OUT/'responses'/f'{name}.json'
        if path.exists():
            if c.load(path)['status']!='received':raise c.base.lab.LabError('prior_native_failure_no_retry')
            continue
        image=c.fixture_image(fixture);request=body(image)
        prior=c.load(c.ROOT/'private-receipts/evaluation/p8-02d/requests'/f'{name}.json')
        assert request['systemInstruction']['parts'][0]['text']==prior['messages'][0]['content']
        assert request['generationConfig']['responseFormat']['text']['schema']==prior['response_format']['json_schema']['schema']
        assert request['contents'][0]['parts'][0]['inlineData']['data']==prior['messages'][1]['content'][0]['image_url']['url'].split(',',1)[1]
        c.old.wait_spacing();digest=c.old.digest(json.dumps(request,sort_keys=True).encode());c.old.reserve('fictional',name,digest)
        c.write(OUT/'requests'/f'{name}.json',request);result={'name':name,'payload_sha256':digest,'image_sha256':c.old.digest(image['data']),'status':'not_sent'};start=time.monotonic()
        try:
            key=c.credentials.keychain.read_key()
            if not key:raise c.base.lab.LabError('gemini_keychain_entry_missing')
            env=send(request,key);del key;c.write(OUT/'raw'/f'{name}.json',env);result['usage']=env.get('usageMetadata',{})
            value=candidate(env);actual,validation=c.base.extract.canonical(value)
            result.update(status='received',candidate=value,actual=actual,validation=validation)
        except c.base.lab.LabError as error:result.update(status=str(error),diagnostic=error.diagnostic)
        result['elapsed_seconds']=round(time.monotonic()-start,3);c.write(path,result)
        print(json.dumps({'case':fixture['id'],'status':result['status'],'seconds':result['elapsed_seconds']}),flush=True)
        if result['status'] not in ['received','invalid_unit','fractional_cent','unreadable_printed_number']:raise c.base.lab.LabError('native_run_stopped_no_retry')

def report():
    freeze();calls=c.load(OUT/'calls.json');assert len(calls)<=6 and len({x['name'] for x in calls})==len(calls)
    fixtures={x['id']:x for x in c.load(c.base.FIXTURES/'manifest.json')};statuses={}
    for call in calls:
        assert call['kind']=='fictional';name=call['name'];image=c.fixture_image(fixtures[name.removeprefix('fictional-')])
        request=c.load(OUT/'requests'/f'{name}.json');result=c.load(OUT/'responses'/f'{name}.json')
        assert request==body(image);assert call['payload_sha256']==result['payload_sha256']==c.old.digest(json.dumps(request,sort_keys=True).encode())
        if result['status']=='received':
            value=candidate(c.load(OUT/'raw'/f'{name}.json'));assert value==result['candidate']
            actual,validation=c.base.extract.canonical(value);assert actual==result['actual'] and validation==result['validation']
        statuses[result['status']]=statuses.get(result['status'],0)+1
    previous=c.base.OUT
    try:
        c.base.OUT=OUT
        spec=importlib.util.spec_from_file_location('unchanged_scorer',c.base.HERE/'score.py');scorer=importlib.util.module_from_spec(spec);spec.loader.exec_module(scorer)
        with contextlib.redirect_stdout(io.StringIO()):score=scorer.fictional()
    finally:c.base.OUT=previous
    baseline=c.load(c.ROOT/'private-receipts/evaluation/p8-02d/fictional-score.json')
    score.update(task='P8-02E-native',model=c.MODEL,baseline_exact=baseline['passed_cases'],attempt_statuses=statuses,previous_compatibility_attempts=2,real_uploads=0,comparison_complete=score['cases_run']==6 and all(x['status']=='received' for x in score['results']),configuration_differences=['native_endpoint','low_reasoning','temperature_omitted','180_second_timeout'])
    c.write(OUT/'comparison.json',score);c.write(OUT/'verification.json',{'verified':True,'requests_reproduced':True,'same_image_prompt_schema_scorer':True,'canonical_results_reproduced':True,'attempts':len(calls),'real_uploads':0})
    print(json.dumps({'cases_run':score['cases_run'],'fully_exact':score['passed_cases'],'baseline_exact':baseline['passed_cases'],'attempt_statuses':statuses,'comparison_complete':score['comparison_complete']}))
if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['run']:run()
        elif sys.argv[1:]==['report']:report()
        else:raise c.base.lab.LabError('fictional_only_command_required')
    except Exception as error:sys.exit(str(error) if isinstance(error,c.base.lab.LabError) else 'native_comparison_stopped_details_suppressed')
