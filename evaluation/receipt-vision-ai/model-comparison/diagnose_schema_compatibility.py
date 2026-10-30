"""Approved six-call maximum, fictional-only schema isolation. Never retries.

95-second start spacing; stop on transport/auth/quota failures. HTTP 400 may
advance to a different predeclared diagnostic. No model or production changes.
"""
import copy, hashlib, json, math, os, ssl, sys, time, urllib.error, urllib.request
from pathlib import Path
from credentials import keychain
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'private-receipts/evaluation/p8-07-schema-isolation-01'
FIXTURE=ROOT/'private-receipts/evaluation/p8-07-structured-03/fictional-request.json'
MODEL='gemini-3.6-flash'
ENDPOINT='https://generativelanguage.googleapis.com/v1beta/models/'+MODEL+':generateContent'

def load(p):return json.loads(p.read_text())
def write(p,value):
    p.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    p.write_text(json.dumps(value,indent=2)+'\n');p.chmod(0o600)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def freeze():
    value={'model':MODEL,'endpoint':ENDPOINT,'maximum_calls':6,'spacing_seconds':95,'timeout_seconds':120,'retries':0,'fictional_only':True,'files':{str(p.relative_to(ROOT)):digest(p) for p in (Path(__file__),FIXTURE)}}
    if (OUT/'configuration.json').exists():
        if load(OUT/'configuration.json')!=value:raise RuntimeError('changed_configuration')
    else:write(OUT/'configuration.json',value)

MINIMAL={'type':'OBJECT','properties':{'merchant':{'type':'STRING'}},'required':['merchant']}
PROMPT='Fictional receipt: merchant SLIPLET TEST; one purchase TEST APPLES for 1.00; total 1.00. Return only JSON following the supplied schema. Unknown date is null.'

def choose(results):
    if len(results)>=6:return None
    if any(r['status'] not in ('received','provider_error') or (r['status']=='provider_error' and r.get('http_status')!=400) for r in results):return None
    ids=[r['case'] for r in results]
    if not ids:return 'minimal_with_thinking'
    if results[0].get('passed'):
        ladder=['nullable','enum_rows','full_schema_text','full_schema_image']
        if all(r.get('passed') for r in results):return ladder[len(results)-1] if len(results)<=len(ladder) else None
        return 'minimal_without_thinking' if 'minimal_without_thinking' not in ids else None
    # Basic schema failure: distinguish representation, thinking and JSON mode.
    diagnostics=['minimal_without_thinking','json_schema_minimal','response_format_minimal','json_only_control','plain_control']
    return diagnostics[len(results)-1] if len(results)<=len(diagnostics) else None

def request(case):
    fixture=load(FIXTURE)
    config={'maxOutputTokens':512}
    schema=copy.deepcopy(MINIMAL)
    if case=='nullable':schema['properties']['date']={'type':'STRING','nullable':True};schema['required'].append('date')
    if case=='enum_rows':
        schema['properties']['rows']={'type':'ARRAY','maxItems':3,'items':{'type':'OBJECT','properties':{'kind':{'type':'STRING','enum':['purchase','tax']},'amount':{'type':'STRING','nullable':True}},'required':['kind','amount']}}
        schema['required'].append('rows')
    if case in ('full_schema_text','full_schema_image'):
        schema=fixture['generationConfig']['responseSchema'];config['maxOutputTokens']=6500
    if case in ('minimal_with_thinking','nullable','enum_rows','full_schema_text','full_schema_image'):config['thinkingConfig']={'thinkingLevel':'low'}
    if case=='json_schema_minimal':
        config.update(responseMimeType='application/json',responseJsonSchema={'type':'object','properties':{'merchant':{'type':'string'}},'required':['merchant'],'additionalProperties':False})
    elif case=='response_format_minimal':
        config['responseFormat']={'text':{'mimeType':'APPLICATION_JSON','schema':{'type':'object','properties':{'merchant':{'type':'string'}},'required':['merchant'],'additionalProperties':False}}}
    elif case=='json_only_control':config['responseMimeType']='application/json'
    elif case!='plain_control':config.update(responseMimeType='application/json',responseSchema=schema)
    prompt=PROMPT if case in ('nullable','enum_rows','full_schema_text') else 'Return exactly this JSON object: {"merchant":"SLIPLET TEST"}. This is fictional test data.'
    if case=='full_schema_text':prompt += '\nFollow this schema: '+json.dumps(schema)
    return {'contents':fixture['contents'] if case=='full_schema_image' else [{'role':'user','parts':[{'text':prompt}]}],'generationConfig':config}

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):return None

def check(case,envelope):
    candidates=envelope.get('candidates',[])
    if len(candidates)!=1 or candidates[0].get('finishReason')!='STOP':return False
    text=''.join(p.get('text','') for p in candidates[0].get('content',{}).get('parts',[]) if not p.get('thought')).strip()
    if text.startswith('```json\n') and text.endswith('```'):text=text[8:-3]
    value=json.loads(text)
    if not isinstance(value,dict) or value.get('merchant')!='SLIPLET TEST':return False
    if case.startswith('full_schema'):
        import structured_layout_v3 as layout
        layout.canonical(value)
        rows=[r for r in value['rows'] if r['kind']=='purchase']
        return value['total']=='1.00' and len(rows)==1 and rows[0]['description']=='TEST APPLES' and rows[0]['amount']=='1.00'
    if case=='nullable':return set(value)=={'merchant','date'} and value['date'] is None
    if case=='enum_rows':return set(value)=={'merchant','rows'} and value['rows']==[{'kind':'purchase','amount':'1.00'}]
    return value=={'merchant':'SLIPLET TEST'}

def next_call():
    freeze();calls=load(OUT/'calls.json') if (OUT/'calls.json').exists() else []
    if len(calls)>6 or [c['index'] for c in calls]!=list(range(len(calls))):raise RuntimeError('invalid_inventory')
    results=[]
    for c in calls:
        p=OUT/f"result-{c['index']}.json"
        if not p.exists():return {'status':'stopped_after_interruption'}
        r=load(p)
        if r['case']!=c['case']:raise RuntimeError('mismatched_inventory')
        results.append(r)
    case=choose(results)
    if case is None:return {'status':'complete_or_stopped','calls':len(calls)}
    delay=math.ceil(95-(time.time()-calls[-1]['time'])) if calls else 0
    if delay>0:return {'status':'spacing','seconds':delay}
    if not load(ROOT/'private-receipts/evaluation/p8-02e/account-confirmation.json').get('free_tier_billing_disabled_user_confirmed'):raise RuntimeError('confirmation_required')
    key=keychain.read_key()
    if not key:raise RuntimeError('key_missing')
    body=json.dumps(request(case)).encode();index=len(calls)
    write(OUT/f'request-{index}.json',json.loads(body))
    calls.append({'index':index,'case':case,'time':time.time(),'sha256':hashlib.sha256(body).hexdigest()});write(OUT/'calls.json',calls)
    result={'case':case,'passed':False};started=time.monotonic()
    try:
        opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect(),urllib.request.HTTPSHandler(context=ssl.create_default_context()))
        req=urllib.request.Request(ENDPOINT,data=body,headers={'x-goog-api-key':key,'Content-Type':'application/json'},method='POST')
        with opener.open(req,timeout=120) as response:raw=response.read(262145)
        if len(raw)>262144:raise ValueError('response_bound')
        envelope=json.loads(raw);write(OUT/f'raw-{index}.json',envelope)
        result.update(status='received',passed=check(case,envelope),usage=envelope.get('usageMetadata',{}))
    except urllib.error.HTTPError as e:
        write(OUT/f'error-{index}.json',{'status':e.code,'body':e.read(8192).decode('utf-8',errors='replace')})
        result.update(status='provider_error',http_status=e.code)
    except (urllib.error.URLError,TimeoutError,OSError):result.update(status='network_or_timeout')
    except Exception:result.update(status='invalid_response')
    finally:del key
    result['seconds']=round(time.monotonic()-started,3);write(OUT/f'result-{index}.json',result)
    return result

if __name__=='__main__':
    os.umask(0o077)
    try:print(json.dumps(next_call()))
    except Exception:sys.exit('Diagnostic stopped; private details suppressed. No automatic retry.')
