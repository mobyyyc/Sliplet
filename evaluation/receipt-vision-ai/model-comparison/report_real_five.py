"""Private receipt scoring; stdout/public artifacts contain aggregates only."""
import collections,importlib.util,json,sys
from pathlib import Path
import real_five as r
n=r.n

def decode(envelope):
    choices=envelope.get('candidates',[])
    if len(choices)!=1 or choices[0].get('finishReason')!='STOP':raise n.c.base.lab.LabError('incomplete_or_blocked')
    text=''.join(p.get('text','') for p in choices[0]['content']['parts'] if not p.get('thought'))
    text=text.strip();wrapped=False
    if text.startswith('```json\n') and text.endswith('```'):
        text=text[8:-3];wrapped=True
    candidate=n.c.base.lab.parse_json(text)
    actual,validation=n.c.base.extract.canonical(candidate)
    return actual,validation,wrapped

def report():
    r.freeze()
    spec=importlib.util.spec_from_file_location('fixed_real_scorer',n.c.base.HERE/'score.py')
    scoring=importlib.util.module_from_spec(spec);spec.loader.exec_module(scoring)
    refs=n.c.load(n.c.ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json')['receipts']
    calls=n.c.load(r.OUT/'calls.json');assert len(calls)<=5 and len({c['name'] for c in calls})==len(calls)
    images=n.c.old.verified_real_images()
    counts=collections.Counter();base_counts=collections.Counter();statuses=collections.Counter();fields={};losses=collections.Counter();ledger=[];usable=0;wrappers=0;recovered=0;decode_errors=collections.Counter();usable_counts=collections.Counter();usable_baseline=collections.Counter()
    keys=['exact_purchase_pairs','expected_purchases','missing_line_proxies','unrelated_unmatched_actual_lines','ambiguous_identity','ambiguous_group_count_mismatch']
    for slot,source in enumerate(refs):
        name=f'real-{slot}-1';path=r.OUT/'responses'/f'{name}.json'
        result=n.c.load(path) if path.exists() else {'status':'not_run'}
        statuses[result['status']]+=1
        actual=dict(merchant=None,date=None,currency=None,subtotal=None,total=None,lines=[])
        diagnostic=None;validation=None;is_usable=False
        if path.exists():
            call=next(c for c in calls if c['name']==name);assert call['kind']=='real'
            request=r.pilot.body(images[slot][0]['data'],True)
            assert request==n.c.load(r.OUT/'requests'/f'{name}.json')
            assert call['payload_sha256']==result['payload_sha256']==n.c.old.digest(json.dumps(request,sort_keys=True).encode())
            raw=r.OUT/'raw'/f'{name}.json'
            if raw.exists():
                try:
                    actual,validation,wrapped=decode(n.c.load(raw));is_usable=True;usable+=1;wrappers+=wrapped;recovered+=result['status']!='received'
                    if result['status']=='received':assert actual==result['actual']
                except n.c.base.lab.LabError as error:
                    diagnostic=str(error);decode_errors[diagnostic]+=1
        ref=scoring.without_regions(source)
        score=scoring.prior.score(actual,ref,[])
        capture=n.c.load(n.c.ROOT/f'private-receipts/evaluation/p7-08-final/captures/capture-{slot}-1.json')
        baseline=scoring.prior.score(scoring.prior.fields_actual(capture['reloadedFields']),ref,[])
        counts.update({k:score['counts'].get(k,0) for k in keys});base_counts.update({k:baseline['counts'].get(k,0) for k in keys})
        if is_usable:
            usable_counts.update({k:score['counts'].get(k,0) for k in keys});usable_baseline.update({k:baseline['counts'].get(k,0) for k in keys})
        for key in ref['fields']:
            fields.setdefault(key,collections.Counter()).update(score['fields'][key])
            losses['summary_fields']+=max(0,baseline['fields'][key].get('correct',0)-score['fields'][key].get('correct',0))
        for x,b in zip(score['line_results'],baseline['line_results']):
            exact=all(x['outcomes'].get(k)=='correct' for k in ['kind','description','amount'])
            old=all(b['outcomes'].get(k)=='correct' for k in ['kind','description','amount'])
            losses['previously_exact_rows']+=old and not exact
            if ref['lines'][x['reference_line']]['fields']['kind'].get('value')!='purchase':
                counts['expected_adjustments']+=1;counts['exact_adjustments']+=exact
        ledger.append({'slot':slot,'transport_status':result['status'],'offline_decode_error':diagnostic,'score':score,'baseline':baseline,'validation':validation})
    summary={'task':'P8-02E real five','attempts':len(calls),'planned':5,'transport_statuses':dict(statuses),'offline_usable_candidates':usable,'offline_rejection_categories':dict(decode_errors),'outer_fences_removed':wrappers,'format_only_recoveries':recovered,'usable_subset_counts':dict(usable_counts),'usable_subset_baseline':dict(usable_baseline),'counts':dict(counts),'baseline_same_matcher':dict(base_counts),'fields':{k:dict(v) for k,v in fields.items()},'losses':dict(losses),'ocr_used':False,'exposed_receipts':5,'held_out_receipts':0,'app_changed':False,'reference_unchanged':True}
    n.c.write(r.OUT/'error-ledger.json',ledger);n.c.write(r.OUT/'real-score.json',summary)
    n.c.write(r.OUT/'verification.json',{'verified':True,'requests_reproduced':True,'attempts':len(calls),'labels_unchanged':True,'raw_results_preserved':True})
    print(json.dumps(summary,indent=2));return summary

if __name__=='__main__':
    try:report()
    except Exception:sys.exit('verification_stopped_private_details_suppressed')
