"""Report an interrupted experiment without presenting its subset as the full benchmark."""
import collections,json
import score as s
r=s.r

def report():
    refs=r.load(r.ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json')['receipts']
    totals=collections.Counter();fields={};issues=collections.Counter();statuses=collections.Counter();ledger=[]
    for pair in (1,2):
        for slot,ref in enumerate(refs):
            path=r.OUT/'responses'/f'real-{slot}-{pair}.json'
            if not path.exists():statuses['not_run']+=1;continue
            d=r.load(path);statuses[d['status']]+=1
            if d['status']!='received':continue
            value=s.prior.score(d['actual'],ref,d['observations'])
            capture=r.load(r.ROOT/f'private-receipts/evaluation/p7-08-final/captures/capture-{slot}-{pair}.json')
            baseline=s.prior.score(s.prior.fields_actual(capture['reloadedFields']),ref,capture['observations'])
            totals['completed_receipt_passes']+=1
            totals['exact_purchases']+=value['counts']['exact_purchase_pairs'];totals['expected_purchases_in_completed_subset']+=value['counts']['expected_purchases'];totals['baseline_exact_same_subset']+=baseline['counts']['exact_purchase_pairs']
            totals['missing_line_proxies']+=value['counts']['missing_line_proxies'];totals['unmatched_output_proxies']+=value['counts']['unrelated_unmatched_actual_lines']
            for k in ref['fields']:
                fields.setdefault(k,collections.Counter()).update(value['fields'][k])
                totals['previously_correct_summary_fields_lost']+=max(0,baseline['fields'][k].get('correct',0)-value['fields'][k].get('correct',0))
            for x,b in zip(value['line_results'],baseline['line_results']):
                exact=all(x['outcomes'].get(k)=='correct' for k in ('kind','description','amount'));old=all(b['outcomes'].get(k)=='correct' for k in ('kind','description','amount'))
                totals['previously_exact_rows_lost']+=old and not exact
                if ref['lines'][x['reference_line']]['fields']['kind'].get('value')!='purchase':totals['expected_adjustments']+=1;totals['exact_adjustments']+=exact
            issues.update(d['validation']['issues']);ledger.append({'pass':pair,'slot':slot,'score':value,'baseline':baseline})
    result={'task':'P8-02B','status':'stopped_on_provider_limit_not_promoted','fictional':{'raw_exact':3,'calibrated_exact':6,'cases':6,'holdout':False},'real_statuses':dict(statuses),'completed_subset_only':dict(totals),'summary_fields_completed_subset':{k:dict(v) for k,v in fields.items()},'validation_issues':dict(issues),'full_pass_denominator':65,'completed_exact_over_full_first_pass_denominator':totals['exact_purchases'],'full_benchmark_complete':False,'repeated_run_complete':False,'real_quantity_labels_available':False,'exposed_corpus_receipts':5,'held_out_receipts':0,'production_changed':False}
    r.write(r.OUT/'partial-score.json',result);r.write(r.OUT/'partial-error-ledger.json',ledger);print(json.dumps(result,indent=2));return result
if __name__=='__main__':report()
