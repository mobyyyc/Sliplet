"""P8-02E: six fixed fictional images only; unchanged prompt and score."""
import copy,contextlib,hashlib,importlib.util,io,json,os,sys,time
from pathlib import Path
from PIL import Image
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'image-only-refined'))
import run as base
import credentials
ROOT=base.ROOT;OUT=credentials.OUT
MODEL='gemini-3.8-flash'
ENDPOINT='https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'
spec=importlib.util.spec_from_file_location('gemini_transport',HERE.parent/'lab.py')
transport=importlib.util.module_from_spec(spec);spec.loader.exec_module(transport)
transport.ENDPOINT=ENDPOINT
old=base.old;old.OUT=OUT;old.MAX_CALLS={'fictional':6,'real':0};old.INTERVAL=95
load=old.load;write=old.write

def source_configuration():
    config=load(ROOT/'private-receipts/evaluation/p8-02d/configuration.json')
    for name,digest in config['files'].items():
        if old.digest((ROOT/name).read_bytes())!=digest:raise base.lab.LabError('baseline_configuration_changed')
    return config

def fixture_image(fixture):
    data=(base.FIXTURES/fixture['image']).read_bytes()
    if old.digest(data)!=fixture['sha256']:raise base.lab.LabError('fixture_changed')
    ims=old.tiles(Image.open(io.BytesIO(data)))
    if len(ims)!=1:raise base.lab.LabError('whole_image_required')
    return ims[0]

def body(image):
    result=copy.deepcopy(base.body(image));result['model']=MODEL
    return result

def freeze():
    original=source_configuration()
    config={'task':'P8-02E','model':MODEL,'endpoint':ENDPOINT,'baseline_model':original['model'],'baseline_configuration_sha256':old.digest((ROOT/'private-receipts/evaluation/p8-02d/configuration.json').read_bytes()),'files':{str(p.relative_to(ROOT)):old.digest(p.read_bytes()) for p in [Path(__file__),HERE/'credentials.py',HERE.parent/'lab_keychain.py',HERE.parent/'lab.py']},'maximum_calls':{'fictional':6,'real':0},'interval_seconds':95,'max_completion_tokens':3500,'request_difference':'model only; provider endpoint and credential differ','reasoning':'provider default, not assumed equivalent','real_receipts_permitted':False}
    path=OUT/'configuration.json'
    if path.exists() and load(path)!=config:raise base.lab.LabError('frozen_configuration_changed')
    if not path.exists():write(path,config)

def preflight():
    marker=OUT/'account-confirmation.json'
    if not marker.exists() or load(marker).get('free_tier_billing_disabled_user_confirmed') is not True:raise base.lab.LabError('free_account_confirmation_required')
    if not credentials.keychain.read_key():raise base.lab.LabError('gemini_keychain_entry_missing')
    source_configuration()

def run():
    preflight();freeze()
    for fixture in load(base.FIXTURES/'manifest.json'):
        name='fictional-'+fixture['id'];path=OUT/'responses'/f'{name}.json'
        if path.exists():
            if load(path)['status']!='received':raise base.lab.LabError('prior_failure_no_automatic_resume')
            continue
        image=fixture_image(fixture);request=body(image)
        # Exact historical request minus model: no hidden preprocessing or extra instructions.
        previous=load(ROOT/'private-receipts/evaluation/p8-02d/requests'/f'{name}.json');previous['model']=MODEL
        if request!=previous:raise base.lab.LabError('comparison_input_changed')
        old.wait_spacing();digest=old.digest(json.dumps(request,sort_keys=True).encode());old.reserve('fictional',name,digest)
        write(OUT/'requests'/f'{name}.json',request);result={'name':name,'payload_sha256':digest,'image_sha256':old.digest(image['data']),'status':'not_sent'};metadata={};start=time.monotonic()
        try:
            key=credentials.keychain.read_key()
            if not key:raise base.lab.LabError('gemini_keychain_entry_missing')
            env=transport.send(request,key,metadata);del key
            write(OUT/'raw'/f'{name}.json',env);result['usage']=env.get('usage',{})
            choices=env.get('choices',[])
            if len(choices)!=1 or choices[0].get('finish_reason')!='stop':raise base.lab.LabError('incomplete_completion')
            if choices[0]['message'].get('refusal'):raise base.lab.LabError('model_refusal')
            candidate=base.lab.parse_json(choices[0]['message']['content']);actual,validation=base.extract.canonical(candidate)
            result.update(status='received',candidate=candidate,actual=actual,validation=validation)
        except base.lab.LabError as error:result.update(status=str(error),diagnostic=error.diagnostic)
        # Separate import of the same transport defines a separate exception class.
        except transport.LabError as error:result.update(status=str(error),diagnostic=error.diagnostic)
        result.update(metadata);result['elapsed_seconds']=round(time.monotonic()-start,3);write(path,result)
        print(json.dumps({'case':fixture['id'],'status':result['status'],'seconds':result['elapsed_seconds']}),flush=True)
        if result['status'] not in {'received','unreadable_printed_number','fractional_cent','invalid_unit'}:raise base.lab.LabError('comparison_stopped_no_retry')

def score():
    spec=importlib.util.spec_from_file_location('fixed_scorer',base.HERE/'score.py');scorer=importlib.util.module_from_spec(spec);spec.loader.exec_module(scorer)
    previous_out=base.OUT
    try:
        base.OUT=OUT
        with contextlib.redirect_stdout(io.StringIO()):result=scorer.fictional()
    finally:base.OUT=previous_out
    result['task']='P8-02E';result['model']=MODEL
    baseline=load(ROOT/'private-receipts/evaluation/p8-02d/fictional-score.json')
    result['baseline']={'model':'qwen/qwen3.8-27b','passed_cases':baseline['passed_cases'],'cases_run':baseline['cases_run']}
    result['real_uploads']=0;result['same_prompt_schema_images_and_scorer']=True
    write(OUT/'fictional-score.json',result)
    print(json.dumps({'cases_run':result['cases_run'],'passed':result['passed_cases'],'baseline_passed':baseline['passed_cases'],'statuses':[{'case':x['case'],'status':x['status'],'exact':x['exact']} for x in result['results']]}));return result

if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['run']:run()
        elif sys.argv[1:]==['score']:score()
        elif sys.argv[1:]==['preflight']:preflight();print('Gemini key saved; free-tier confirmation present; inference not yet tested.')
        else:raise base.lab.LabError('fictional_only_command_required')
    except Exception as error:sys.exit(str(error) if isinstance(error,(base.lab.LabError,transport.LabError)) else 'comparison_stopped_details_suppressed')
