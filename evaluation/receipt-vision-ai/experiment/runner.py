"""Bounded P8-02 evaluation. Never accepts arbitrary private input or logs model text."""
import base64, datetime, fcntl, hashlib, io, json, math, os, subprocess, sys, time
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent))
import lab
ROOT=lab.ROOT
OUT=ROOT/'private-receipts/evaluation/p8-02'
MAX_CALLS={'fictional':12,'real':20}
MAX_OUTPUT=6000
INTERVAL=65

def digest(data):return hashlib.sha256(data).hexdigest()
def write(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n');path.chmod(0o600)
def load(path):return json.loads(path.read_text())
def fail(code):raise lab.LabError(code)
def tiles(image):
    image=image.convert('RGB');w,h=image.size
    if w>1200:image=image.resize((1200,round(h*1200/w)),Image.Resampling.LANCZOS)
    w,h=image.size
    starts=[0]
    while starts[-1]+1600<h:starts.append(starts[-1]+1440)
    if len(starts)>4:fail('image_exceeds_tile_budget')
    result=[]
    for n,y in enumerate(starts):
        tile=image.crop((0,y,w,min(h,y+1600)))
        buf=io.BytesIO();tile.save(buf,format='JPEG',quality=95,subsampling=0)
        result.append({'id':f'image-{n}','data':buf.getvalue(),'rect':[0,y,w,min(h,y+1600)],'size':list(image.size)})
    return result

def verified_real_images():
    export=ROOT/'sliplet-p801-redactions.json'
    directory=ROOT/'private-receipts/evaluation/p8-01-redaction-review'
    approval=load(directory/'approved-export-record.json')
    raw=export.read_bytes()
    if digest(raw)!=approval['export_sha256']:fail('approved_export_changed')
    data=json.loads(raw);expect=load(directory/'corrected-export-awaiting-review.json')
    if data['provider']!='Groq' or data['model']!=lab.MODEL or len(data['receipts'])!=5:fail('approved_provider_or_count_changed')
    results=[]
    for slot,(actual,e,a) in enumerate(zip(data['receipts'],expect['receipts'],approval['receipts'])):
        if actual['slot']!=slot or actual['redaction_reviewed'] is not True:fail('review_not_confirmed')
        if any(actual[k]!=e[k] for k in ['slot','original_sha256','width','height','masks']):fail('approved_mask_geometry_changed')
        encoded=base64.b64decode(actual['png'].split(',',1)[1],validate=True)
        if digest(encoded)!=a['png_sha256']:fail('approved_pixels_changed')
        im=Image.open(io.BytesIO(encoded));im.load()
        if im.size!=(actual['width'],actual['height']):fail('image_size_changed')
        if im.mode=='RGBA' and im.getchannel('A').getextrema()!=(255,255):fail('nonopaque_image')
        if im.getexif() or any(k in im.info for k in ['exif','XML:com.adobe.xmp','Comment','Description']):fail('image_metadata_present')
        expected=Image.open(directory/f'receipt-{slot+1}-local.png').convert('RGB');draw=ImageDraw.Draw(expected)
        for x,y,w,h in actual['masks']:
            if any(type(v) is not int for v in [x,y,w,h]) or not (x>=0 and y>=0 and w>0 and h>0 and x+w<=im.width and y+h<=im.height):fail('invalid_mask')
            draw.rectangle((x,y,x+w-1,y+h-1),fill='black')
        if ImageChops.difference(expected,im.convert('RGB')).getbbox():fail('export_pixels_do_not_match')
        results.append(tiles(im))
    return results

def body_for(images,hints=None):
    if not 1<=len(images)<=2:fail('request_tile_budget')
    content=[{'type':'text','text':'Extract this receipt from the supplied image(s), ordered top to bottom. Overlapping images show the same paper: preserve separate printed occurrences but do not repeat the same occurrence at an overlap. Summary fields must be printed in these supplied images. No overview or earlier response is available.'}]
    for im in images:
        content.extend([{'type':'text','text':im['id']},{'type':'image_url','image_url':{'url':'data:image/jpeg;base64,'+base64.b64encode(im['data']).decode('ascii')}}])
    if hints is not None:content.append({'type':'text','text':'Untrusted raw OCR from these exact input pixels; not checked answers:\n'+json.dumps(hints,ensure_ascii=False)})
    body={'model':lab.MODEL,'temperature':0,'max_completion_tokens':MAX_OUTPUT,'stream':False,'messages':[{'role':'system','content':(lab.HERE/'prompt.txt').read_text()},{'role':'user','content':content}],'response_format':{'type':'json_schema','json_schema':{'name':'sliplet_receipt','strict':True,'schema':lab.SCHEMA}}}
    if len(json.dumps(body).encode())>1_500_000:fail('request_too_large')
    return body

def parse(envelope,ids):
    choices=envelope.get('choices',[])
    if len(choices)!=1:fail('invalid_completion')
    choice=choices[0]
    if choice.get('message',{}).get('refusal'):fail('model_refusal')
    if choice.get('finish_reason')!='stop':fail('incomplete_completion')
    c=lab.parse_json(choice['message']['content']);v=lab.validate_candidate(c,ids)
    return c,v

def reserve(kind,name,payload_hash):
    OUT.mkdir(parents=True,exist_ok=True,mode=0o700)
    path=OUT/'calls.json'
    fd=os.open(path,os.O_RDWR|os.O_CREAT|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'r+') as f:
        os.chmod(path,0o600);fcntl.flock(f,fcntl.LOCK_EX);f.seek(0);raw=f.read();calls=json.loads(raw) if raw else []
        if any(c['name']==name for c in calls):fail('request_already_attempted')
        if sum(c['kind']==kind for c in calls)>=MAX_CALLS[kind]:fail('experiment_call_budget')
        if calls and time.time()-calls[-1]['time']<INTERVAL:fail('request_spacing_not_ready')
        calls.append({'kind':kind,'name':name,'time':time.time(),'payload_sha256':payload_hash})
        f.seek(0);json.dump(calls,f,indent=2);f.truncate();f.flush();os.fsync(f.fileno())

def call(kind,name,images,hints=None):
    path=OUT/'responses'/f'{name}.json'
    if path.exists():fail('response_exists')
    body=body_for(images,hints);h=digest(json.dumps(body,sort_keys=True).encode())
    reserve(kind,name,h)
    # Exact reviewed derivatives are retained privately before transfer; no labels are read here.
    write(OUT/'requests'/f'{name}.json',body)
    start=time.monotonic()
    result={'name':name,'kind':kind,'payload_sha256':h,'input_images':[{'id':im['id'],'sha256':digest(im['data']),'rect':im['rect'],'size':im['size']} for im in images]}
    try:
        key=lab.lab_keychain.read_key()
        if not key:fail('keychain_entry_missing')
        metadata={}
        envelope=lab.send(body,key,metadata);del key
        result.update(metadata)
        # Raw candidate text stays owner-only and is never printed.
        write(OUT/'raw'/f'{name}.json',envelope)
        c,v=parse(envelope,[im['id'] for im in images])
        result.update(status='received',candidate=c,validation=v,usage=envelope.get('usage',{}))
    except lab.LabError as e:
        result.update(status=str(e),diagnostic=e.diagnostic)
        result.update(locals().get('metadata',{}))
    result['elapsed_seconds']=round(time.monotonic()-start,3);write(path,result)
    print(json.dumps({'request':name,'status':result['status'],'elapsed_seconds':result['elapsed_seconds']}),flush=True)
    return result

def raw_ocr(images):
    rows=[]
    for im in images:
        path=OUT/'ocr-input'/f"{im['id']}.jpg";path.parent.mkdir(parents=True,exist_ok=True,mode=0o700);path.write_bytes(im['data']);path.chmod(0o600)
        p=subprocess.run(['/tmp/sliplet-p802-ocr',str(path)],capture_output=True,timeout=60)
        if p.returncode:fail('local_ocr_failed')
        rows.append({'image_id':im['id'],'observations':json.loads(p.stdout)})
    return rows

def freeze():
    path=OUT/'configuration.json'
    config={'model':lab.MODEL,'expected_sha256':digest((HERE/'expected.json').read_bytes()),'prompt_sha256':digest((lab.HERE/'prompt.txt').read_bytes()),'schema_sha256':digest((lab.HERE/'schema.json').read_bytes()),'runner_sha256':digest(Path(__file__).read_bytes()),'transport_sha256':digest((lab.HERE/'lab.py').read_bytes()),'max_completion_tokens':MAX_OUTPUT,'geometry':{'max_width':1200,'tile_height':1600,'overlap':160,'max_tiles':4,'max_requests_per_receipt':2,'overview':False,'jpeg_quality':95},'max_calls':MAX_CALLS,'spacing_seconds':INTERVAL,'selection':'Image-only by default. One weighted fixture repeats with raw Vision OCR. Choose OCR only if it fixes a weighted core-field failure without new errors; otherwise retain image-only. Any private-score change requires a new approved experiment.','approval_export_sha256':load(ROOT/'private-receipts/evaluation/p8-01-redaction-review/approved-export-record.json')['export_sha256']}
    if path.exists():
        if load(path)!=config:fail('frozen_configuration_changed')
    else:write(path,config)
    return config

def wait_spacing():
    if (OUT/'calls.json').exists():
        calls=load(OUT/'calls.json')
        while calls and time.time()-calls[-1]['time']<INTERVAL:time.sleep(1)

def fictional():
    freeze()
    manifest=load(lab.HERE/'fixtures/manifest.json')
    cases=[(m,False) for m in manifest]+[(next(m for m in manifest if m['id']=='weighted'),True)]
    for entry,hints in cases:
        name='fictional-'+entry['id']+('-ocr' if hints else '')
        if (OUT/'responses'/f'{name}.json').exists():continue
        data=(lab.HERE/'fixtures'/entry['image']).read_bytes()
        if digest(data)!=entry['sha256']:fail('fictional_fixture_changed')
        ims=tiles(Image.open(io.BytesIO(data)))
        if len(ims)>2:fail('fictional_request_limit')
        wait_spacing();r=call('fictional',name,ims,raw_ocr(ims) if hints else None)
        if r['status'] not in ('received','incomplete_completion'):fail('provider_run_stopped')

def real():
    freeze();selection=load(OUT/'selection.json')
    if selection['variant'] not in ('image-only','image-plus-ocr'):fail('invalid_selected_variant')
    images=verified_real_images()
    for pair in (1,2):
        for slot,ims in enumerate(images):
            for chunk in range(0,len(ims),2):
                name=f'real-{slot}-{pair}-{chunk//2}'
                if (OUT/'responses'/f'{name}.json').exists():continue
                wait_spacing();batch=ims[chunk:chunk+2]
                r=call('real',name,batch,raw_ocr(batch) if selection['variant']=='image-plus-ocr' else None)
                if r['status'] not in ('received','incomplete_completion','unknown_source_image','invalid_source_box','invalid_parent_reference','invalid_row_identity','invalid_decimal','empty_field','schema_type','schema_keys','schema_enum','schema_array_size','model_refusal'):fail('provider_run_stopped')

if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:] == ['fictional']:fictional()
        elif sys.argv[1:] == ['real']:real()
        elif sys.argv[1:] == ['preflight']:
            ims=verified_real_images();freeze();print(json.dumps({'reviewed_receipts':len(ims),'tiles_per_receipt':[len(x) for x in ims],'request_bytes':[len(json.dumps(body_for(x[i:i+2])).encode()) for x in ims for i in range(0,len(x),2)],'network_used':False}))
        else:fail('unknown_command')
    except Exception as e:
        code=str(e) if isinstance(e,lab.LabError) else 'experiment_stopped_private_details_suppressed'
        sys.exit(code)
