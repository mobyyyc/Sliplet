"""Post-run aggregate audit; strict score preserved beside group correctness."""
import collections,importlib.util,json,sys
import correct_real_five as c
from duplicate_groups import assess
n=c.n

def audit():
    c.freeze()
    spec=importlib.util.spec_from_file_location('fixed_scorer',n.c.base.HERE/'score.py')
    scoring=importlib.util.module_from_spec(spec);spec.loader.exec_module(scoring)
    refs=n.c.load(n.c.ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json')['receipts']
    current=collections.Counter();baseline=collections.Counter();invalid=collections.Counter()
    statuses=collections.Counter();field_outcomes={};reconcile=0
    for slot,source in enumerate(refs):
        path=c.r.OUT/'responses'/f'real-{slot}-1.json'
        result=n.c.load(path) if path.exists() else {'status':'not_run'}
        statuses[result['status']]+=1
        actual=result.get('actual',dict(merchant=None,date=None,currency=None,subtotal=None,total=None,lines=[]))
        ref=scoring.without_regions(source)
        score=scoring.prior.score(actual,ref,[])
        capture=n.c.load(n.c.ROOT/f'private-receipts/evaluation/p7-08-final/captures/capture-{slot}-1.json')
        old=scoring.prior.fields_actual(capture['reloadedFields'])
        oldscore=scoring.prior.score(old,ref,[])
        for target,value,sc in [(current,actual,score),(baseline,old,oldscore)]:
            group=assess(value,ref,sc,scoring.prior.legacy.e.norm)
            target.update({k:v for k,v in group.items() if type(v) is int})
        for field in ['kind','description','amount','quantity','unit','unitPrice']:
            field_outcomes.setdefault(field,collections.Counter()).update(score['fields'].get(field,{}))
        validation=result.get('validation',{})
        invalid['fields_flagged']+=len(validation.get('invalid_fields',[]))
        reconcile+='total_conflict' in validation.get('issues',[])
    result={'task':'real correction supplementary audit','statuses':dict(statuses),'candidate':dict(current),'baseline_same_metric':dict(baseline),'line_field_outcomes':{k:dict(v) for k,v in field_outcomes.items()},'invalid_fields':dict(invalid),'receipts_with_total_conflict':reconcile,'metric_added_after_calls':True,'individual_duplicate_identity_verified':False,'labels_unchanged':True}
    n.c.write(c.r.OUT/'supplementary-audit.json',result)
    print(json.dumps(result,indent=2));return result

if __name__=='__main__':
    try:audit()
    except Exception:sys.exit('audit_stopped_private_details_suppressed')
