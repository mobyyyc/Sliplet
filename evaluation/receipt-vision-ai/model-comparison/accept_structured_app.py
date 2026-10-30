"""P8-07 bounded current-app acceptance. Explicit next sends at most one request.

Five previously approved actual receipts, exact native-exported image requests,
95-second spacing, no retries and stop on any failed/interrupted attempt.
Outputs are private except aggregate report counters. No secret output.
"""
import hashlib,json,os,ssl,sys,time,urllib.request,urllib.error
from pathlib import Path
import structured_layout_v3 as layout
import confirm_structured as baseline
from credentials import keychain
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'private-receipts/evaluation/p8-07-structured-03'
MODEL='gemini-3.6-flash'
ENDPOINT='https://generativelanguage.googleapis.com/v1beta/models/'+MODEL+':generateContent'
def load(p):return json.loads(p.read_text())
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):
    p.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
    p.write_text(json.dumps(value,indent=2)+'\n');p.chmod(0o600)
def freeze():
    files=[ROOT/'Sliplet/Recognition/Model'/n for n in ['ReceiptUploadImage.swift','GeminiReceiptTransport.swift','ReceiptModelReader.swift','ReceiptAIConnection.swift']]
    files += [Path(__file__),Path(layout.__file__),baseline.trial.REFERENCE]
    files += [ROOT/f'private-receipts/evaluation/p8-01-redaction-review/receipt-{i+1}-local.png' for i in range(5)]
    files += [OUT/f'request-{i}.json' for i in range(5)] + [OUT/'fictional-request.json']
    config={'model':MODEL,'endpoint':ENDPOINT,'maximum_attempts':5,'retries':0,'spacing_seconds':95,'timeout_seconds':120,
            'authorization':'Approved P8-07 acceptance on the same five actual receipts previously authorized by the owner.',
            'input':'Current native image preparation and request export; no OCR, reference labels or redaction.',
            'files':{str(p.relative_to(ROOT)):digest(p) for p in files}}
    p=OUT/'configuration.json'
    if p.exists() and load(p)!=config:raise RuntimeError('configuration_changed')
    if not p.exists():write(p,config)
    return config
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):return None
def next_call():
    freeze()
    if not load(OUT/'fictional-result.json').get('passed'):raise RuntimeError('fictional_gate_required')
    history=load(OUT/'calls.json') if (OUT/'calls.json').exists() else []
    if len(history)>5 or [x['slot'] for x in history]!=list(range(len(history))):raise RuntimeError('invalid_inventory')
    for c in history:
        p=OUT/'responses'/f"real-{c['slot']}-1.json"
        if not p.exists() or load(p)['status']!='received':return {'status':'stopped_after_failure','attempts':len(history)}
    if len(history)==5:return {'status':'complete','attempts':5}
    remaining=95-(time.time()-(history[-1]['time'] if history else load(OUT/'fictional-call.json')['time']))
    if remaining>0:return {'status':'spacing','seconds':round(remaining)+1}
    marker=ROOT/'private-receipts/evaluation/p8-02e/account-confirmation.json'
    if not load(marker).get('free_tier_billing_disabled_user_confirmed'):raise RuntimeError('account_confirmation_missing')
    key=keychain.read_key()
    if not key:raise RuntimeError('key_missing')
    slot=len(history);body=(OUT/f'request-{slot}.json').read_bytes()
    request=load(OUT/f'request-{slot}.json')
    if len(body)>12_000_000 or set(request)!= {'contents','generationConfig'}:raise RuntimeError('request_bound')
    history.append({'slot':slot,'time':time.time(),'payload_sha256':hashlib.sha256(body).hexdigest()});write(OUT/'calls.json',history)
    result={'status':'interrupted','slot':slot};start=time.monotonic()
    try:
        opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect(),urllib.request.HTTPSHandler(context=ssl.create_default_context()))
        req=urllib.request.Request(ENDPOINT,data=body,headers={'x-goog-api-key':key,'Content-Type':'application/json'},method='POST')
        with opener.open(req,timeout=120) as response:raw=response.read(262145)
        if len(raw)>262144:raise ValueError('response_bound')
        envelope=json.loads(raw);write(OUT/'raw'/f'real-{slot}-1.json',envelope)
        parsed=baseline.trial.parse(envelope)
        actual,validation=layout.canonical(parsed['candidate'])
        result.update(status='received',candidate=parsed['candidate'],actual=actual,validation=validation,usage=envelope.get('usageMetadata',{}))
    except urllib.error.HTTPError as e:
        write(OUT/'http-error.json',{'status':e.code,'body':e.read(8192).decode('utf-8',errors='replace')})
        result.update(status='provider_error',http_status=e.code)
    except (urllib.error.URLError,TimeoutError,OSError):result.update(status='network_or_timeout')
    except Exception:result.update(status='invalid_or_incomplete_response')
    finally:del key
    result['elapsed_seconds']=round(time.monotonic()-start,3)
    write(OUT/'responses'/f'real-{slot}-1.json',result)
    return {k:v for k,v in result.items() if k in ('slot','status','http_status','elapsed_seconds')}
def probe():
    freeze()
    if (OUT/'fictional-call.json').exists():raise RuntimeError('probe_already_attempted')
    if not load(ROOT/'private-receipts/evaluation/p8-02e/account-confirmation.json').get('free_tier_billing_disabled_user_confirmed'):raise RuntimeError('account_confirmation_missing')
    key=keychain.read_key()
    if not key:raise RuntimeError('key_missing')
    body=(OUT/'fictional-request.json').read_bytes()
    write(OUT/'fictional-call.json',{'time':time.time(),'payload_sha256':hashlib.sha256(body).hexdigest()})
    result={'passed':False};start=time.monotonic()
    try:
        opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect(),urllib.request.HTTPSHandler(context=ssl.create_default_context()))
        req=urllib.request.Request(ENDPOINT,data=body,headers={'x-goog-api-key':key,'Content-Type':'application/json'},method='POST')
        with opener.open(req,timeout=120) as response:raw=response.read(262145)
        if len(raw)>262144:raise ValueError('response_bound')
        envelope=json.loads(raw);write(OUT/'fictional-raw.json',envelope)
        parsed=baseline.trial.parse(envelope);actual,validation=layout.canonical(parsed['candidate'])
        c=parsed['candidate'];purchases=[r for r in c['rows'] if r['kind']=='purchase']
        passed=c['merchant']=='SLIPLET TEST' and c['total']=='1.00' and len(purchases)==1 and purchases[0]['description']=='TEST APPLES' and purchases[0]['amount']=='1.00'
        result.update(status='received',passed=passed)
    except urllib.error.HTTPError as e:
        write(OUT/'http-error.json',{'status':e.code,'body':e.read(8192).decode('utf-8',errors='replace')})
        result.update(status='provider_error',http_status=e.code)
    except (urllib.error.URLError,TimeoutError,OSError):result.update(status='network_or_timeout')
    except Exception:result.update(status='invalid_or_incomplete_response')
    finally:del key
    result['elapsed_seconds']=round(time.monotonic()-start,3)
    write(OUT/'fictional-result.json',result);return result

def report():
    freeze();history=load(OUT/'calls.json');results=[load(OUT/'responses'/f"real-{x['slot']}-1.json") for x in history]
    summary={'attempts':len(history),'received':sum(x['status']=='received' for x in results),'statuses':[x['status'] for x in results],
             'response_seconds':[x['elapsed_seconds'] for x in results],'held_out_receipts':0,'model':MODEL}
    if len(results)==5 and summary['received']==5:
        comparison,ledger=baseline.score_folder(OUT);write(OUT/'ledger.json',ledger)
        summary['comparison']=comparison;summary['previous_gates']=baseline.acceptance(comparison)
        core=comparison['gemini']['core'];summary['core_above_95_percent']=core['core_correct_purchases_including_groups']/core['expected_purchases']>0.95
        parity=[]
        for i,result in enumerate(results):
            parity.append({'envelope':load(OUT/'raw'/f'real-{i}-1.json'),'expected':result['actual'],
                           'imagePath':str(ROOT/f'private-receipts/evaluation/p8-01-redaction-review/receipt-{i+1}-local.png')})
        write(Path('/tmp/sliplet-p803-private-parity.json'),parity)
    write(OUT/'summary.json',summary)
    return summary
if __name__=='__main__':
    os.umask(0o077)
    try:
        mode=sys.argv[1]
        result={'status':'frozen','requests':0} if mode=='freeze' and freeze() else probe() if mode=='probe' else next_call() if mode=='next' else report() if mode=='report' else {'status':'invalid_command'}
        print(json.dumps(result))
    except Exception:sys.exit('Acceptance stopped; private details suppressed. No automatic retry.')
