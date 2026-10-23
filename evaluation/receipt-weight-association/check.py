#!/usr/bin/env python3
"""Fictional structural tests and private frozen-reference regression gate."""
import json,subprocess,uuid,sys,collections,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'));import lab
WORKER='/tmp/sliplet-p706-parse'
def run(obs):
 p=subprocess.run([WORKER],input=json.dumps(obs),capture_output=True,text=True);assert p.returncode==0
 return json.loads(p.stdout)
def row(text,x,y,width=.5,height=.02):return dict(id=str(uuid.uuid4()).upper(),text=text,engineConfidence=1,boundingBox=dict(x=x,y=y,width=width,height=height))
def fixture(head='FICTIONAL PEARS XYZ',tail='0.500 kg @ $4.00/kg 2.00',merchant='NO FRILLS'):
 return [row(merchant,.1,.95),row(head,.1,.8),row(tail,.2,.775)]
def check():
 count=0
 for merchant in ('NO FRILLS','COSTCO','T&T'):
  for head,tail,amount in [('FICTIONAL PEARS XYZ','0.500 kg @ $4.00/kg 2.00',200),('654321 FICTIONAL APPLES','1.250 LB @ $2.00/LB 2.50',250),('(SALE) FICTIONAL ROOT','0.333 Kg @ $3.00/Kg F 1.00',100)]:
   obs=fixture(head,tail,merchant);p=run(obs);lines=p['parsed']['lines'];assert len(lines)==1 and lines[0]['description']==head and lines[0]['amount']==amount
   assert set(lines[0]['sourceLineIDs'])=={o['id'] for o in obs[1:]};assert p['observations']==obs;count+=1
 for tail in ('0.500 kg @ $4.00/kg','0.500 kg @ $4.00/kg 3.00','0.500 kg @ $4.00/kg -2.00','0.500 kg @ $4.00/lb 2.00','0.500 kg @ $4.00/kg 2.00 1.00','0.500 kg @ $4.00/kg OTHER PRODUCT 2.00'):
  assert not run(fixture(tail=tail))['parsed']['lines'];count+=1
 for head in ('TOTAL','SUBTOTAL','PRODUCE','DISCOUNT','DEPOSIT','NO FRILLS'):
  assert not run(fixture(head=head))['parsed']['lines'];count+=1
 for variant in range(6):
  obs=fixture()
  if variant==0:obs[0]['text']='UNKNOWN STORE'
  if variant==1:obs[2]['boundingBox']['y']=.65
  if variant==2:obs[2]['boundingBox']['x']=.05
  if variant==3:obs.insert(1,row('TOTAL 2.00',.1,.85))
  if variant==4:obs.insert(1,row('DEBIT 2.00',.1,.85))
  if variant==5:
   for o in obs:o.pop('boundingBox')
  assert not run(obs)['parsed']['lines'];count+=1
 for scale,dx,dy in ((.8,.04,.02),(.6,.15,.1),(1,0,-.1)):
  obs=fixture()
  for o in obs:
   b=o['boundingBox'];b.update(x=b['x']*scale+dx,y=b['y']*scale+dy,width=b['width']*scale,height=b['height']*scale)
  assert len(run(obs)['parsed']['lines'])==1;count+=1
 obs=fixture();obs.extend([row('FICTIONAL PEARS XYZ',.1,.70),row('0.500 kg @ $4.00/kg 2.00',.2,.675)])
 lines=run(obs)['parsed']['lines'];assert len(lines)==2 and set(lines[0]['sourceLineIDs']).isdisjoint(lines[1]['sourceLineIDs']);count+=1
 return count

def main():
 os.umask(0o077);n=check();refs=json.loads((ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json').read_text())['receipts'];out=ROOT/'private-receipts/evaluation/p7-06-final';assert not out.exists();out.mkdir()
 report={'fictional_checks':n,'passes':[],'fresh_OCR':False,'held_out':0}
 for pair in (1,2):
  beforeExact=afterExact=added=0
  for slot,ref in enumerate(refs):
   before=json.loads((ROOT/f'private-receipts/evaluation/p7-05-final/replay-{slot}-{pair}.json').read_text());after=run(before['observations'])
   assert after['observations']==before['observations']
   normalize=lambda l:{k:v for k,v in l.items() if k!='id'}
   old=before['parsed']['lines'];new=after['parsed']['lines']
   retained=[normalize(l) for l in new if any(set(l['sourceLineIDs'])==set(o['sourceLineIDs']) for o in old)]
   assert retained==[normalize(l) for l in old]
   ids=[sid for l in new for sid in l['sourceLineIDs']];assert len(ids)==len(set(ids))
   a=lab.score(lab.fields_actual(before['draftFields']),ref,before['observations']);b=lab.score(lab.fields_actual(after['draftFields']),ref,after['observations'])
   for k in a['fields']:assert b['fields'][k].get('correct',0)>=a['fields'][k].get('correct',0)
   for oldScore,newScore in zip(a['line_results'],b['line_results']):
    for k,v in oldScore['outcomes'].items():
     if v=='correct':assert newScore['outcomes'].get(k)=='correct'
   for key in ('merchant','date','subtotal','total','currency'):assert before['draftFields'].get(key)==after['draftFields'].get(key)
   assert any(i['code']=='source_review_required' for i in after['parsed']['issues'])
   beforeExact+=a['counts']['exact_purchase_pairs'];afterExact+=b['counts']['exact_purchase_pairs'];added+=len(new)-len(old)
   (out/f'pair-{slot}-{pair}.json').write_text(json.dumps(after,indent=2)+'\n')
  assert (beforeExact,afterExact,added)==(56,57,2)
  report['passes'].append(dict(before=beforeExact,after=afterExact,denominator=65,recovered_purchases=added,lost_correct_fields=0))
 (out/'aggregate.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('Weighted association gate failed; private content suppressed.')
