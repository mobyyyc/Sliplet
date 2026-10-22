#!/usr/bin/env python3
"""Verify frozen human amendments, input hashes and repeated baseline scores."""
import copy,hashlib,json,runpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'));import lab
P=ROOT/'private-receipts/evaluation/p7-05-final'
def read(p):return json.loads(p.read_text())
def main():
 assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in read(P/'manifest.json').items())
 refs=read(P/'reference-v3.json')['receipts'];original=read(ROOT/'private-receipts/evaluation/p7-03-final-v2/reference-clarified.json')['receipts']
 changes=[]
 for a,b in zip(original,refs):
  lab.validate_reference(b);assert len(a['lines'])==len(b['lines'])
  for old,new in zip(a['lines'],b['lines']):
   assert old['reference_id']==new['reference_id'] and old['fields']['amount']==new['fields']['amount']
   for key in ('kind','description'):
    if old['fields'][key]!=new['fields'][key]:changes.append(key)
 assert sorted(changes)==['description','kind']
 for pair in (1,2):
  exact=den=0
  for slot,ref in enumerate(refs):
   c=read(P/f'replay-{slot}-{pair}.json');s=lab.score(lab.fields_actual(c['draftFields']),ref,c['observations'])
   exact+=s['counts']['exact_purchase_pairs'];den+=s['counts']['expected_purchases']
  assert (exact,den)==(56,65)
 # Optional supplemental text is valid, incomplete supplied rows are not.
 v=runpy.run_path(str(ROOT/'evaluation/receipt-focused-audit/check-export.py'))
 b=dict(x=.1,y=.1,width=.2,height=.02)
 i={'nonce':'fiction','cases':[dict(id='one',kind='purchase',slot=0,category='test',description='FICTIONAL')]}
 d=dict(schemaVersion=1,nonce='fiction',complete=True,cases=[dict(id='one',confirmed=True,unresolved=False,region=b,amount='1.00',description='FICTIONAL',rows=[])])
 assert v['validate'](d,i)==1
 for change in ('nonce','row','confirmed'):
  x=copy.deepcopy(d)
  if change=='nonce':x['nonce']='other'
  elif change=='row':x['cases'][0]['rows']=[dict(text='',box=b)]
  else:x['cases'][0]['confirmed']=False
  try:v['validate'](x,i)
  except AssertionError:pass
  else:raise AssertionError('invalid export accepted')
 print('Final verification passed: immutable inputs, two explicit amendments, unchanged amounts, both 56/65 replays, optional-row validation and invalid-export rejection.')
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('Verification failed; private data suppressed.')
