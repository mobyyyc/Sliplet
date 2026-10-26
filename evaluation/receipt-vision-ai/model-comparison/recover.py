"""One explicitly announced recovery for the first HTTP 503, retaining all evidence.
No general retry loop. At most seven total attempts for six fictional cases.
"""
import json,os,sys,time
import compare as c
FIRST='fictional-dense-coupons'
RETRY=FIRST+'-recovery'

def eligible(result):return result.get('status')=='provider_error' and result.get('diagnostic',{}).get('http_status')==503

def execute(name,fixture):
    image=c.fixture_image(fixture);request=c.body(image)
    prior=c.load(c.ROOT/'private-receipts/evaluation/p8-02d/requests'/('fictional-'+fixture['id']+'.json'));prior['model']=c.MODEL
    if request!=prior:raise c.base.lab.LabError('comparison_input_changed')
    c.old.wait_spacing();digest=c.old.digest(json.dumps(request,sort_keys=True).encode());c.old.reserve('fictional',name,digest)
    c.write(c.OUT/'requests'/f'{name}.json',request);result={'name':name,'payload_sha256':digest,'image_sha256':c.old.digest(image['data']),'status':'not_sent'};metadata={};start=time.monotonic()
    try:
        key=c.credentials.keychain.read_key()
        if not key:raise c.base.lab.LabError('gemini_keychain_entry_missing')
        env=c.transport.send(request,key,metadata);del key;c.write(c.OUT/'raw'/f'{name}.json',env);result['usage']=env.get('usage',{})
        choices=env.get('choices',[])
        if len(choices)!=1 or choices[0].get('finish_reason')!='stop':raise c.base.lab.LabError('incomplete_completion')
        if choices[0]['message'].get('refusal'):raise c.base.lab.LabError('model_refusal')
        candidate=c.base.lab.parse_json(choices[0]['message']['content']);actual,validation=c.base.extract.canonical(candidate)
        result.update(status='received',candidate=candidate,actual=actual,validation=validation)
    except (c.base.lab.LabError,c.transport.LabError) as e:result.update(status=str(e),diagnostic=e.diagnostic)
    result.update(metadata);result['elapsed_seconds']=round(time.monotonic()-start,3);c.write(c.OUT/'responses'/f'{name}.json',result)
    print(json.dumps({'attempt':name,'status':result['status'],'seconds':result['elapsed_seconds']}),flush=True)
    return result

def main():
    c.preflight();c.freeze()
    if not eligible(c.load(c.OUT/'responses'/f'{FIRST}.json')):raise c.base.lab.LabError('recovery_requires_initial_503')
    if (c.OUT/'responses'/f'{RETRY}.json').exists():raise c.base.lab.LabError('recovery_already_attempted')
    c.old.MAX_CALLS={'fictional':7,'real':0}
    c.write(c.OUT/'recovery-policy.json',{'reason':'single_announced_recovery_after_initial_503','initial_attempt_retained':True,'maximum_total_attempts':7,'maximum_recovery_attempts':1,'real_attempts':0,'script_sha256':c.old.digest(open(__file__,'rb').read())})
    fixtures=c.load(c.base.FIXTURES/'manifest.json')
    first=next(f for f in fixtures if 'fictional-'+f['id']==FIRST)
    result=execute(RETRY,first)
    if result['status']!='received':raise c.base.lab.LabError('recovery_failed_stop')
    for fixture in fixtures:
        name='fictional-'+fixture['id']
        if name==FIRST:continue
        if (c.OUT/'responses'/f'{name}.json').exists():raise c.base.lab.LabError('unexpected_existing_attempt')
        result=execute(name,fixture)
        if result['status'] not in {'received','unreadable_printed_number','fractional_cent','invalid_unit'}:raise c.base.lab.LabError('comparison_stopped_no_retry')
if __name__=='__main__':
    os.umask(0o077)
    try:main()
    except Exception as e:sys.exit(str(e) if isinstance(e,(c.base.lab.LabError,c.transport.LabError)) else 'recovery_stopped_details_suppressed')
