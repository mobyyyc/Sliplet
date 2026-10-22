#!/usr/bin/env python3
"""Freeze explicitly reviewed references and evaluate unchanged parsing locally."""
import copy,collections,hashlib,json,os,subprocess,sys,uuid
from decimal import Decimal
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'));import lab
OUT=ROOT/'private-receipts/evaluation/p7-05-final'
def read(p):return json.loads(p.read_text())
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(obs):
 p=subprocess.run(['/tmp/sliplet-p705-parse'],input=json.dumps(obs),text=True,capture_output=True)
 assert p.returncode==0
 return json.loads(p.stdout)
def semantic(fields):
 f=copy.deepcopy(fields)
 for key in ('items','adjustments'):
  for item in f[key]:item.pop('id',None)
 return f
def in_box(o,b):
 a=o['boundingBox'];x=a['x']+a['width']/2;y=a['y']+a['height']/2
 return b['x']<=x<=b['x']+b['width'] and b['y']<=y<=b['y']+b['height']
def main():
 os.umask(0o077);assert not OUT.exists()
 identity=read(ROOT/'private-receipts/evaluation/p7-05-review/identity.json');human=read(ROOT/'sliplet-p705-progress.json')
 assert human['nonce']==identity['nonce'] and len(human['cases'])==len(identity['cases'])==23
 assert all(digest(ROOT/p)==h for p,h in identity['input_hashes'].items())
 original=read(ROOT/'private-receipts/evaluation/p7-03-final-v2/reference-clarified.json')
 refs=copy.deepcopy(read(ROOT/'private-receipts/evaluation/p7-05-human-audit/source-anchor-diagnostic-reference.json'))
 amendments=[]
 for n,(c,e) in enumerate(zip(human['cases'],identity['cases']),1):
  assert c['id']==e['id']
  r=refs['receipts'][e['slot']]
  if e['kind']=='total':
   assert r['fields']['total']['value']==int(Decimal(c['amount'])*100)
   r['fields']['total']['original_regions']=[c['region']];r['source_regions_verified']=True;continue
  l=next(l for l in r['lines'] if l['reference_id']==e['reference_id'])
  assert l['fields']['amount']['value']==int(Decimal(c['amount'])*100)
  if l['fields']['description']['value']!=c['description']:
   amendments.append(dict(case=n,field='description',before=l['fields']['description']['value'],after=c['description']))
   l['fields']['description']['value']=c['description']
  if n==14:
   assert 'discount' in c['notes'].lower() and l['fields']['amount']['value']<0
   l['fields']={k:l['fields'][k] for k in ('kind','description','amount')}
   l['fields']['kind']['value']='discount';l['fields']['rate']={'state':'unreviewed','original_regions':[]}
   amendments.append(dict(case=n,field='kind',before='purchase',after='discount',parent='User identifies item above; exact parent source identity not asserted here',tax='unverified'))
 for r in refs['receipts']:lab.validate_reference(r)
 OUT.mkdir();aggregate={'cases':23,'held_out':0,'fresh_OCR':False,'production_changed':False,'amendments':len(amendments),'passes':[],'scoped_text_diagnostics':[]};ledger=[]
 for pair in (1,2):
  counts=collections.Counter();fieldcounts={}
  for slot,ref in enumerate(refs['receipts']):
   retained=read(ROOT/f'private-receipts/evaluation/p7-04-final/native/captures/pair-{slot}-{pair}.json')['current']
   capture=run(retained['observations']);assert semantic(capture['draftFields'])==semantic(retained['draftFields'])
   actual=lab.fields_actual(capture['draftFields']);score=lab.score(actual,ref,capture['observations'])
   counts.update({k:score['counts'][k] for k in ('exact_purchase_pairs','expected_purchases','unrelated_unmatched_actual_lines')})
   for k in ('merchant','date','subtotal','total'):fieldcounts.setdefault(k,collections.Counter()).update(score['fields'][k])
   (OUT/f'replay-{slot}-{pair}.json').write_text(json.dumps(capture,indent=2)+'\n')
   for result in score['line_results']:
    if pair==1 and any(result['outcomes'].get(k)!='correct' for k in ('kind','description','amount')):
     ledger.append(dict(slot=slot,reference_id=ref['lines'][result['reference_line']]['reference_id'],**result))
  aggregate['passes'].append(dict(counts=counts,fields=fieldcounts))
 # Scoped literal-row substitution diagnoses interpretation; it is not automatic OCR.
 for n in (1,21,23):
  c=human['cases'][n-1];e=identity['cases'][n-1];slot=e['slot'];ref=refs['receipts'][slot]
  cap=read(OUT/f'replay-{slot}-1.json');obs=copy.deepcopy(cap['observations']);removed=0
  for row in c['rows']:
   kept=[o for o in obs if not in_box(o,row['box'])];removed+=len(obs)-len(kept);obs=kept
   obs.append(dict(id=str(uuid.uuid4()),text=row['text'],boundingBox=row['box'],engineConfidence=1))
  diag=run(obs);before=lab.score(lab.fields_actual(cap['draftFields']),ref,cap['observations']);after=lab.score(lab.fields_actual(diag['draftFields']),ref,diag['observations'])
  idx=next(j for j,l in enumerate(ref['lines']) if l['reference_id']==e['reference_id'])
  target=lambda s:next(d for d in s['line_results'] if d['reference_line']==idx)['outcomes']
  aggregate['scoped_text_diagnostics'].append(dict(case=n,verified_rows=len(c['rows']),replaced_observations=removed,before={k:target(before).get(k) for k in ('kind','description','amount')},after={k:target(after).get(k) for k in ('kind','description','amount')},complete_oracle=False))
  (OUT/f'scoped-text-{n}.json').write_text(json.dumps(diag,indent=2)+'\n')
 for name,value in [('reference-v3.json',refs),('amendments.json',amendments),('error-ledger.json',ledger),('aggregate.json',aggregate)]:
  (OUT/name).write_text(json.dumps(value,indent=2)+'\n')
 paths=[ROOT/'sliplet-p705-progress.json',ROOT/'Sliplet/Parsing/Parsing.swift',Path(__file__),OUT/'reference-v3.json']
 (OUT/'manifest.json').write_text(json.dumps({str(p.relative_to(ROOT)):digest(p) for p in paths},indent=2)+'\n')
 print(json.dumps(aggregate,indent=2))
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('Finalization failed; private contents suppressed; retained references and production unchanged.')
