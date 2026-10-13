#!/usr/bin/env python3
"""P4-01 private Simulator capture/coverage protocol. Only aggregate status on stdout."""
import argparse
import collections
import copy
import hashlib
import html
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import statistics
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'evaluation/receipt-audit'))
import audit as legacy
spec = importlib.util.spec_from_file_location('layout', ROOT/'evaluation/receipt-layout/compare.py')
layout = importlib.util.module_from_spec(spec); spec.loader.exec_module(layout)
STATES = {'printed_verified', 'not_printed_verified', 'unreadable', 'unreviewed'}
RECEIPT_FIELDS = ('merchant', 'date', 'currency', 'subtotal', 'total')
ITEM_FIELDS = ('kind', 'description', 'amount', 'quantity', 'unit', 'unitPrice', 'sku', 'taxMarker')
ADJUSTMENT_FIELDS = ('kind', 'description', 'amount', 'rate')
ENV = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
BUNDLE = 'com.mobyyyc.RcpLens'

def digest(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return json.loads(Path(p).read_text())
def write(p, value):
    p = Path(p); p.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True)); p.chmod(0o600)
def private(p): return legacy.private(p)
def run_tool(args, log=None, timeout=120):
    p = subprocess.run(args, env=ENV, capture_output=True, timeout=timeout)
    if log:
        Path(log).write_bytes(p.stdout+p.stderr); Path(log).chmod(0o600)
    if p.returncode: raise ValueError('local_command_failed')
    return p.stdout.decode()
def sources():
    folders = ('Sliplet', 'SlipletTests', 'evaluation/receipt-lab', 'evaluation/receipt-audit', 'evaluation/receipt-layout', 'evaluation/receipt-eval')
    return {str(p.relative_to(ROOT)): digest(p) for folder in folders for p in sorted((ROOT/folder).rglob('*')) if p.is_file() and p.suffix in {'.swift','.py','.md','.json'}}
def check_device(device):
    data = json.loads(run_tool(['xcrun','simctl','list','devices','available','-j']))
    d = next(({**d,'runtimeIdentifier':runtime} for runtime,group in data['devices'].items() for d in group if d['udid']==device),None)
    if not d or d['name'] != 'Sliplet P4-01 Recognition Lab': raise ValueError('isolated_device_required')
    runtimes=json.loads(run_tool(['xcrun','simctl','list','runtimes','-j']))['runtimes']
    runtime=next(r for r in runtimes if r['identifier']==d['runtimeIdentifier'])
    d['runtimeVersion']=runtime['version'];d['runtimeBuild']=runtime['buildversion']
    return d

def reference(expected):
    def field(value=None):
        return {'state':'printed_verified','value':value,'original_regions':[]} if value is not None else {'state':'unreviewed','original_regions':[]}
    fields = {k:field(expected.get(k)) for k in RECEIPT_FIELDS}
    # Prior labels did not verify printed currency or normalized quantities/units.
    fields['currency'] = field()
    if expected.get('date') is not None:fields['date']=field(legacy.e.date_key(expected['date']))
    lines=[]
    for i,line in enumerate(expected['lines']):
        keys = ITEM_FIELDS if line['kind']=='purchase' else ADJUSTMENT_FIELDS
        values={k:field(line.get(k) if k in {'kind','description','amount'} else None) for k in keys}
        lines.append({'reference_id':f'line-{i+1}', 'original_regions':[], 'fields':values,
                      'legacy_quantity_transcription':line.get('quantity')})
    return {'fields':fields,'lines':lines,'all_lines_verified':True,'all_summary_fields_verified':False,
            'verification_method':'legacy_checked_fields_only','source_regions_verified':False}

def validate_reference(ref):
    if any(type(ref[k]) is not bool for k in ('all_lines_verified','all_summary_fields_verified','source_regions_verified')): raise ValueError('invalid_coverage_flag')
    if set(ref['fields']) != set(RECEIPT_FIELDS): raise ValueError('receipt_field_inventory')
    ids=[l['reference_id'] for l in ref['lines']]
    if len(ids)!=len(set(ids)): raise ValueError('duplicate_reference_identity')
    for fields in [ref['fields']]+[l['fields'] for l in ref['lines']]:
        for key,field in fields.items():
            state=field['state']
            if state not in STATES: raise ValueError('invalid_field_state')
            value=field.get('value')
            if state=='printed_verified' and value is None: raise ValueError('missing_verified_value')
            if state!='printed_verified' and 'value' in field: raise ValueError('unverified_value')
            if state=='printed_verified':
                if key in {'amount','subtotal','total','unitPrice'}:
                    if type(value) is not int or abs(value)>10**11: raise ValueError('invalid_minor_units')
                elif not isinstance(value,str) or not value: raise ValueError('invalid_text_field')
                if key in {'quantity','rate'}:
                    import re
                    if not re.fullmatch(r'(?:0|[1-9][0-9]*)(?:\.[0-9]*[1-9])?',value): raise ValueError('invalid_decimal')
            for box in field.get('original_regions',[]): validate_box(box)
    for line in ref['lines']:
        kind=line['fields']['kind'].get('value')
        if kind not in {'purchase','discount','tax','deposit','tip','adjustment'}: raise ValueError('invalid_kind')
        if line['original_regions'] and not ref['source_regions_verified']: raise ValueError('unverified_identity_region')
        if set(line['fields']) != set(ITEM_FIELDS if kind=='purchase' else ADJUSTMENT_FIELDS): raise ValueError('line_field_inventory')
        for box in line['original_regions']: validate_box(box)

def validate_box(b):
    if set(b)!= {'x','y','width','height'}: raise ValueError('invalid_box')
    if not (0<=b['x']<=1 and 0<=b['y']<=1 and b['width']>0 and b['height']>0 and b['x']+b['width']<=1.000001 and b['y']+b['height']<=1.000001): raise ValueError('invalid_box')

def field_result(label, actual, key):
    state=label['state']
    if state in {'unreadable','unreviewed'}: return 'unscorable'
    if state=='not_printed_verified': return 'correct_absence' if actual is None else 'spurious'
    if actual is None: return 'missing'
    desired=label['value']
    # Printed text normalization is restricted to casing and whitespace.
    equal=legacy.e.norm(actual)==legacy.e.norm(desired) if key in {'merchant','description'} else actual==desired
    return 'correct' if equal else 'wrong'

def decimal(value):
    if value is None:return None
    from decimal import Decimal
    return format(Decimal(value['coefficient']).scaleb(-value['scale']).normalize(),'f')
def money(value): return value['minorUnits'] if value is not None else None

def fields_actual(fields):
    date=fields.get('purchaseDate')
    data={'merchant':fields.get('merchant'),'date':'%04d-%02d-%02d'%(date['year'],date['month'],date['day']) if date else None,
          'currency':(fields.get('currency') or {}).get('code'),'subtotal':money(fields.get('subtotal')),'total':money(fields.get('total')),'lines':[]}
    for line in fields['items']:
        data['lines'].append({'id':line['id'],'kind':'purchase','description':line.get('description'),'amount':money(line.get('amount')),
                             'quantity':decimal(line.get('quantity')),'unit':None,'unitPrice':money(line.get('unitPrice')),
                             'sku':line.get('sku'),'taxMarker':line.get('taxMarker'),'sourceLineIDs':line['sourceLineIDs']})
    for line in fields['adjustments']:
        data['lines'].append({'id':line['id'],'kind':'adjustment' if line['kind']=='other' else line['kind'],
                             'description':line.get('label'),'amount':money(line.get('amount')),'rate':decimal(line.get('rate')),'sourceLineIDs':line['sourceLineIDs']})
    return data

def pairing(actual, ref, observations):
    """No amount-assisted pairing. Duplicate names remain ambiguous without verified locations."""
    byid={o['id']:o for o in observations}; unused=set(range(len(actual)));pairs=[];ambiguous=[]
    for i,line in enumerate(ref['lines']):
        f=line['fields']; kind=f['kind'].get('value'); desc=f['description'].get('value')
        candidates=[]
        if line['original_regions']:
            for j in unused:
                for source in actual[j].get('sourceLineIDs',[]):
                    box=byid.get(source,{}).get('boundingBox')
                    if not box: continue
                    x,y=box['x']+box['width']/2,box['y']+box['height']/2
                    if any(r['x']<=x<=r['x']+r['width'] and r['y']<=y<=r['y']+r['height'] for r in line['original_regions']):
                        candidates.append(j);break
        else:
            same_reference=sum(l['fields']['kind'].get('value')==kind and legacy.e.norm(l['fields']['description'].get('value'))==legacy.e.norm(desc) for l in ref['lines'])
            candidates=[j for j in unused if actual[j].get('kind')==kind and legacy.e.norm(actual[j].get('description'))==legacy.e.norm(desc)]
            if candidates and same_reference>1:
                ambiguous.append(i); pairs.append((i,None)); continue
        if len(candidates)>1:
            ambiguous.append(i);pairs.append((i,None))
        elif candidates:
            j=candidates[0];unused.remove(j);pairs.append((i,j))
        else:pairs.append((i,None))
    return pairs,sorted(unused),ambiguous

def score(actual,ref,observations):
    validate_reference(ref)
    counts=collections.Counter(); coverage=collections.Counter();details=[]; byfield={}
    def add(key,label,value):
        result=field_result(label,value,key)
        counts[result]+=1;coverage[label['state']]+=1
        byfield.setdefault(key,collections.Counter())[result]+=1
        return result
    for k,label in ref['fields'].items():add(k,label,actual.get(k))
    pairs,unmatched,ambiguous=pairing(actual['lines'],ref,observations)
    for i,j in pairs:
        line=ref['lines'][i]; outcomes={}
        if i in ambiguous:
            for key,label in line['fields'].items():
                coverage[label['state']]+=1;counts['ambiguous_identity']+=1
                byfield.setdefault(key,collections.Counter())['ambiguous_identity']+=1
            details.append({'reference_line':i,'actual_line':None,'outcomes':{},'ambiguous_identity':True});continue
        for key,label in line['fields'].items():
            outcomes[key]=add(key,label,actual['lines'][j].get(key) if j is not None else None)
        details.append({'reference_line':i,'actual_line':j,'outcomes':outcomes})
    # Unmatched output can reflect description errors or ambiguity, not proven invention.
    counts['unmatched_actual_line_proxies']=len(unmatched)
    counts['missing_line_proxies']=sum(j is None and i not in ambiguous for i,j in pairs)
    counts['reference_lines']=len(ref['lines']); counts['actual_lines']=len(actual['lines'])
    counts['exact_purchase_pairs']=sum(ref['lines'][d['reference_line']]['fields']['kind'].get('value')=='purchase' and all(d['outcomes'].get(k)=='correct' for k in ('kind','description','amount')) for d in details)
    counts['expected_purchases']=sum(l['fields']['kind'].get('value')=='purchase' for l in ref['lines'])
    counts['actual_purchases']=sum(l['kind']=='purchase' for l in actual['lines'])
    ambiguous_keys={(ref['lines'][i]['fields']['kind'].get('value'),legacy.e.norm(ref['lines'][i]['fields']['description'].get('value'))) for i in ambiguous}
    ambiguous_pool={j for j in unmatched if (actual['lines'][j].get('kind'),legacy.e.norm(actual['lines'][j].get('description'))) in ambiguous_keys}
    counts['unrelated_unmatched_actual_lines']=len(set(unmatched)-ambiguous_pool)
    cardinality_error=False
    for kind,desc in ambiguous_keys:
        expected_count=sum(l['fields']['kind'].get('value')==kind and legacy.e.norm(l['fields']['description'].get('value'))==desc for l in ref['lines'])
        actual_count=sum(l.get('kind')==kind and legacy.e.norm(l.get('description'))==desc for l in actual['lines'])
        cardinality_error |= expected_count!=actual_count
    counts['ambiguous_group_count_mismatch']=int(cardinality_error)
    has_error=cardinality_error or any(counts[k]>0 for k in ('wrong','missing','spurious','missing_line_proxies')) or (counts['unrelated_unmatched_actual_lines']>0 and ref['all_lines_verified'])
    unknown=any(counts[k]>0 for k in ('unscorable','ambiguous_identity')) or not ref['all_lines_verified'] or not ref['all_summary_fields_verified']
    verdict='incorrect' if has_error else ('indeterminate' if unknown else 'correct')
    return {'counts':dict(counts),'reference_coverage':dict(coverage),'fields':{k:dict(v) for k,v in byfield.items()},'verdict':verdict,'line_results':details,'unmatched_actual_indices':unmatched,'pairing':'verified_region_or_unique_kind_description_no_amount_tiebreak'}

def stage_failures(response, expected):
    pairs,_=legacy.match_lines(legacy.normalize(response),expected)
    out=[]
    for i,line,found in pairs:
        if found is not None and found[1]['amount']==line['amount']:continue
        def has_desc(text):return legacy.e.norm(line['description']) in legacy.e.norm(text)
        def paired(row):return has_desc(row['text']) and legacy.money_in(row['text'],line['amount'])
        grouped=any(paired(row) for row in response['groupedRows'])
        interpreted=any(paired(row) for row in response['interpretedRows'])
        desc=[o for o in response['observations'] if has_desc(o['text'])]
        prices=[o for o in response['observations'] if legacy.money_in(o['text'],line['amount'])]
        near=False
        for d in desc:
            for p in prices:
                db,pb=d.get('boundingBox'),p.get('boundingBox')
                if db and pb:
                    near |= abs((db['y']+db['height']/2)-(pb['y']+pb['height']/2))<=1.5*max(db['height'],pb['height'])
        category='interpretation_or_description_match_suspect' if interpreted else ('grouping_or_interpretation_suspect' if grouped else ('association_suspect' if near else 'capture_ocr_or_reference_unresolved'))
        out.append({'reference_line':i,'kind':line['kind'],'category':category,'grouped_pair':grouped,'interpreted_pair':interpreted,'nearby_evidence':near})
    return out

def stable(response):
    """Strip generated identities only, retain text, all fields and source relationships."""
    source={o['id']:i for i,o in enumerate(response['observations'])}
    def walk(v,key=None):
        if isinstance(v,dict):return {k:walk(x,k) for k,x in v.items() if k not in {'id','capturedAt'}}
        if isinstance(v,list):return [walk(x,key) for x in v]
        if key in {'sourceLineIDs','groupedRowIDs','interpretedRowIDs','ids'}:return source.get(v,v)
        return v
    return {k:walk(response[k],k) for k in ('observations','parsed','fields','draftFields','draft','groupedRowIDs','interpretedRowIDs')}

def prepare(args):
    os.umask(0o077); output=private(args.run)
    if output.exists():raise ValueError('new_run_required')
    device=check_device(args.device)
    groups=read(ROOT/'private-receipts/evaluation/p2-01-final/corpus.json')['groups']
    legacy.validate_groups(groups)
    labels=ROOT/'private-receipts/evaluation/real-v1/ground-truth.json'
    checked=layout.validated_labels(labels,ROOT/'private-receipts/evaluation/real-final',groups)
    # Resolve historical paths by digest without modifying archived manifests.
    images={digest(p):p for p in (ROOT/'private-receipts').iterdir() if p.is_file() and p.suffix.lower() in {'.heic','.jpg','.jpeg','.png'}}
    for group in groups:
        for image in group['images']:
            image['path']=str(images[image['sha256']])
    output.mkdir(parents=True,mode=0o700)
    nonce=str(uuid.uuid4()); app=Path(args.build)/'Build/Products/Debug-iphonesimulator/Sliplet.app'
    run_tool(['xcrun','simctl','install',args.device,str(app)])
    container=Path(run_tool(['xcrun','simctl','get_app_container',args.device,BUNDLE,'data']).strip())
    inbox=container/'Documents/P401Lab'/nonce;inbox.mkdir(parents=True,mode=0o700)
    slots=[]
    for index,g in enumerate(groups):
        image=g['images'][0]; name=f'input-{index}'+Path(image['path']).suffix.lower()
        target=inbox/name;target.write_bytes(Path(image['path']).read_bytes());target.chmod(0o600)
        slots.append({'slot':index,'image':name,'sha256':image['sha256']})
    write(inbox/'request.json',{'nonce':nonce,'slots':slots}) # No checked references reach the app.
    xctestrun=next((Path(args.build)/'Build/Products').glob('*.xctestrun'))
    data=plistlib.loads(xctestrun.read_bytes())
    targets = [t for c in data.get('TestConfigurations',[]) for t in c['TestTargets']] if 'TestConfigurations' in data else [v for k,v in data.items() if k=='SlipletTests']
    if len(targets)!=1: raise ValueError('unexpected_test_targets')
    for target in targets:
        target.setdefault('EnvironmentVariables',{}).update(SLIPLET_P401_PRIVATE='YES',SLIPLET_P401_NONCE=nonce)
    def resolve(v):
        if isinstance(v,dict): return {k:resolve(x) for k,x in v.items()}
        if isinstance(v,list): return [resolve(x) for x in v]
        if isinstance(v,str): return v.replace('__TESTROOT__',str(xctestrun.parent))
        return v
    (output/'private.xctestrun').write_bytes(plistlib.dumps(resolve(data)))
    write(output/'reference-v2.json',{'schema_version':2,'receipts':[{'slot':i,**reference(checked[g['purchase_id']])} for i,g in enumerate(groups)]})
    write(output/'manifest.json',{'schema_version':1,'nonce':nonce,'groups':groups,'label_path':str(labels),'label_hash':digest(labels),
        'sources':sources(),'project_hash':digest(ROOT/'Sliplet.xcodeproj/project.pbxproj'),'device':args.device,'inbox':str(inbox),
        'app_binary_sha256':digest(app/'Sliplet'),'test_binary_sha256':digest(app/'PlugIns/SlipletTests.xctest/SlipletTests'),
        'simulator':{'device_type':device['deviceTypeIdentifier'],'runtime':device['runtimeIdentifier'],'version':device['runtimeVersion'],'build':device['runtimeBuild']},'reference_hash':digest(output/'reference-v2.json')})
    print(json.dumps({'status':'prepared','purchases':len(groups),'labels_supplied_to_app':False}))

def collect(args):
    output=private(args.run);m=read(output/'manifest.json');check_device(m['device'])
    # Xcode may relocate the data container when installing the test host. Resolve it after the run.
    container=Path(run_tool(['xcrun','simctl','get_app_container',m['device'],BUNDLE,'data']).strip())
    inbox=container/'Documents/P401Lab'/m['nonce']
    if not inbox.is_dir():raise ValueError('capture_inbox_missing')
    request=read(inbox/'request.json')
    if set(request)!={'nonce','slots'} or request['nonce']!=m['nonce']:raise ValueError('staged_request_changed')
    if any(set(slot)!={'slot','image','sha256'} for slot in request['slots']):raise ValueError('reference_leak')
    captures=output/'captures';captures.mkdir(exist_ok=True,mode=0o700)
    write(captures/'staged-request.json',request)
    for slot in range(len(m['groups'])):
        for repeat in (1,2):
            name=f'capture-{slot}-{repeat}.json'
            p=inbox/name
            if p.exists():write(captures/name,read(p))
            ledger=inbox/f'attempt-{slot}-{repeat}.json'
            write(captures/ledger.name,read(ledger) if ledger.exists() else {'status':'not_attempted_after_abort'})
    report,records=evaluate(output)
    write(output/'private-scores.json',records);write(output/'aggregate.json',report)
    review_page(output,m,records)
    print(json.dumps({'status':'collected','attempts':report['attempts'],'successful':report['successful_attempts'],'complete_receipts':report['verdicts'].get('correct',0)}))

def evaluate(output):
    m=read(output/'manifest.json');refs=read(output/'reference-v2.json')['receipts']
    if {r['slot'] for r in refs}!=set(range(len(m['groups']))) or len(refs)!=len(m['groups']):raise ValueError('reference_slots')
    refs=sorted(refs,key=lambda r:r['slot'])
    checked=layout.validated_labels(Path(m['label_path']),ROOT/'private-receipts/evaluation/real-final',m['groups'])
    for path,h in m['sources'].items():
        if digest(ROOT/path)!=h:raise ValueError('sources_changed')
    if digest(m['label_path'])!=m['label_hash'] or digest(output/'reference-v2.json')!=m['reference_hash']:raise ValueError('references_changed')
    if digest(ROOT/'Sliplet.xcodeproj/project.pbxproj')!=m['project_hash']:raise ValueError('project_changed')
    report={'schema_version':1,'task':'P4-01','corpus':{'development':len(refs),'held_out':0},'attempts':len(refs)*2,'successful_attempts':0,
            'attempt_statuses':{},'first_attempt_failures':0,'first_not_attempted':0,'storage_eligible':0,'storage_attempted':0,'repeat_pairs_equal':0,'legacy':{},'verdicts':{},'coverage':{},'v2_counts':{},'field_results':{},'failure_suspects':{},'stores':{},
            'conversion_fields_equal':0,'currency_unresolved_receipts':0,'parser_line_amounts_blocked_by_currency':0,'parser_summary_amounts_blocked_by_currency':0,'draft_storage_roundtrips_equal':0,'source_preservation_checks':0,'full_parsed_equal_previous_mac':0}
    records=[];times=[];repeat_times=[];gaps=[]
    def counter(key,value):report[key]=dict(collections.Counter(report[key])+collections.Counter(value))
    for slot,group in enumerate(m['groups']):
        for image in group['images']:
            if digest(image['path'])!=image['sha256']:raise ValueError('original_changed')
        passes=[]
        for repeat in (1,2):
            p=output/'captures'/f'capture-{slot}-{repeat}.json'
            status=read(output/'captures'/f'attempt-{slot}-{repeat}.json')['status']
            if status not in {'ok','failed','timed_out','started','not_attempted_after_abort'}:raise ValueError('invalid_attempt_status')
            counter('attempt_statuses',{status:1})
            if status!='ok':
                if repeat==1:
                    report['first_not_attempted' if status=='not_attempted_after_abort' else 'first_attempt_failures']+=1
                passes.append(None);continue
            if not p.exists():raise ValueError('successful_capture_missing')
            response=read(p)
            if response['status']!='ok' or response['nonce']!=m['nonce'] or response['slot']!=slot or response['pass']!=repeat:raise ValueError('invalid_capture')
            layout.verify_membership(response)
            raw=[o['id'] for o in response['observations']]
            if collections.Counter(raw)!=collections.Counter(i for row in response['interpretedRowIDs'] for i in row):raise ValueError('interpretation_membership')
            if not response['replayEqual'] or not response['originalBytesEqual'] or response['draftCanFinalize']:raise ValueError('app_boundary_failed')
            if response.get('storeRoundtripEqual') is False or response.get('reviewInputEqual') is False:raise ValueError('roundtrip_failed')
            report['source_preservation_checks']+=1;report['successful_attempts']+=1
            passes.append(response)
        first,second=passes
        if first is None:
            counter('verdicts',{'failed':1});continue
        if second is not None:report['repeat_pairs_equal']+=int(stable(first)==stable(second))
        before=read(ROOT/'private-receipts/evaluation/p2-03-final/fresh-after'/(group['purchase_id']+'-pass1.json'))
        report['full_parsed_equal_previous_mac']+=int(layout.full_parsed(first)==layout.full_parsed(before))
        expected=checked[group['purchase_id']];old=legacy.amount_score(legacy.normalize(first),expected)
        actual=fields_actual(first['draftFields']);scored=score(actual,refs[slot],first['observations']);failures=stage_failures(first,expected)
        counter('legacy',old);counter('verdicts',{scored['verdict']:1});counter('coverage',scored['reference_coverage']);counter('v2_counts',scored['counts'])
        counter('failure_suspects',collections.Counter(f['category'] for f in failures))
        for key,values in scored['fields'].items():report['field_results'][key]=dict(collections.Counter(report['field_results'].get(key,{}))+collections.Counter(values))
        store=report['stores'].setdefault(group['store'],{'purchases':0,'legacy':{},'verdicts':{},'v2_counts':{}})
        store['purchases']+=1
        for key,values in [('legacy',old),('verdicts',{scored['verdict']:1}),('v2_counts',scored['counts'])]:store[key]=dict(collections.Counter(store[key])+collections.Counter(values))
        same=first['fields']==first['draftFields']
        if first['fields'].get('currency') is None:
            report['currency_unresolved_receipts']+=1
            structured={line['id']:line for line in first['fields']['items']+first['fields']['adjustments']}
            report['parser_line_amounts_blocked_by_currency']+=sum(line.get('amount') is not None and structured[line['id']].get('amount') is None for line in first['parsed']['lines'])
            report['parser_summary_amounts_blocked_by_currency']+=sum(first['parsed'].get(k) is not None and first['fields'].get(k) is None for k in ('subtotal','total'))
        report['storage_eligible']+=int(first['draftCanSave'])
        report['storage_attempted']+=int('storeRoundtripEqual' in first)
        report['conversion_fields_equal']+=int(same)
        report['draft_storage_roundtrips_equal']+=int(first.get('storeRoundtripEqual') is True and first.get('reviewInputEqual') is True)
        times.append(first['importToReviewMS']);gaps.append(first['mainActorPollMaxGapMS'])
        if second:repeat_times.append(second['importToReviewMS'])
        records.append({'slot':slot,'score':scored,'legacy':dict(old),'failure_suspects':failures,'conversion_equal':same})
    def timing(v):return {'count':len(v),'median_ms':round(statistics.median(v),2),'max_ms':round(max(v),2)} if v else {'count':0}
    report['timing']={'first_imports':timing(times),'repeat_imports':timing(repeat_times),'main_actor_poll_gap':timing(gaps),'first_process_import_ms':round(times[0],2) if times else None}
    report['environment']=m['simulator'];report['source_hashes']=m['sources']
    report['limits']=['Five exposed development purchases; zero held-out purchases.','Expanded fields retain unreviewed reference states; no invented labels.',
                      'Unique kind/description matching is a proxy without source regions; duplicate identities remain ambiguous.',
                      'Hosted Simulator test calls actual Files import handler, not picker UI or camera.','First/repeat timings include 20ms polling; no cold-cache/phone or FPS claim.',
                      'Failure-stage categories are suspects unless captured boundary loss is proven.','No user corrections or reference injection during automatic capture.']
    return report,records

def review_page(output,m,records):
    # Private, offline-only reference workflow. No external resources, no uploads, no auto approval.
    refs=read(output/'reference-v2.json')
    parts=['<!doctype html><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; img-src file:; style-src \'unsafe-inline\'">',
           '<title>Private Phase 4 reference review</title><style>body{font:16px system-ui;max-width:1100px;margin:32px auto;padding:20px}pre{white-space:pre-wrap;overflow-wrap:anywhere}img{max-width:100%}section{border-top:1px solid #aaa;padding:24px 0}</style>',
           '<h1>Phase 4 private reference review</h1><p>Read-only. No receipt data is uploaded. Existing labels remain unchanged. New dimensions are unreviewed. Review only requested gaps against the original, then provide a separate checked sidecar; never overwrite historical labels.</p>']
    for slot,group in enumerate(m['groups']):
        path=Path(group['images'][0]['path'])
        parts+=['<section><h2>Receipt '+str(slot+1)+'</h2><p><a href="'+html.escape(path.as_uri(),quote=True)+'">Open original image locally</a></p>',
                '<h3>Reference coverage and checked values</h3><pre>'+html.escape(json.dumps(refs['receipts'][slot],ensure_ascii=False,indent=2))+'</pre>']
        r=next((r for r in records if r['slot']==slot),None)
        if r:parts+=['<h3>Fields needing investigation</h3><pre>'+html.escape(json.dumps(r,indent=2))+'</pre>']
        parts+=['</section>']
    (output/'review.html').write_text('\n'.join(parts));(output/'review.html').chmod(0o600)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','collect','verify']);p.add_argument('--run',required=True);p.add_argument('--device');p.add_argument('--build',default='/tmp/sliplet-p401-build')
    try:
        args=p.parse_args()
        if args.action=='prepare':prepare(args)
        elif args.action=='collect':collect(args)
        else:
            output=private(args.run);report,records=evaluate(output)
            if report!=read(output/'aggregate.json') or records!=read(output/'private-scores.json'):raise ValueError('report_mismatch')
            print('Verified capture membership, source/input/reference hashes, repeat values and recomputed scores.')
    except Exception:
        print('P4-01 operation failed; private details suppressed.',file=sys.stderr);sys.exit(1)
