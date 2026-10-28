"""Version confirmed reference corrections and rescore retained outputs locally.

No inference, credentials or network calls. The seven review cases are explicit
source-audit correspondences, not a receipt-recognition algorithm. No fuzzy or
amount-assisted matching. Original references, candidates and scores stay frozen.
"""
import copy
from collections import Counter
from decimal import Decimal
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import source_audit as audit
from duplicate_groups import assess

ROOT = audit.ROOT
OUT = audit.PRIVATE / 'p8-02e/reference-repair-01'
RESULT = OUT / 'final'
REFERENCE = audit.PRIVATE / 'p7-05-final/reference-v3.json'
EXPORT = ROOT / 'sliplet-p8-reference-checked.json'
# Visually inspected name-only differences, covered by the confirmed naming rule.
# receipt, reference row, retained output row (all one based).
POLICY_NAMES = [(1,21,10),(2,20,8),(2,21,10),(2,22,16),
                (3,8,3),(4,15,8),(4,16,16),(5,1,3)]
# Price-column markers visually confirmed in the source; never strip arbitrary suffixes.
PRICE_MARKER_CASES = {'case-1', 'case-5'}
PRICE_MARKER_POLICY_ROWS = {(2,22)}


def load(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_once(path, value):
    if path.exists():
        if load(path) != value:
            raise ValueError('existing_evidence_differs')
        return
    with path.open('x') as stream:
        json.dump(value, stream, indent=2)
    path.chmod(0o600)


def cents(value):
    if not isinstance(value, str) or not re.fullmatch(r'-?\d+(?:\.\d{1,2})?',value):
        raise ValueError('invalid_checked_amount')
    result = int(Decimal(value)*100)
    if abs(result)>10**11:
        raise ValueError('amount_out_of_range')
    return result


def validate_export(data, proposal, reference_hash):
    if data.get('schemaVersion') != 1 or data.get('complete') is not True:
        raise ValueError('incomplete_review')
    if data.get('reviewID') != proposal['reviewID'] or data.get('referenceHash') != reference_hash or proposal['referenceHash'] != reference_hash:
        raise ValueError('review_binding_mismatch')
    if data.get('policy') != 'approve':
        raise ValueError('policy_not_approved')
    expected = [c['id'] for c in proposal['cases']]
    cases = data.get('cases',[])
    if [c.get('id') for c in cases] != expected or len(set(expected))!=len(expected):
        raise ValueError('case_inventory_mismatch')
    for c in cases:
        if c.get('checked') is not True or c.get('decision') not in {'include','exclude'}:
            raise ValueError('unresolved_case')
        if c['decision']=='include':
            if c.get('kind') not in {'purchase','discount','tax','deposit','tip','adjustment'}:
                raise ValueError('invalid_kind')
            if not isinstance(c.get('description'),str) or not c['description'].strip():
                raise ValueError('missing_description')
            cents(c.get('amount'))
    return cases


def field(value):
    return {'state':'printed_verified','value':value,'original_regions':[]}


def split_confirmed_marker(description):
    # These audited rows have a separate one-letter price-column marker.
    pieces = description.rsplit(' ',1)
    if len(pieces)!=2 or not re.fullmatch('[A-Z]',pieces[1]):
        raise ValueError('audited_marker_changed')
    return pieces


def scorer():
    spec=importlib.util.spec_from_file_location('reference_repair_lab',ROOT/'evaluation/receipt-lab/lab.py')
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build_reference(old, proposal, checked, lab):
    revised=copy.deepcopy(old)
    ledger=[]
    for c,p in zip(checked,proposal['cases']):
        slot=p['receipt']-1
        if c['decision']=='exclude':
            if p['referenceRow'] is not None:
                raise ValueError('unexpected_existing_row_exclusion')
            ledger.append({'case':c['id'],'receipt':p['receipt'],'action':'confirmed_non_accounting_output',
                           'outputRow':p['outputRow'],'notes':c['notes']})
            continue
        description=c['description'].strip()
        marker=None
        if c['id'] in PRICE_MARKER_CASES:
            description,marker=split_confirmed_marker(description)
        prior=copy.deepcopy(old['receipts'][slot]['lines'][p['referenceRow']-1]) if p['referenceRow'] else None
        line=copy.deepcopy(prior) if prior else {
            'reference_id':'p8-'+c['id'], 'original_regions':[],
            'fields':{key:{'state':'unreviewed','original_regions':[]} for key in
                      (lab.ITEM_FIELDS if c['kind']=='purchase' else lab.ADJUSTMENT_FIELDS)}}
        if prior and prior['fields']['kind'].get('value')!=c['kind']:
            raise ValueError('unexpected_kind_change')
        for k,v in [('kind',c['kind']),('description',description),('amount',cents(c['amount']))]:
            line['fields'][k]=field(v)
        if marker is not None:
            line['fields']['taxMarker']=field(marker)
        # Prior regions may be wrong for the heading/fragment cases. Do not carry
        # them forward as verified anchors for revised names without a new drawing.
        line['original_regions']=[]
        for f in line['fields'].values():
            f['original_regions']=[]
        if prior:
            revised['receipts'][slot]['lines'][p['referenceRow']-1]=line
        else:
            revised['receipts'][slot]['lines'].append(line)
        ledger.append({'case':c['id'],'receipt':p['receipt'],'action':'replace' if prior else 'add',
                       'before':prior,'after':copy.deepcopy(line),'notes':c['notes'],
                       'verification':'human_export_core_fields_plus_approved_boundary_policy'})
    for receipt,row,output in POLICY_NAMES:
        slot=receipt-1
        line=revised['receipts'][slot]['lines'][row-1]
        before=copy.deepcopy(line)
        description=load(audit.RUN/f'responses/real-{slot}-1.json')['actual']['lines'][output-1]['description']
        if (receipt,row) in PRICE_MARKER_POLICY_ROWS:
            description,_=split_confirmed_marker(description)
        line['fields']['description']=field(description)
        ledger.append({'receipt':receipt,'referenceRow':row,'action':'name_policy',
                       'before':before,'after':copy.deepcopy(line),
                       'verification':'manual_source_audit_plus_user_approved_policy_not_new_full_row_review'})
    for receipt in revised['receipts']:
        lab.validate_reference(receipt)
    return revised,ledger


def evaluate(refs, lab):
    totals={name:{'core':Counter(),'adjustments':Counter(),'fields':{}} for name in ['gemini','local_baseline']}
    private=[]
    for slot,source in enumerate(refs['receipts']):
        ref=copy.deepcopy(source)
        for line in ref['lines']:
            line['original_regions']=[]
        gemini=load(audit.RUN/f'responses/real-{slot}-1.json')['actual']
        capture=load(audit.PRIVATE/f'p7-08-final/captures/capture-{slot}-1.json')
        baseline=lab.fields_actual(capture['reloadedFields'])
        for name,actual in [('gemini',gemini),('local_baseline',baseline)]:
            score=lab.score(actual,ref,[])
            group=assess(actual,ref,score,lab.legacy.e.norm)
            totals[name]['core'].update({k:v for k,v in group.items() if type(v) is int})
            for k,v in score['fields'].items():
                totals[name]['fields'].setdefault(k,Counter()).update(v)
            for result in score['line_results']:
                kind=ref['lines'][result['reference_line']]['fields']['kind'].get('value')
                if kind!='purchase':
                    totals[name]['adjustments']['expected']+=1
                    totals[name]['adjustments']['exact']+=all(result['outcomes'].get(k)=='correct' for k in ('kind','description','amount'))
            totals[name]['core']['unrelated_unmatched_output_rows']+=score['counts'].get('unrelated_unmatched_actual_lines',0)
            private.append({'slot':slot,'candidate':name,'score':score,'groups':group})
    return totals,private


def run():
    audit.main()
    RESULT.mkdir(mode=0o700, exist_ok=True)
    proposal=load(OUT/'proposal.json');data=load(EXPORT)
    checked=validate_export(data,proposal,digest(REFERENCE))
    inputs=[REFERENCE,EXPORT,OUT/'proposal.json',Path(__file__).resolve(),
            ROOT/'evaluation/receipt-lab/lab.py',Path(__file__).with_name('duplicate_groups.py')]
    for slot in range(5):
        inputs += [audit.RUN/f'responses/real-{slot}-1.json',audit.PRIVATE/f'p7-08-final/captures/capture-{slot}-1.json']
    hashes={str(p.relative_to(ROOT)):digest(p) for p in inputs}
    lab=scorer();old=load(REFERENCE)
    revised,ledger=build_reference(old,proposal,checked,lab)
    write_once(RESULT/'checked-export.json',data)
    write_once(RESULT/'reference-v4.json',revised)
    write_once(RESULT/'amendments.json',ledger)
    before,_=evaluate(old,lab)
    after,detail=evaluate(revised,lab)
    write_once(RESULT/'comparison-ledger.json',detail)
    if hashes!={str(p.relative_to(ROOT)):digest(p) for p in inputs}:
        raise ValueError('input_drift')
    write_once(RESULT/'repair-manifest.json',{'inputs':hashes,'reference_v4_sha256':digest(RESULT/'reference-v4.json'),
                 'human_cases':len(checked),'policy':'approved','original_reference_unchanged':True})
    result={'task':'P8 reference integrity repair','new_api_requests':0,'exposed_receipts':5,'held_out_receipts':0,
            'human_cases_confirmed':len(checked),'human_rows_corrected':4,'human_rows_added':2,'human_non_purchase_decisions':1,
            'source_audited_policy_name_amendments':len(POLICY_NAMES),
            'original_reference_unchanged':True,'historical_v3_replay':before,'revised_v4':after,
            'matching':'same unique kind/description matcher plus exact indistinguishable duplicate groups',
            'limitations':['post-hoc reference repair on exposed receipts','no new inference or app changes',
                          'unit price and tax-marker coverage is partial; do not treat unreviewed fields as wrong',
                          'names containing misplaced quantity or tax markers remain errors; outputs are unmodified']}
    write_once(RESULT/'comparison-summary.json',result)
    return result


if __name__=='__main__':
    try:
        print(json.dumps(run(),indent=2))
    except Exception:
        sys.exit('reference_repair_stopped_private_details_suppressed')
