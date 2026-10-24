"""Frozen P8-02B scorer: original reference and comparator, no private labels in requests."""
import collections,json,sys
from decimal import Decimal
from pathlib import Path
import run as r
import importlib.util
spec=importlib.util.spec_from_file_location('prior_comparator',r.ROOT/'evaluation/receipt-lab/lab.py');prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
def norm(x):return ' '.join((x or '').upper().split())
def eq(a,b,k):
    if k=='quantity':return (Decimal(a) if a is not None else None)==(Decimal(b) if b is not None else None)
    return norm(a)==norm(b) if k in ['merchant','description'] else a==b

def fictional():
    cases=[]
    for e in r.load(r.HERE/'fixtures/manifest.json'):
        path=r.OUT/'responses'/('fictional-'+e['id']+'.json')
        if not path.exists():continue
        calibrated=r.OUT/'calibrated'/path.name
        d=r.load(calibrated if calibrated.exists() else path);x={'case':e['id'],'status':d['status'],'exact':False}
        if d['status']=='received':
            actual=d['actual'];expected=e['expected']
            fields={k:eq(actual.get(k),v,k) for k,v in expected.items() if k!='lines'}
            rows=[{k:i<len(actual['lines']) and eq(actual['lines'][i].get(k),v,k) for k,v in row.items()} for i,row in enumerate(expected['lines'])]
            x.update(fields=fields,rows=rows,expected_rows=len(expected['lines']),actual_rows=len(actual['lines']),issues=d['validation']['issues'])
            x['exact']=all(fields.values()) and len(actual['lines'])==len(expected['lines']) and all(all(v.values()) for v in rows)
        cases.append(x)
    report={'task':'P8-02B','cases_run':len(cases),'passed_cases':sum(x['exact'] for x in cases),'results':cases}
    r.write(r.OUT/'fictional-score.json',report)
    print(json.dumps({'fictional_cases':len(cases),'passed':report['passed_cases'],'failed_cases':[x['case'] for x in cases if not x['exact']]}));return report

def real():
    refs_path=r.ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json';refs=r.load(refs_path)['receipts']
    passes=[];ledger=[]
    for pair in (1,2):
        counts=collections.Counter();fields={};adjustments=collections.Counter();losses=collections.Counter();statuses=collections.Counter();issues=collections.Counter();usage=collections.Counter();elapsed=[]
        for slot,ref in enumerate(refs):
            path=r.OUT/'responses'/f'real-{slot}-{pair}.json'
            if not path.exists():raise ValueError('incomplete_pass')
            d=r.load(path);statuses[d['status']]+=1;elapsed.append(d['elapsed_seconds']);usage.update({k:v for k,v in d.get('usage',{}).items() if k in ('prompt_tokens','completion_tokens','total_tokens')})
            actual=d.get('actual',dict(merchant=None,date=None,currency=None,subtotal=None,total=None,lines=[]));obs=d.get('observations',[])
            score=prior.score(actual,ref,obs);capture=r.load(r.ROOT/f'private-receipts/evaluation/p7-08-final/captures/capture-{slot}-{pair}.json');baseline=prior.score(prior.fields_actual(capture['reloadedFields']),ref,capture['observations'])
            counts.update({k:score['counts'].get(k,0) for k in ['exact_purchase_pairs','expected_purchases','actual_purchases','missing_line_proxies','unrelated_unmatched_actual_lines','ambiguous_group_count_mismatch']})
            for k in ref['fields']:
                fields.setdefault(k,collections.Counter()).update(score['fields'][k])
                if baseline['fields'][k].get('correct',0)>score['fields'][k].get('correct',0):losses['summary_fields']+=1
            for x,b in zip(score['line_results'],baseline['line_results']):
                exact=all(x['outcomes'].get(k)=='correct' for k in ['kind','description','amount']);old=all(b['outcomes'].get(k)=='correct' for k in ['kind','description','amount'])
                if old and not exact:losses['previously_exact_rows']+=1
                if ref['lines'][x['reference_line']]['fields']['kind'].get('value')!='purchase':adjustments['expected']+=1;adjustments['exact']+=int(exact)
            issues.update(d.get('validation',{}).get('issues',[]))
            ledger.append({'pass':pair,'slot':slot,'score':score,'baseline_score':baseline})
        passes.append({'pass':pair,'counts':dict(counts),'summary_fields':{k:dict(v) for k,v in fields.items()},'adjustments':dict(adjustments),'previously_correct_lost':dict(losses),'statuses':dict(statuses),'validation_issues':dict(issues),'usage':dict(usage),'elapsed_seconds':elapsed})
    report={'task':'P8-02B','exposed_receipts':5,'held_out_receipts':0,'baseline_exact_purchases':57,'denominator':65,'source_claims_verified':False,'real_quantity_labels_available':False,'production_changed':False,'passes':passes}
    r.write(r.OUT/'real-score.json',report);r.write(r.OUT/'error-ledger.json',ledger);print(json.dumps(report,indent=2));return report
if __name__=='__main__':
    try:
        if sys.argv[1:]==['fictional']:fictional()
        elif sys.argv[1:]==['real']:real()
        else:raise ValueError()
    except Exception:sys.exit('Scoring stopped; private details suppressed.')
