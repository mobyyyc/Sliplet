#!/usr/bin/env python3
"""Read-only classification of retained P7-04 results; emit aggregate data only."""
import collections,hashlib,json,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'));import lab
OUT=ROOT/'private-receipts/evaluation/p7-05-planning-audit'
def read(p):return json.loads(p.read_text())
def main():
 os.umask(0o077);assert not OUT.exists()
 reference=ROOT/'private-receipts/evaluation/p7-03-final-v2/reference-clarified.json'
 refs=read(reference)['receipts'];counts=collections.Counter();coverage=collections.Counter();field_scores={};ledger=[];hashes={}
 norm=lab.legacy.e.norm
 for slot,ref in enumerate(refs):
  path=ROOT/f'private-receipts/evaluation/p7-04-final/native/captures/pair-{slot}-1.json'
  hashes[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
  c=read(path)['current'];actual=lab.fields_actual(c['draftFields']);score=lab.score(actual,ref,c['observations'])
  coverage.update(score['reference_coverage'])
  for k,v in score['fields'].items():field_scores.setdefault(k,collections.Counter()).update(v)
  counts['unmatched_output_proxies']+=score['counts']['unrelated_unmatched_actual_lines']
  groups={}
  for d in score['line_results']:
   r=ref['lines'][d['reference_line']];f=r['fields']
   if f['kind'].get('value')!='purchase':continue
   counts['purchases']+=1
   if all(d['outcomes'].get(k)=='correct' for k in ('kind','description','amount')):counts['exact']+=1;continue
   name=norm(f['description'].get('value'))
   if d.get('ambiguous_identity'):
    category='duplicate_identity_unverified';groups.setdefault((f['kind']['value'],name),[]).append(f['amount']['value'])
   elif d['actual_line'] is not None:category='paired_wrong_amount'
   else:
    rows=[r for r in c['interpretedRows'] if name and name in norm(r['text'])]
    if not rows:category='name_not_exactly_contained_cause_unresolved'
    elif any(set(r['ids'])&set(l['sourceLineIDs']) for r in rows for l in c['parsed']['lines']):category='linked_description_differs'
    else:category='contained_name_unparsed'
   counts[category]+=1
   ledger.append(dict(slot=slot,reference_id=r['reference_id'],category=category,reference_line=d['reference_line'],actual_line=d['actual_line'],outcomes=d['outcomes']))
  for (kind,name),amounts in groups.items():
   matches=[l['amount'] for l in actual['lines'] if (l['kind'],norm(l['description']))==(kind,name)]
   counts['duplicate_groups']+=1
   if sorted(amounts)==sorted(matches):counts['duplicate_groups_with_equal_amount_multiset']+=1;counts['duplicate_rows_in_equal_multiset_groups']+=len(amounts)
 assert counts['purchases']==66 and counts['exact']==45
 assert sum(counts[k] for k in ('duplicate_identity_unverified','paired_wrong_amount','name_not_exactly_contained_cause_unresolved','linked_description_differs','contained_name_unparsed'))==21
 report=dict(task='P7-05 planning audit',counts=dict(counts),field_scores=field_scores,reference_coverage=dict(coverage),held_out=0,
  target=dict(exact_purchase_pairs_required=60,total_purchase_pairs=66),notes=['Duplicate amount-set equality is diagnostic only, not verified identity or recovered accuracy.','Name containment is not proof of OCR correctness.','Unmatched output proxies are not proven fabricated purchases.','No production or reference changes.'])
 hashes[str(reference.relative_to(ROOT))]=hashlib.sha256(reference.read_bytes()).hexdigest()
 OUT.mkdir(parents=True)
 for name,value in [('aggregate.json',report),('cases.json',ledger),('manifest.json',hashes)]: (OUT/name).write_text(json.dumps(value,indent=2)+'\n')
 print(json.dumps(report,indent=2))
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('Planning audit failed; private content suppressed')
