"""Aggregate retained structured fields; presence is not verified correctness."""
from collections import Counter
import json
import structured_trial as trial


def report():
    counts=Counter();issues=Counter();coverage=Counter();rows=0;received=0
    for slot in range(5):
        path=trial.OUT/'responses'/f'real-{slot}-1.json'
        if not path.exists():continue
        result=trial.load(path)
        if result['status']!='received':continue
        received+=1;actual=result['actual'];validation=result['validation']
        issues.update(validation['issues'])
        counts['invalid_fields']+=len(validation['invalid_fields'])
        counts['non_accounting_rows_retained']+=len(actual['nonAccountingRows'])
        counts['receipts_with_printed_tax_legend']+=actual['taxLegend'] is not None
        for row in actual['lines']:
            rows+=1
            for key in ('sku','taxMarker','quantity','unit','unitPrice','unitPriceDecimal','taxBase','rate','rawText'):
                coverage[key]+=row.get(key) is not None
    result={'received_real_receipts':received,'accounting_rows':rows,'field_presence_counts':dict(coverage),
            'counts':dict(counts),'receipt_issue_counts':dict(issues),
            'field_presence_is_not_accuracy':True,'taxability_inferred':False,
            'quantity_unit_price_accuracy_not_established_by_existing_reference':True}
    trial.write(trial.OUT/'structured-field-diagnostics.json',result)
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    try:report()
    except Exception:raise SystemExit('diagnostics_stopped_private_details_suppressed')
