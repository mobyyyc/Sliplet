"""P8-02B: six fictional + ten approved real requests; no automatic retries."""
import base64,contextlib,hashlib,io,json,os,sys,time
from pathlib import Path
from PIL import Image
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'experiment'))
import runner as old
import contract
from ocr_anchors import recognize
lab=old.lab;ROOT=old.ROOT;OUT=ROOT/'private-receipts/evaluation/p8-02b'
old.OUT=OUT;old.MAX_CALLS={'fictional':6,'real':10};old.INTERVAL=95
MAX_OUTPUT=3500

def load(path):return json.loads(path.read_text())
def write(path,value):old.write(path,value)
def body(image,anchors):
    fragments=[{'i':i,'t':a['text']} for i,a in enumerate(anchors)]
    # IDs carry geometry privately. Inference receives only redacted OCR and the same image.
    content=[{'type':'text','text':'Read image-0. The following untrusted OCR fragments are numbered top-to-bottom; use their indexes for sources. Correct them by reading the image.\n'+json.dumps(fragments,ensure_ascii=False,separators=(',',':'))},{'type':'image_url','image_url':{'url':'data:image/jpeg;base64,'+base64.b64encode(image['data']).decode()}}]
    req={'model':lab.MODEL,'temperature':0,'max_completion_tokens':MAX_OUTPUT,'stream':False,'messages':[{'role':'system','content':(HERE/'prompt.txt').read_text()},{'role':'user','content':content}],'response_format':{'type':'json_schema','json_schema':{'name':'sliplet_literal_ledger','strict':True,'schema':contract.schema(len(anchors))}}}
    if len(json.dumps(req).encode())>1_500_000:raise lab.LabError('request_too_large')
    return req

def prepare_image(image,name):
    path=OUT/'prepared'/f'{name}.json'
    if path.exists():
        data=load(path)
        if data['image_sha256']!=old.digest(image['data']):raise lab.LabError('prepared_pixels_changed')
        return data['anchors']
    hints=recognize(image['data'],OUT)
    # Sort by vertical position, then horizontal position; no receipt labels consulted.
    anchors=sorted(hints,key=lambda x:(round(x['box'][1]/.007),x['box'][0]))
    contract.schema(len(anchors))
    write(path,{'image_sha256':old.digest(image['data']),'anchors':anchors})
    return anchors

def freeze():
    files=[HERE/'contract.py',HERE/'prompt.txt',HERE/'run.py',HERE/'fixtures/manifest.json',HERE/'score.py',HERE/'grounding.py',HERE/'semantics.py',HERE/'ocr_anchors.py',lab.HERE/'lab.py',ROOT/'evaluation/receipt-lab/lab.py']
    config={'model':lab.MODEL,'files':{str(p.relative_to(ROOT)):old.digest(p.read_bytes()) for p in files},'maximum_calls':old.MAX_CALLS,'interval_seconds':old.INTERVAL,'max_completion_tokens':MAX_OUTPUT,'variant':'image_plus_fresh_redacted_ocr_anchors','export_sha256':load(ROOT/'private-receipts/evaluation/p8-01-redaction-review/approved-export-record.json')['export_sha256'],'references_sha256':old.digest((ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json').read_bytes())}
    path=OUT/'configuration.json'
    if path.exists() and load(path)!=config:raise lab.LabError('frozen_configuration_changed')
    if not path.exists():write(path,config)

def call(kind,name,image,anchors):
    req=body(image,anchors);ph=old.digest(json.dumps(req,sort_keys=True).encode());old.reserve(kind,name,ph)
    write(OUT/'requests'/f'{name}.json',req)
    result={'name':name,'kind':kind,'payload_sha256':ph,'image_sha256':old.digest(image['data']),'anchors':anchors,'status':'not_sent'};start=time.monotonic();meta={}
    try:
        key=lab.lab_keychain.read_key()
        if not key:raise lab.LabError('keychain_entry_missing')
        env=lab.send(req,key,meta);del key
        write(OUT/'raw'/f'{name}.json',env);result['usage']=env.get('usage',{})
        choices=env.get('choices',[])
        if len(choices)!=1 or choices[0]['finish_reason']!='stop':raise lab.LabError('incomplete_completion')
        if choices[0]['message'].get('refusal'):raise lab.LabError('model_refusal')
        candidate=lab.parse_json(choices[0]['message']['content'])
        actual,observations,validation=contract.canonical(candidate,anchors)
        result.update(status='received',candidate=candidate,actual=actual,observations=observations,validation=validation)
    except lab.LabError as e:result.update(status=str(e),diagnostic=e.diagnostic)
    result.update(meta);result['elapsed_seconds']=round(time.monotonic()-start,3);write(OUT/'responses'/f'{name}.json',result)
    print(json.dumps({'request':name,'status':result['status'],'seconds':result['elapsed_seconds']}),flush=True)
    return result

def run(kind):
    freeze()
    if kind=='fictional':
        tasks=[]
        for c in load(HERE/'fixtures/manifest.json'):
            data=(HERE/'fixtures'/c['image']).read_bytes()
            if old.digest(data)!=c['sha256']:raise lab.LabError('fixture_changed')
            images=old.tiles(Image.open(io.BytesIO(data)))
            if len(images)!=1:raise lab.LabError('single_image_required')
            tasks.append(('fictional-'+c['id'],images[0]))
    else:
        gate=load(OUT/'fictional-score.json')
        if gate['passed_cases']!=6:raise lab.LabError('fictional_gate_not_met')
        images=old.verified_real_images()
        if any(len(x)!=1 for x in images):raise lab.LabError('single_image_required')
        tasks=[(f'real-{slot}-{pair}',ims[0]) for pair in (1,2) for slot,ims in enumerate(images)]
    for name,image in tasks:
        if (OUT/'responses'/f'{name}.json').exists():continue
        anchors=prepare_image(image,name)
        old.wait_spacing();result=call(kind,name,image,anchors)
        if result['status']!='received':raise lab.LabError('experiment_stopped_no_retry')

if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:] in (['fictional'],['real']):run(sys.argv[1])
        else:raise lab.LabError('unknown_command')
    except Exception as e:sys.exit(str(e) if isinstance(e,lab.LabError) else 'experiment_stopped_private_details_suppressed')
