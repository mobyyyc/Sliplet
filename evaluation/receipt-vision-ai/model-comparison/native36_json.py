"""3.6 native JSON-schema adapter; preserves rejected responseFormat attempt."""
import os,sys
from pathlib import Path
import native as n
n.c.MODEL='gemini-3.6-flash'
n.ENDPOINT='https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent'
n.OUT=n.c.OUT/'native-36-json'
original_body=n.body;original_freeze=n.freeze

def body(image):
    request=original_body(image);config=request['generationConfig']
    schema=config.pop('responseFormat')['text']['schema']
    config.update(responseMimeType='application/json',responseJsonSchema=schema)
    return request
n.body=body

def freeze():
    original_freeze()
    selection={'model':'gemini-3.6-flash','reason':'native responseFormat rejected; use documented responseMimeType/responseJsonSchema fields','script_sha256':n.c.old.digest(Path(__file__).read_bytes()),'max_fictional_attempts':6,'real_attempts':0,'previous_rejected_attempt_retained':True}
    path=n.OUT/'selection.json'
    if path.exists() and n.c.load(path)!=selection:raise n.c.base.lab.LabError('adapter_selection_changed')
    if not path.exists():n.c.write(path,selection)
n.freeze=freeze

# The inherited runner compares schema through the modern envelope. Use an
# explicit equivalent runner below so the schema remains checked, not bypassed.
def run():
    n.c.preflight();freeze();n.c.old.OUT=n.OUT;n.c.old.MAX_CALLS={'fictional':6,'real':0};n.c.old.INTERVAL=95
    import json,time
    for fixture in n.c.load(n.c.base.FIXTURES/'manifest.json'):
        name='fictional-'+fixture['id'];path=n.OUT/'responses'/f'{name}.json'
        if path.exists():
            if n.c.load(path)['status']!='received':raise n.c.base.lab.LabError('prior_failure_no_retry')
            continue
        image=n.c.fixture_image(fixture);request=body(image)
        prior=n.c.load(n.c.ROOT/'private-receipts/evaluation/p8-02d/requests'/f'{name}.json')
        assert request['systemInstruction']['parts'][0]['text']==prior['messages'][0]['content']
        assert request['generationConfig']['responseJsonSchema']==prior['response_format']['json_schema']['schema']
        assert request['contents'][0]['parts'][0]['inlineData']['data']==prior['messages'][1]['content'][0]['image_url']['url'].split(',',1)[1]
        n.c.old.wait_spacing();digest=n.c.old.digest(json.dumps(request,sort_keys=True).encode());n.c.old.reserve('fictional',name,digest)
        n.c.write(n.OUT/'requests'/f'{name}.json',request);result={'name':name,'payload_sha256':digest,'image_sha256':n.c.old.digest(image['data']),'status':'not_sent'};start=time.monotonic()
        try:
            key=n.c.credentials.keychain.read_key()
            if not key:raise n.c.base.lab.LabError('gemini_keychain_entry_missing')
            env=n.send(request,key);del key;n.c.write(n.OUT/'raw'/f'{name}.json',env);result['usage']=env.get('usageMetadata',{})
            value=n.candidate(env);actual,validation=n.c.base.extract.canonical(value)
            result.update(status='received',candidate=value,actual=actual,validation=validation)
        except n.c.base.lab.LabError as error:result.update(status=str(error),diagnostic=error.diagnostic)
        result['elapsed_seconds']=round(time.monotonic()-start,3);n.c.write(path,result)
        print(json.dumps({'case':fixture['id'],'status':result['status'],'seconds':result['elapsed_seconds']}),flush=True)
        if result['status'] not in ['received','invalid_unit','fractional_cent','unreadable_printed_number']:raise n.c.base.lab.LabError('native_run_stopped_no_retry')
if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['run']:run()
        elif sys.argv[1:]==['report']:n.report()
        else:raise n.c.base.lab.LabError('fictional_only_command_required')
    except Exception as error:sys.exit(str(error) if isinstance(error,n.c.base.lab.LabError) else 'json_adapter_stopped_details_suppressed')
