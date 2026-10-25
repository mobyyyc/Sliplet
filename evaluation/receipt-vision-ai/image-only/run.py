"""P8-02C whole-image experiment: six fictional, at most ten real, no retries."""
import base64,io,json,os,sys,time
from pathlib import Path
from PIL import Image
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'experiment'))
import runner as old
import extract
lab=old.lab;ROOT=old.ROOT;OUT=ROOT/'private-receipts/evaluation/p8-02c';FIXTURES=HERE.parent/'correction/fixtures'
old.OUT=OUT;old.MAX_CALLS={'fictional':6,'real':10};old.INTERVAL=95
load=old.load;write=old.write

def body(image):
    req={'model':lab.MODEL,'temperature':0,'max_completion_tokens':3500,'stream':False,'messages':[{'role':'system','content':(HERE/'prompt.txt').read_text()},{'role':'user','content':[{'type':'image_url','image_url':{'url':'data:image/jpeg;base64,'+base64.b64encode(image['data']).decode()}}]}],'response_format':{'type':'json_schema','json_schema':{'name':'receipt_fields','strict':True,'schema':extract.SCHEMA}}}
    if len(json.dumps(req).encode())>1500000:raise lab.LabError('request_too_large')
    return req

def freeze():
    files=[HERE/n for n in ['run.py','extract.py','prompt.txt','score.py']]+[HERE.parent/'correction/contract.py',FIXTURES/'manifest.json',lab.HERE/'lab.py',ROOT/'evaluation/receipt-lab/lab.py']
    config={'model':lab.MODEL,'files':{str(p.relative_to(ROOT)):old.digest(p.read_bytes()) for p in files},'reference_sha256':old.digest((ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json').read_bytes()),'approval_sha256':load(ROOT/'private-receipts/evaluation/p8-01-redaction-review/approved-export-record.json')['export_sha256'],'maximum_calls':old.MAX_CALLS,'interval_seconds':95,'max_completion_tokens':3500,'input':'one_full_image_no_ocr','source_coordinates':False,'scoring':'unique_kind_description_without_amount_or_geometry_for_both_candidates_and_baseline'}
    path=OUT/'configuration.json'
    if path.exists() and load(path)!=config:raise lab.LabError('frozen_configuration_changed')
    if not path.exists():write(path,config)

def call(kind,name,image):
    req=body(image);digest=old.digest(json.dumps(req,sort_keys=True).encode());old.reserve(kind,name,digest);write(OUT/'requests'/f'{name}.json',req)
    start=time.monotonic();meta={};result={'name':name,'status':'not_sent','payload_sha256':digest,'image_sha256':old.digest(image['data'])}
    try:
        key=lab.lab_keychain.read_key()
        if not key:raise lab.LabError('keychain_entry_missing')
        env=lab.send(req,key,meta);del key;write(OUT/'raw'/f'{name}.json',env);result['usage']=env.get('usage',{})
        choices=env.get('choices',[])
        if len(choices)!=1 or choices[0]['finish_reason']!='stop':raise lab.LabError('incomplete_completion')
        if choices[0]['message'].get('refusal'):raise lab.LabError('model_refusal')
        candidate=lab.parse_json(choices[0]['message']['content']);actual,validation=extract.canonical(candidate)
        result.update(status='received',candidate=candidate,actual=actual,validation=validation)
    except lab.LabError as e:result.update(status=str(e),diagnostic=e.diagnostic)
    result.update(meta);result['elapsed_seconds']=round(time.monotonic()-start,3);write(OUT/'responses'/f'{name}.json',result)
    print(json.dumps({'request':name,'status':result['status'],'seconds':result['elapsed_seconds']}),flush=True);return result

def run(kind):
    freeze();tasks=[]
    if kind=='fictional':
        for fixture in load(FIXTURES/'manifest.json'):
            data=(FIXTURES/fixture['image']).read_bytes()
            if old.digest(data)!=fixture['sha256']:raise lab.LabError('fixture_changed')
            images=old.tiles(Image.open(io.BytesIO(data)))
            if len(images)!=1:raise lab.LabError('full_image_required')
            tasks.append(('fictional-'+fixture['id'],images[0]))
    else:
        if load(OUT/'fictional-score.json')['passed_cases']!=6:raise lab.LabError('fictional_gate_failed')
        images=old.verified_real_images()
        if any(len(ims)!=1 for ims in images):raise lab.LabError('full_image_required')
        tasks=[(f'real-{slot}-{pair}',ims[0]) for pair in (1,2) for slot,ims in enumerate(images)]
    for name,image in tasks:
        path=OUT/'responses'/f'{name}.json'
        if path.exists():
            if load(path)['status']!='received':raise lab.LabError('previous_failure_no_automatic_resume')
            continue
        old.wait_spacing();result=call(kind,name,image)
        if result['status']!='received':raise lab.LabError('experiment_stopped_no_retry')
if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:] in (['fictional'],['real']):run(sys.argv[1])
        else:raise lab.LabError('unknown_command')
    except Exception as e:sys.exit(str(e) if isinstance(e,lab.LabError) else 'experiment_stopped_private_details_suppressed')
