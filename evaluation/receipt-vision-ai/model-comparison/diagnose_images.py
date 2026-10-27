"""Bounded fictional-only isolation of image input; never retries a case."""
import base64,io,json,os,sys,time
from pathlib import Path
from PIL import Image
import native as n
n.c.MODEL='gemini-3.6-flash'
n.ENDPOINT='https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent'
n.TIMEOUT=30
OUT=n.c.OUT/'image-diagnosis-01'

def body(data=None):
    parts=[{'text':'Reply with OK.'}]
    if data is not None:
        parts.insert(0,{'inlineData':{'mimeType':'image/jpeg','data':base64.b64encode(data).decode()}})
    return {'contents':[{'role':'user','parts':parts}],
            'generationConfig':{'maxOutputTokens':128,'thinkingConfig':{'thinkingLevel':'low'}}}

def requests():
    output=io.BytesIO()
    Image.new('RGB',(64,64),(32,96,160)).save(output,format='JPEG')
    tiny=output.getvalue()
    fixture=n.c.load(n.c.base.FIXTURES/'manifest.json')[0]
    receipt=n.c.fixture_image(fixture)['data']
    for data in [tiny,receipt]:
        with Image.open(io.BytesIO(data)) as image:
            assert image.format=='JPEG'
            image.verify()
    return [('text-control',body()),('tiny-image',body(tiny)),('receipt-image',body(receipt))]

def run():
    n.c.preflight()
    config={'model':n.c.MODEL,'max_attempts':3,'real_attempts':0,'timeout_seconds':30,
            'spacing_seconds':95,'automatic_retries':0,
            'files':{p.name:n.c.old.digest(p.read_bytes()) for p in [Path(__file__),Path(n.__file__)]}}
    path=OUT/'configuration.json'
    if path.exists() and n.c.load(path)!=config:raise n.c.base.lab.LabError('configuration_changed')
    if not path.exists():n.c.write(path,config)
    n.c.old.OUT=OUT;n.c.old.MAX_CALLS={'fictional':3,'real':0};n.c.old.INTERVAL=95
    for name,request in requests():
        path=OUT/'responses'/f'{name}.json'
        if path.exists():
            if n.c.load(path)['status']!='received':return
            continue
        n.c.old.wait_spacing()
        digest=n.c.old.digest(json.dumps(request,sort_keys=True).encode())
        n.c.old.reserve('fictional',name,digest)
        n.c.write(OUT/'requests'/f'{name}.json',request)
        start=time.monotonic();result={'case':name,'payload_sha256':digest}
        try:
            key=n.c.credentials.keychain.read_key()
            if not key:raise n.c.base.lab.LabError('key_missing')
            envelope=n.send(request,key);del key
            n.c.write(OUT/'raw'/f'{name}.json',envelope)
            candidates=envelope.get('candidates',[])
            stopped=len(candidates)==1 and candidates[0].get('finishReason')=='STOP'
            result['status']='received' if stopped else 'incomplete_or_blocked'
        except n.c.base.lab.LabError as error:
            result.update(status=str(error),diagnostic=error.diagnostic)
        result['elapsed_seconds']=round(time.monotonic()-start,3)
        n.c.write(path,result);print(json.dumps(result),flush=True)
        if result['status']!='received':return

if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['run']:run()
        else:raise n.c.base.lab.LabError('fictional_only_command_required')
    except Exception as error:
        sys.exit(str(error) if isinstance(error,n.c.base.lab.LabError) else 'diagnostic_stopped_details_suppressed')
