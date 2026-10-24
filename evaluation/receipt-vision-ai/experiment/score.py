"""Private P8-02 scores, with aggregate-only stdout and public evidence."""
import collections,decimal,difflib,importlib.util,json,re,sys
from pathlib import Path
import runner as r
spec=importlib.util.spec_from_file_location('prior_lab',r.ROOT/'evaluation/receipt-lab/lab.py')
prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)

def norm(s):return ' '.join((s or '').upper().split())
def number(s):return decimal.Decimal(s) if s is not None else None
def minor(s):
    if s is None:return None
    n=number(s)*100
    if n!=n.to_integral_value():return None
    return int(n)
def equal(a,b,key):
    if key in ('amount','subtotal','total','quantity','unit_price'):return number(a)==number(b)
    return norm(a)==norm(b) if key in ('merchant','description') else a==b

def fictional():
    expected=r.load(r.HERE/'expected.json');results=[]
    for name,e in list(expected.items())+[('weighted-ocr',expected['weighted'])]:
        path=r.OUT/'responses'/f'fictional-{name}.json'
        if not path.exists():continue
        response=r.load(path);res={'case':name,'status':response['status'],'exact':False}
        if response['status']=='received':
            c=response['candidate'];fields={k:equal(c[k]['value'],v,k) for k,v in e['fields'].items()}
            matches=[]
            for i,row in enumerate(e['rows']):
                matches.append({k:i<len(c['lines']) and equal(c['lines'][i].get(k),v,k) for k,v in row.items()})
            res.update(fields=fields,expected_rows=len(e['rows']),actual_rows=len(c['lines']),exact_ordered_rows=sum(all(x.values()) for x in matches),row_outcomes=matches,issues=response['validation']['issues'])
            res['exact']=all(fields.values()) and len(c['lines'])==len(e['rows']) and all(all(x.values()) for x in matches)
        results.append(res)
    aggregate={'cases_run':len(results),'exact_cases':sum(x['exact'] for x in results),'results':results}
    r.write(r.OUT/'fictional-score.json',aggregate)
    if len(results)==12:
        by={x['case']:x for x in results};use_ocr=not by['weighted']['exact'] and by['weighted-ocr']['exact']
        selection={'variant':'image-plus-ocr' if use_ocr else 'image-only','rule':'Frozen weighted comparison; OCR must fix a core failure without new field errors.','fictional_exact_cases':aggregate['exact_cases'],'private_results_seen':False,'expected_sha256':r.digest((r.HERE/'expected.json').read_bytes()),'image_only_weighted_exact':by['weighted']['exact'],'ocr_weighted_exact':by['weighted-ocr']['exact']}
        target=r.OUT/'selection.json'
        if target.exists() and r.load(target)!=selection:raise ValueError('selection_changed')
        r.write(target,selection)
    print(json.dumps({'fictional_cases':len(results),'exact_cases':aggregate['exact_cases'],'failed_cases':[x['case'] for x in results if not x['exact']]}))
    return aggregate

def source_anchors(line,input_images,observations):
    """Use candidate text and unlabelled original OCR, never reference answers or prices.
    A unique description match anchors an existing OCR occurrence. Otherwise retain
    model boxes as unverified claims, with an explicit source-method count.
    """
    description=norm(line.get('description'))
    candidates=[]
    if len(description)>=4:
        for o in observations:
            text=norm(o['text'])
            # Compare only candidate description to raw OCR, with no expected amount tiebreak.
            score=1.0 if description==text else difflib.SequenceMatcher(None,description,text).ratio()
            if score>=.86:candidates.append((score,o))
    candidates.sort(key=lambda x:x[0],reverse=True)
    if candidates and (len(candidates)==1 or candidates[0][0]-candidates[1][0]>=.08):
        return [candidates[0][1]['id']],[],'unique_raw_ocr_description'
    imgs={im['id']:im for im in input_images};synthetic=[]
    for i,e in enumerate(line['evidence']):
        b=e['box'];im=imgs.get(e['image_id'])
        if b is None or im is None:continue
        x0,y0,x1,y1=im['rect'];w,h=im['size']
        left=(x0+b[0]*(x1-x0))/w;right=(x0+b[2]*(x1-x0))/w
        top=(y0+b[1]*(y1-y0))/h;bottom=(y0+b[3]*(y1-y0))/h
        synthetic.append({'id':f"model-{line['id']}-{i}",'boundingBox':{'x':left,'y':1-bottom,'width':right-left,'height':bottom-top},'text':''})
    return [x['id'] for x in synthetic],synthetic,'model_box_claim' if synthetic else 'unresolved'

def canonical(c,input_images,observations):
    actual={k:c[k]['value'] for k in ('merchant','date','currency')}
    actual.update({k:minor(c[k]['value']) for k in ('subtotal','total')});actual['lines']=[]
    observations=list(observations);methods=collections.Counter();supplemental=collections.Counter()
    for line in c['lines']:
        if line['kind'] in ('payment','change'):
            supplemental[line['kind']]+=1;continue # No payment labels in frozen reference: do not call these invented items.
        ids,new,method=source_anchors(line,input_images,observations);observations+=new;methods[method]+=1
        actual['lines'].append({'id':line['id'],'kind':line['kind'],'description':line['description'],'amount':minor(line['amount']),'quantity':line['quantity'],'unit':line['unit'],'unitPrice':minor(line['unit_price']),'sku':None,'taxMarker':None,'rate':None,'sourceLineIDs':ids})
    return actual,observations,dict(methods),dict(supplemental)

def empty():return dict(merchant=None,date=None,currency=None,subtotal=None,total=None,lines=[])

def real_scores():
    refs_path=r.ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json'
    refs=r.load(refs_path)['receipts'];passes=[];ledger=[]
    for pair in (1,2):
        count=collections.Counter();fields={};adjustments=collections.Counter();methods=collections.Counter();status=collections.Counter();lost=collections.Counter();extra=collections.Counter();latency=[];usage=collections.Counter()
        for slot,ref in enumerate(refs):
            path=r.OUT/'responses'/f'real-{slot}-{pair}-0.json'
            if not path.exists():raise ValueError('real_pass_incomplete')
            response=r.load(path);status[response['status']]+=1;latency.append(response['elapsed_seconds'])
            for k in ('prompt_tokens','completion_tokens','total_tokens'):usage[k]+=response.get('usage',{}).get(k,0)
            capture=r.load(r.ROOT/f'private-receipts/evaluation/p7-08-final/captures/capture-{slot}-{pair}.json')
            observations=capture['observations'];actual=empty();source={};supplemental={}
            if (r.OUT/'responses'/f'real-{slot}-{pair}-1.json').exists():raise ValueError('multi_request_merge_requires_source_review')
            if response['status']=='received':actual,observations,source,supplemental=canonical(response['candidate'],response['input_images'],observations)
            score=prior.score(actual,ref,observations)
            baseline=prior.score(prior.fields_actual(capture['reloadedFields']),ref,capture['observations'])
            for k in ('exact_purchase_pairs','expected_purchases','actual_purchases','missing_line_proxies','unrelated_unmatched_actual_lines','ambiguous_group_count_mismatch'):count[k]+=score['counts'].get(k,0)
            for key in ref['fields']:
                fields.setdefault(key,collections.Counter()).update(score['fields'][key])
                if baseline['fields'][key].get('correct',0)>score['fields'][key].get('correct',0):lost['summary_fields']+=1
            for row,old in zip(score['line_results'],baseline['line_results']):
                kind=ref['lines'][row['reference_line']]['fields']['kind'].get('value');exact=all(row['outcomes'].get(k)=='correct' for k in ('kind','description','amount'))
                old_exact=all(old['outcomes'].get(k)=='correct' for k in ('kind','description','amount'))
                if old_exact and not exact:lost['previously_exact_rows']+=1
                for k,v in old['outcomes'].items():
                    if v=='correct' and row['outcomes'].get(k)!='correct':lost['line_fields']+=1
                if kind!='purchase':
                    adjustments['expected']+=1;adjustments['exact']+=int(exact)
            methods.update(source);extra.update(supplemental)
            ledger.append({'pass':pair,'slot':slot,'score':score,'baseline_score':baseline,'source_methods':source,'canonical':actual})
        passes.append({'pass':pair,'counts':dict(count),'summary_fields':{k:dict(v) for k,v in fields.items()},'adjustments':dict(adjustments),'previously_correct_lost':dict(lost),'source_methods':dict(methods),'statuses':dict(status),'unscored_payment_change_rows':dict(extra),'latency_seconds':latency,'usage':dict(usage)})
    report={'task':'P8-02','exposed_receipts':5,'held_out_receipts':0,'passes':passes,'baseline_exact_purchases':57,'baseline_expected_purchases':65,'baseline_correct_totals':3,'baseline_correct_adjustments':4,'quantity_unit_price_labels_available':False,'model_source_claims_verified':False,'production_changed':False,'private_reference_sha256':r.digest(refs_path.read_bytes())}
    r.write(r.OUT/'real-score.json',report);r.write(r.OUT/'error-ledger.json',ledger)
    safe={k:v for k,v in report.items() if k!='private_reference_sha256'}
    print(json.dumps(safe,indent=2));return safe
if __name__=='__main__':
    try:
        if sys.argv[1:]==['fictional']:fictional()
        elif sys.argv[1:]==['real']:real_scores()
        else:raise ValueError()
    except Exception:sys.exit('Scoring stopped; private details suppressed.')
