#!/usr/bin/env python3
"""Audit human progress without changing production or canonical references."""
import json,hashlib,copy,sys,runpy,collections,os
from pathlib import Path
from decimal import Decimal
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'));import lab
v=runpy.run_path(str(Path(__file__).with_name('check-export.py')))
def read(p):return json.loads(p.read_text())
def main():
 os.umask(0o077)
 identity=read(ROOT/'private-receipts/evaluation/p7-05-review/identity.json');export=ROOT/'sliplet-p705-progress.json';data=read(export)
 assert data['nonce']==identity['nonce'] and len(data['cases'])==len(identity['cases'])
 assert {c['id'] for c in data['cases']}=={c['id'] for c in identity['cases']}
 assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in identity['input_hashes'].items())
 refs=read(ROOT/'private-receipts/evaluation/p7-03-final-v2/reference-clarified.json');candidate=copy.deepcopy(refs)
 totals=collections.Counter();details=[];groups=[]
 for n,(c,e) in enumerate(zip(data['cases'],identity['cases']),1):
  assert c['id']==e['id'] and v['box'](c['region']) and c['notes'].strip() and not c['unresolved']
  amount=int(Decimal(c['amount'])*100);assert Decimal(c['amount'])*100==amount
  totals['cases']+=1;totals['confirmed_checkbox']+=bool(c['confirmed']);totals['empty_optional_rows']+=not bool(c['rows'])
  assert all(v['box'](r['box']) and r['text'].strip() for r in c['rows'])
  r=candidate['receipts'][e['slot']]
  if e['kind']=='total':
   totals['total_amount_changes']+=r['fields']['total']['value']!=amount
   continue
  assert c['description'].strip()
  line=next(l for l in r['lines'] if l['reference_id']==e['reference_id'])
  totals['description_amendments']+=line['fields']['description']['value']!=c['description']
  totals['amount_amendments']+=line['fields']['amount']['value']!=amount
  # Diagnostic source anchors only; do not silently apply semantic changes.
  line['original_regions']=[c['region']];r['source_regions_verified']=True
  if e['category']=='duplicate_identity_unverified':groups.append((n,e,c))
  details.append({'case':n,'slot':e['slot'],'reference_id':e['reference_id'],'description_changed':line['fields']['description']['value']!=c['description'],'amount_changed':line['fields']['amount']['value']!=amount,'rows':len(c['rows'])})
 for j,(n,e,c) in enumerate(groups):
  for nn,ee,cc in groups[j+1:]:
   if e['slot']==ee['slot'] and e['description']==ee['description']:
    assert v['overlap'](c['region'],cc['region'])<.2
 for pair in (1,2):
  counts=collections.Counter();failures=[]
  for slot,r in enumerate(candidate['receipts']):
   cap=read(ROOT/f'private-receipts/evaluation/p7-04-final/native/captures/pair-{slot}-{pair}.json')['current']
   score=lab.score(lab.fields_actual(cap['draftFields']),r,cap['observations'])
   counts.update({k:score['counts'][k] for k in ('exact_purchase_pairs','expected_purchases','unrelated_unmatched_actual_lines')})
   for d in score['line_results']:
    if r['lines'][d['reference_line']]['fields']['kind']['value']=='purchase' and not all(d['outcomes'].get(k)=='correct' for k in ('kind','description','amount')):failures.append(dict(slot=slot,**d))
  totals[f'anchor_diagnostic_pair_{pair}_exact']=counts['exact_purchase_pairs'];totals[f'anchor_diagnostic_pair_{pair}_denominator']=counts['expected_purchases']
  if pair==1:remaining=failures
 out=ROOT/'private-receipts/evaluation/p7-05-human-audit';out.mkdir(exist_ok=False)
 for name,value in [('export-preserved.json',data),('aggregate.json',dict(totals)),('case-audit.json',details),('source-anchor-diagnostic-reference.json',candidate),('remaining-diagnostic-errors.json',remaining),('manifest.json',{'export_sha256':hashlib.sha256(export.read_bytes()).hexdigest(),'input_hashes':identity['input_hashes'],'status':'diagnostic only; explicit human completion statement retained in conversation; original checkbox states preserved'})]:
  (out/name).write_text(json.dumps(value,indent=2)+'\n')
 print(json.dumps(dict(totals),indent=2))
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('Audit failed; private data suppressed; canonical references unchanged.')
