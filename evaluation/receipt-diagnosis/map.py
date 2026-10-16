#!/usr/bin/env python3
"""Read frozen P4-06 evidence; write aggregate-only results and a private index ledger.
No OCR requests, parser changes, amount-assisted identity matching, or reference edits.
"""
import argparse, collections, hashlib, importlib.util, json, re, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'))
import lab
BASE=ROOT/'private-receipts/evaluation/p4-06-final'
def read(p): return json.loads(p.read_text())
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def norm(t): return lab.legacy.e.norm(t or '')
def text_evidence(refline,capture):
    description=norm(refline['fields']['description'].get('value'))
    # Text containment is a diagnostic clue, never a source identity or correctness label.
    def present(rows): return bool(description) and any(description in norm(r['text']) for r in rows)
    return {k:present(capture[k]) for k in ('observations','groupedRows','interpretedRows')}
def run():
    refs=read(BASE/'reference-v2.json')['receipts']; m=read(BASE/'manifest.json')
    assert digest(BASE/'reference-v2.json')==m['reference_hash']
    assert digest(Path(m['label_path']))==m['label_hash']
    for g in m['groups']:
        for im in g['images']: assert digest(Path(im['path']))==im['sha256']
    for name,h in {**m['sources'],**m['extra_sources']}.items(): assert digest(ROOT/name)==h
    inputs={str(BASE/'reference-v2.json'):digest(BASE/'reference-v2.json')}
    ledger=[]; counts=collections.Counter(); stages=collections.Counter(); outcomes=collections.Counter(); issues=collections.Counter(); coverage=collections.Counter(); summary=collections.Counter(); diagnostic=collections.Counter(); byfield={}; checked=collections.Counter()
    for slot,ref in enumerate(refs):
        p=BASE/'captures'/f'capture-{slot}-1.json'; c=read(p); inputs[str(p)]=digest(p)
        lab.layout.verify_membership(c)
        assert c['storeRoundtripEqual'] and c['reloadedFields']==c['draftFields']
        actual=lab.fields_actual(c['draftFields']); scored=lab.score(actual,ref,c['observations'])
        counts.update(scored['counts']); coverage.update(scored['reference_coverage'])
        for name,cs in scored['fields'].items(): byfield.setdefault(name,collections.Counter()).update(cs)
        parsed={l['id']:l for l in c['parsed']['lines']}; obs={o['id']:o for o in c['observations']}
        for issue in c['parsed']['issues']: issues[issue['code']]+=1
        for name,label in ref['fields'].items():
            result=lab.field_result(label,actual.get(name),name)
            if result in ('correct','correct_absence'):continue
            if result=='unscorable': stage='reference_not_checked'
            elif c['parsed'].get(name) is None: stage='parser_field_unresolved'
            else: stage='summary_value_or_conversion_requires_source_check'
            stages[stage]+=1; outcomes[result]+=1
            ledger.append(dict(slot=slot,scope='summary',field=name,outcome=result,stage=stage))
        for result in scored['line_results']:
            i=result['reference_line']; j=result['actual_line']; r=ref['lines'][i]
            evidence=text_evidence(r,c)
            if j is None:
                if result.get('ambiguous_identity'): diagnostic['ambiguous_reference_lines']+=1
                elif evidence['interpretedRows']:
                    diagnostic['unpaired_name_present_in_interpreted_row']+=1
                    name=norm(r['fields']['description'].get('value'))
                    ids={sid for row in c['interpretedRows'] if name in norm(row['text']) for sid in row['ids']}
                    linked=[line for line in c['parsed']['lines'] if ids & set(line['sourceLineIDs'])]
                    diagnostic['name_clue_has_linked_output' if linked else 'name_clue_has_no_linked_output']+=1
                    if linked:
                        diagnostic['name_clue_output_description_differs']+=int(all(norm(line['description'])!=name for line in linked))
                    for code in {issue['code'] for issue in c['parsed']['issues'] if ids & set(issue['sourceLineIDs'])}:
                        diagnostic['name_clue_issue_'+code]+=1
                elif evidence['groupedRows']: diagnostic['unpaired_name_present_only_before_interpretation']+=1
                elif evidence['observations']: diagnostic['unpaired_name_present_only_in_observations']+=1
                else: diagnostic['unpaired_name_not_exactly_present_ocr_or_reference_unresolved']+=1
            keys={k:'ambiguous_identity' for k in r['fields']} if result.get('ambiguous_identity') else result['outcomes']
            for name,outcome in keys.items():
                if outcome in ('correct','correct_absence'):continue
                if outcome=='ambiguous_identity':stage='identity_unresolved_no_verified_region'
                elif outcome=='unscorable':stage='reference_not_checked'
                elif j is None:stage='unpaired_line_requires_source_identity'
                else:
                    source=parsed.get(actual['lines'][j]['id'])
                    if source is None:stage='conversion_identity_unresolved'
                    elif name=='amount' and source.get('amount')==r['fields'][name].get('value'):stage='conversion_value_mismatch'
                    elif name=='amount':
                        desired=r['fields'][name].get('value')
                        has=any(lab.legacy.money_in(obs[s]['text'],desired) for s in source['sourceLineIDs'] if s in obs)
                        stage='source_amount_present_parser_selection' if has else 'source_amount_not_found_ocr_or_association_unresolved'
                    else:stage='paired_field_parser_or_source_unresolved'
                stages[stage]+=1;outcomes[outcome]+=1
                ledger.append(dict(slot=slot,scope='line',reference_line=i,actual_line=j,field=name,outcome=outcome,stage=stage,text_clues=evidence))
        for j in scored['unmatched_actual_indices']:
            ledger.append(dict(slot=slot,scope='unmatched_output',actual_line=j,stage='identity_or_classification_unresolved_not_proven_invention'))
        for row in c['interpretedRows']:
            t=re.sub(r'^[\s*:=]+','',row['text'].upper())
            if not re.search(r'\b(?:TOTAL|SUBTOTAL|SOUS[- ]?TOTAL)\b',t):continue
            summary['keyword_rows']+=1
            anchored=bool(re.match(r'^(?:(?:GRAND\s+)?TOTAL|SUB\s*TOTAL|SOUS[- ]?TOTAL)\b',t))
            summary['anchored' if anchored else 'not_anchored']+=1
            purchase=any(l['kind']=='purchase' and set(row['ids'])&set(l['sourceLineIDs']) for l in c['parsed']['lines'])
            summary['used_as_purchase']+=int(purchase)
            if c['parsed'].get('total') is None and re.match(r'^(?:GRAND\s+)?TOTAL\b',t) and not re.match(r'^TOTAL\s+(SAVINGS|ITEMS|DISCOUNT)',t):
                summary['missing_total_label_rows']+=1
                summary['missing_total_label_with_decimal' if re.search(r'\d+[.,]\d{2}',t) else 'missing_total_label_without_decimal']+=1
        # Conversion deliberately leaves typed money absent without OCR currency;
        # review's explicit default restores values without pretending currency was read.
        if c['parsed'].get('currency') is None:
            diagnostic['currency_default_receipts']+=1
            middle={l['id']:l for l in c['fields']['items']+c['fields']['adjustments']}
            final={l['id']:l for l in c['draftFields']['items']+c['draftFields']['adjustments']}
            for l in c['parsed']['lines']:
                if middle[l['id']].get('amount') is None:
                    diagnostic['typed_money_absent_before_default']+=1
                    diagnostic['typed_money_restored_by_default']+=int(final[l['id']].get('amount',{}).get('minorUnits')==l['amount'])
        p=BASE/'captures'/f'capture-{slot}-checked-text.json'
        if p.exists():
            cc=read(p); inputs[str(p)]=digest(p);checked['receipts']+=1
            expected=next(r['expected'] for r in read(Path(m['label_path']))['receipts'] if r['id']==m['groups'][slot]['purchase_id'])
            ss=lab.legacy.amount_score(lab.legacy.normalize(cc),expected)
            checked.update({k:ss.get(k,0) for k in ('items_expected','item_amounts_correct','lines_expected','line_amounts_correct','omitted_lines','amount_corrections')})
            checked['correct_totals']+=int(lab.field_result(ref['fields']['total'],cc['parsed'].get('total'),'total')=='correct')
    assert sum(outcomes.values())==sum(counts[k] for k in ('missing','wrong','spurious','unscorable','ambiguous_identity'))
    public=dict(task='P5-01',mode='frozen_capture_diagnostic_no_new_imports',development_receipts=5,held_out_receipts=0,structured_counts=dict(counts),reference_coverage=dict(coverage),noncorrect_field_outcomes=dict(outcomes),field_stage_inventory=dict(stages),by_field={k:dict(v) for k,v in byfield.items()},line_diagnostic_clues=dict(diagnostic),summary_keyword_audit=dict(summary),parser_issue_counts=dict(issues),checked_text=dict(checked),draft_roundtrips_preserved=5,limitations=['Text containment is not verified source identity.','Unpaired and ambiguous rows cannot establish OCR versus grouping versus classification fault without source review.','Legacy and strict pairing metrics are not interchangeable.','No new recognition, timings, phone checks or human corrections.'])
    return public,dict(inputs=inputs,records=ledger)
def main():
    p=argparse.ArgumentParser();p.add_argument('--public',type=Path,required=True);p.add_argument('--private',type=Path,required=True);p.add_argument('--verify',action='store_true');a=p.parse_args()
    if not a.private.resolve().is_relative_to(ROOT/'private-receipts'):raise ValueError('private_output_required')
    public,private=run()
    if a.verify:
        assert read(a.public)==public and read(a.private)==private
        print('P5-01 aggregate and complete field ledger verified')
    else:
        for path,value in [(a.public,public),(a.private,private)]:
            if path.exists():raise ValueError('refuse_overwrite')
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')
        a.private.chmod(0o600)
        print(json.dumps(public,indent=2))
if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('P5-01 audit failed; private contents suppressed')
