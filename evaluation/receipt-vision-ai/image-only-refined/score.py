"""Image-only scoring; immutable labels, no amount-assisted or coordinate pairing."""
import collections,copy,importlib.util,json,sys
from decimal import Decimal
import run as r
spec=importlib.util.spec_from_file_location('prior_comparator',r.ROOT/'evaluation/receipt-lab/lab.py');prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
def eq(a,b,k):
    if k=='quantity':return (Decimal(a) if a is not None else None)==(Decimal(b) if b is not None else None)
    if k in ('description','merchant'):return ' '.join((a or '').upper().split())==' '.join((b or '').upper().split())
    return a==b

def fictional():
    cases=[]
    for f in r.load(r.FIXTURES/'manifest.json'):
        path=r.OUT/'responses'/('fictional-'+f['id']+'.json');x={'case':f['id'],'status':'not_run','exact':False}
        if path.exists():
            d=r.load(path);x['status']=d['status']
            if d['status']=='received':
                actual=d['actual'];expected=f['expected'];fields={k:eq(actual.get(k),v,k) for k,v in expected.items() if k!='lines'}
                rows=[{k:i<len(actual['lines']) and eq(actual['lines'][i].get(k),v,k) for k,v in row.items()} for i,row in enumerate(expected['lines'])]
                x.update(fields=fields,rows=rows,expected_rows=len(expected['lines']),actual_rows=len(actual['lines']),issues=d['validation']['issues'])
                x['exact']=all(fields.values()) and len(actual['lines'])==len(expected['lines']) and all(all(row.values()) for row in rows)
        cases.append(x)
    result={'task':'P8-02D','cases_planned':6,'cases_run':sum(x['status']!='not_run' for x in cases),'passed_cases':sum(x['exact'] for x in cases),'results':cases,'ocr_used':False,'calibration_after_calls':False}
    r.write(r.OUT/'fictional-score.json',result);print(json.dumps(result,indent=2));return result

def without_regions(ref):
    result=copy.deepcopy(ref)
    for line in result['lines']:line['original_regions']=[]
    return result

def real():
    refs=r.load(r.ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json')['receipts'];passes=[];ledger=[]
    for pair in (1,2):
        counts=collections.Counter();baseline_counts=collections.Counter();statuses=collections.Counter();fields={};losses=collections.Counter()
        for slot,source in enumerate(refs):
            ref=without_regions(source);path=r.OUT/'responses'/f'real-{slot}-{pair}.json'
            d=r.load(path) if path.exists() else {'status':'not_run'};statuses[d['status']]+=1
            actual=d.get('actual',dict(merchant=None,date=None,currency=None,subtotal=None,total=None,lines=[]))
            value=prior.score(actual,ref,[]);cap=r.load(r.ROOT/f'private-receipts/evaluation/p7-08-final/captures/capture-{slot}-{pair}.json');baseline=prior.score(prior.fields_actual(cap['reloadedFields']),ref,[])
            keys=['exact_purchase_pairs','expected_purchases','missing_line_proxies','unrelated_unmatched_actual_lines','ambiguous_identity','ambiguous_group_count_mismatch']
            counts.update({k:value['counts'].get(k,0) for k in keys});baseline_counts.update({k:baseline['counts'].get(k,0) for k in keys})
            for k in ref['fields']:
                fields.setdefault(k,collections.Counter()).update(value['fields'][k])
                losses['summary_fields']+=max(0,baseline['fields'][k].get('correct',0)-value['fields'][k].get('correct',0))
            for x,b in zip(value['line_results'],baseline['line_results']):
                exact=all(x['outcomes'].get(k)=='correct' for k in ['kind','description','amount']);old=all(b['outcomes'].get(k)=='correct' for k in ['kind','description','amount'])
                losses['previously_exact_rows']+=old and not exact
                if ref['lines'][x['reference_line']]['fields']['kind'].get('value')!='purchase':counts['expected_adjustments']+=1;counts['exact_adjustments']+=exact
            ledger.append({'pass':pair,'slot':slot,'score':value,'baseline':baseline})
        passes.append({'pass':pair,'statuses':dict(statuses),'counts':dict(counts),'baseline_same_matcher':dict(baseline_counts),'fields':{k:dict(v) for k,v in fields.items()},'losses':dict(losses)})
    result={'task':'P8-02D','passes':passes,'matching':'unique_kind_description_no_coordinates_or_amount_tiebreak','original_reference_file_unchanged':True,'ocr_used':False,'exposed_receipts':5,'held_out_receipts':0,'production_changed':False}
    r.write(r.OUT/'real-score.json',result);r.write(r.OUT/'error-ledger.json',ledger);print(json.dumps(result,indent=2));return result
if __name__=='__main__':
    try:
        if sys.argv[1:]==['fictional']:fictional()
        elif sys.argv[1:]==['real']:real()
        else:raise ValueError()
    except Exception:sys.exit('Scoring stopped; private details suppressed.')
