#!/usr/bin/env python3
"""P8-01 lab. Network entry point accepts only the bundled fictional smoke image.
No private-image input, API-key arguments, environment-key reads or raw response logs.
"""
import base64
import datetime
from decimal import Decimal
import fcntl
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import ssl
import sys
import time
import urllib.error
import urllib.request

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions'
MODEL = 'qwen/qwen3.8-27b'
MAX_RESPONSE = 256_000
DECIMAL = re.compile(r'-?(?:0|[1-9][0-9]{0,8})(?:\.[0-9]{1,6})?\Z')
SCHEMA = json.loads((HERE / 'schema.json').read_text())

class LabError(Exception):
    """Only static, non-sensitive codes may be placed in this exception."""
    def __init__(self, code, diagnostic=None):
        super().__init__(code)
        self.diagnostic = diagnostic or {}

def parse_json(text):
    if len(text.encode('utf-8')) > MAX_RESPONSE:
        raise LabError('response_too_large')
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise LabError('duplicate_json_key')
            result[key] = value
        return result
    def constant(_):
        raise LabError('non_finite_number')
    try:
        return json.loads(text, object_pairs_hook=pairs, parse_constant=constant)
    except (ValueError, RecursionError, UnicodeError):
        raise LabError('invalid_json') from None

def validate_shape(value, schema, depth=0):
    """Deliberately small validator for the checked-in schema's keyword subset.
    Fail on unknown keywords so a schema revision cannot silently bypass a check.
    """
    supported = {'type','properties','required','additionalProperties','items','enum','minItems','maxItems'}
    if set(schema) - supported or depth > 16:
        raise LabError('unsupported_schema')
    kinds = schema['type']
    kinds = kinds if isinstance(kinds, list) else [kinds]
    kind = ('null' if value is None else 'boolean' if isinstance(value,bool)
            else 'string' if isinstance(value,str) else 'object' if isinstance(value,dict)
            else 'array' if isinstance(value,list) else 'number' if isinstance(value,(int,float)) else 'invalid')
    if kind not in kinds:
        raise LabError('schema_type')
    if 'enum' in schema and value not in schema['enum']:
        raise LabError('schema_enum')
    if kind == 'string' and len(value) > 1000:
        raise LabError('string_too_long')
    if kind == 'object':
        if set(value) != set(schema['required']) or schema['additionalProperties'] is not False:
            raise LabError('schema_keys')
        for key, child in value.items():
            validate_shape(child, schema['properties'][key], depth+1)
    if kind == 'array':
        if not schema.get('minItems',0) <= len(value) <= schema.get('maxItems',150):
            raise LabError('schema_array_size')
        for child in value:
            validate_shape(child, schema['items'], depth+1)

def validate_candidate(candidate, image_ids=('image-0',)):
    validate_shape(candidate, SCHEMA)
    issues = set()
    def evidence(items, needed):
        if needed and not items:
            issues.add('missing_source_claim')
        for item in items:
            if item['image_id'] not in image_ids:
                raise LabError('unknown_source_image')
            if not item['quote'].strip():
                issues.add('empty_source_claim')
            b = item['box']
            if b is not None and not (all(0 <= x <= 1 for x in b) and b[0] < b[2] and b[1] < b[3]):
                raise LabError('invalid_source_box')
    def number(value):
        if value is None:
            return None
        if not DECIMAL.fullmatch(value):
            raise LabError('invalid_decimal')
        return Decimal(value)
    for key in ('merchant','date','currency','subtotal','total'):
        f = candidate[key]
        evidence(f['evidence'], f['value'] is not None)
        if f['value'] == '':
            raise LabError('empty_field')
    for key in ('subtotal','total'):
        number(candidate[key]['value'])
    currency = candidate['currency']['value']
    if currency is not None and not re.fullmatch('[A-Z]{3}',currency):
        issues.add('currency_needs_review')
    if candidate['date']['value'] is not None:
        try:
            datetime.date.fromisoformat(candidate['date']['value'])
        except ValueError:
            issues.add('date_needs_review')
    ids = [line['id'] for line in candidate['lines']]
    if len(set(ids)) != len(ids) or any(not i for i in ids):
        raise LabError('invalid_row_identity')
    kinds = {line['id']:line['kind'] for line in candidate['lines']}
    values = []
    for line in candidate['lines']:
        evidence(line['evidence'], True)
        for key in ('quantity','unit_price','amount'):
            number(line[key])
        if line['parent_id'] is not None:
            if line['kind'] != 'discount' or kinds.get(line['parent_id']) not in ('purchase','return'):
                raise LabError('invalid_parent_reference')
        if line['kind'] in ('purchase','return','discount','tax','fee'):
            values.append(number(line['amount']))
            if line['amount'] is None:
                issues.add('missing_line_amount')
        if line['kind'] == 'other':
            issues.add('unclassified_row')
    total = number(candidate['total']['value'])
    if total is None:
        issues.add('missing_total')
    elif values and all(v is not None for v in values) and sum(values) != total:
        issues.add('total_conflict')
    # Balanced arithmetic does not validate image evidence or authorize Finish.
    return {'schema_valid':True,'issues':sorted(issues),'source_verified':False,'review_required':True}

def smoke_fixture():
    manifest = json.loads((HERE/'fixtures/manifest.json').read_text())
    entry = next(x for x in manifest if x['id']=='smoke')
    data = (HERE/'fixtures/smoke.png').read_bytes()
    if hashlib.sha256(data).hexdigest() != entry['sha256'] or len(data)>1_000_000:
        raise LabError('fictional_fixture_changed')
    return data

def request_body():
    # No expected answer, checked reference, arbitrary image or filename enters this request.
    return dict(model=MODEL,temperature=0,max_completion_tokens=3000,stream=False,
        messages=[{'role':'system','content':(HERE/'prompt.txt').read_text()},
          {'role':'user','content':[{'type':'text','text':'Extract the receipt from image-0.'},
          {'type':'image_url','image_url':{'url':'data:image/png;base64,'+base64.b64encode(smoke_fixture()).decode('ascii')}}]}],
        response_format={'type':'json_schema','json_schema':{'name':'sliplet_receipt','strict':True,'schema':SCHEMA}})

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise LabError('redirect_refused')

def http_state(status):
    return {400:'request_or_schema_rejected',401:'key_rejected',403:'access_denied',404:'model_or_endpoint_unavailable',
            413:'request_too_large',422:'request_or_schema_rejected',429:'rate_or_quota_limited'}.get(status,'provider_error')

def send(body, key):
    encoded = json.dumps(body).encode('utf-8')
    if len(encoded)>1_500_000:
        raise LabError('request_too_large')
    # No implicit proxy, retries, redirects, caches, cookies, URL image fetches or SDK logging.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect(),
                                        urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    req = urllib.request.Request(ENDPOINT,data=encoded,headers={
        'Authorization':'Bearer '+key,'Content-Type':'application/json',
        'User-Agent':'SlipletReceiptLab/0.1','Accept':'application/json'},method='POST')
    try:
        with opener.open(req,timeout=60) as response:
            raw = response.read(MAX_RESPONSE+1)
    except urllib.error.HTTPError as error:
        diagnostic = {'http_status':error.code,'error_format':'unknown','provider_code':'unrecognized'}
        # Read only to classify known static codes. Never persist or echo error text.
        try:
            raw_error = error.read(16384)
            if raw_error.lstrip().startswith(b'{'):
                diagnostic['error_format']='json'
                parsed_error=json.loads(raw_error)
                code=parsed_error.get('error',{}).get('code')
                allowed={'invalid_api_key','model_not_found','model_decommissioned',
                         'rate_limit_exceeded','insufficient_quota','permission_denied',
                         'organization_restricted','unsupported_country_region_territory',
                         'json_validate_failed','model_permission_blocked'}
                if isinstance(code,str) and code in allowed:
                    diagnostic['provider_code']=code
            elif b'error code: 1010' in raw_error:
                diagnostic['error_format']='edge_rejection_1010'
            elif raw_error.lstrip().lower().startswith((b'<!doctype html',b'<html')):
                diagnostic['error_format']='html'
        except Exception:
            pass
        raise LabError(http_state(error.code),diagnostic) from None
    except (urllib.error.URLError,TimeoutError,OSError):
        raise LabError('network_or_timeout') from None
    if len(raw)>MAX_RESPONSE:
        raise LabError('response_too_large')
    try:
        return parse_json(raw.decode('utf-8'))
    except UnicodeError:
        raise LabError('invalid_response_encoding') from None

def read_completion(envelope):
    try:
        choices = envelope['choices']
        if not isinstance(choices,list) or len(choices)!=1:
            raise LabError('invalid_completion')
        choice = choices[0]
        if choice['message'].get('refusal'):
            raise LabError('model_refusal')
        if choice['finish_reason'] != 'stop':
            raise LabError('incomplete_completion')
        content=choice['message']['content']
        if not isinstance(content,str):
            raise LabError('invalid_completion')
        candidate=parse_json(content)
        return candidate,validate_candidate(candidate)
    except (KeyError,TypeError,IndexError,AttributeError):
        raise LabError('invalid_completion') from None

def smoke_matches(candidate):
    expected=json.loads((HERE/'fixtures/smoke.expected.json').read_text())
    # Separate the capability check from exact fictional field extraction.
    fields=all(candidate[k]['value']==expected[k]['value'] for k in ('merchant','date','currency','subtotal','total'))
    def rows(c):return [(r['kind'],r['description'],r['amount']) for r in c['lines']]
    return fields and rows(candidate)==rows(expected)

def reserve_attempt():
    directory=ROOT/'private-receipts/evaluation/p8-01-lab'
    directory.mkdir(parents=True,exist_ok=True,mode=0o700)
    path=directory/'attempts.json'
    fd=os.open(path,os.O_RDWR|os.O_CREAT|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'r+') as f:
        fcntl.flock(f,fcntl.LOCK_EX)
        raw=f.read()
        state=json.loads(raw) if raw else {}
        day=datetime.datetime.now(datetime.timezone.utc).date().isoformat()
        count=state.get(day,0)
        if count>=3:
            raise LabError('daily_smoke_budget_exhausted')
        state[day]=count+1
        f.seek(0);json.dump(state,f);f.truncate();f.flush();os.fsync(f.fileno())
    return directory

def smoke():
    if not sys.stdin.isatty():
        raise LabError('interactive_terminal_required')
    print('Sliplet: fictional receipt connection test. No real receipts are read.')
    print('Use a NEW key if any previous key was pasted into a chat. This key stays in memory only.')
    print('One request to Groq. Your account allowance is used. No automatic retries.')
    if input('Confirm your Groq account is on the free tier (type FREE): ').strip().upper()!='FREE':
        raise LabError('cancelled')
    body=request_body()
    key=getpass.getpass('Paste the replacement API key here (hidden; never saved): ').strip()
    if not key or '\n' in key or '\r' in key or len(key)>512:
        raise LabError('invalid_key_input')
    try:
        key.encode('ascii')
    except UnicodeError:
        raise LabError('invalid_key_input') from None
    if input('Send only the bundled fictional test image now? Type TEST: ').strip().upper()!='TEST':
        raise LabError('cancelled')
    directory=reserve_attempt()
    start=time.monotonic()
    report={'task':'P8-01','fixture':'fictional-smoke','model':MODEL,'live_request_attempted':True,
            'key_saved':False,'private_receipts_sent':False,'privacy_settings_verified':False}
    try:
        envelope=send(body,key)
        report['credential_accepted']=True
        usage=envelope.get('usage',{}) if isinstance(envelope,dict) else {}
        if isinstance(usage,dict):
            report['usage']={k:usage[k] for k in ('prompt_tokens','completion_tokens','total_tokens')
                             if type(usage.get(k)) is int and 0<=usage[k]<=1_000_000}
        candidate,validation=read_completion(envelope)
        report.update(status='image_schema_response_received',fictional_exact=smoke_matches(candidate),validation=validation)
    except LabError as e:
        report.update(status=str(e),diagnostic=e.diagnostic)
    finally:
        key=None  # Drop reference; Python does not guarantee physical memory erasure.
    report['elapsed_seconds']=round(time.monotonic()-start,2)
    report['checked_at_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
    # Only static outcomes/counters. Never save response contents or credentials.
    fd=os.open(directory/'smoke-result.json',os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'w') as f:json.dump(report,f,indent=2)
    print(json.dumps(report,indent=2))

def main():
    os.umask(0o077)
    if sys.argv[1:]==['smoke']:
        smoke()
    elif sys.argv[1:]==['check']:
        expected=json.loads((HERE/'fixtures/smoke.expected.json').read_text())
        validate_candidate(expected)
        body=request_body()
        print(json.dumps({'offline_contract_check':'passed','network_used':False,'request_bytes':len(json.dumps(body).encode()),'model':MODEL}))
    else:
        print('Usage: python3 lab.py check | smoke')
        return 2
    return 0

if __name__=='__main__':
    try:
        sys.exit(main())
    except LabError as error:
        print('Stopped: '+str(error));sys.exit(1)
    except (KeyboardInterrupt,EOFError):
        print('\nCancelled; no key saved.');sys.exit(1)
    except Exception:
        print('Stopped: unexpected local error; sensitive details suppressed.');sys.exit(1)
