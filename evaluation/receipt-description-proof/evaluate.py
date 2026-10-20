#!/usr/bin/env python3
"""Paired P7-03 scoring; version clarified labels, never overwrite the historical reference."""
import collections, copy, hashlib, json, os, re, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-item-proof'));import run as proof
BASE=proof.BASE;OUT=ROOT/'private-receipts/evaluation/p7-03-final-v2';WORKER='/tmp/sliplet-p703-proof'
def read(p):return json.loads(p.read_text())
def write(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def run(obs):
 p=subprocess.run([WORKER],input=json.dumps(obs),capture_output=True,text=True)
 if p.returncode:raise ValueError('worker_failed')
 return json.loads(p.stdout)
def clarified():
 historical=read(BASE/'reference-v2.json');updated=copy.deepcopy(historical)
 trace=read(ROOT/'private-receipts/evaluation/p7-03-boundaries/trace.json');amendments=[]
 for row in trace:
  ref=next(r for r in updated['receipts'][row['slot']]['lines'] if r['reference_id']==row['reference_id'])
  before=ref['fields']['description']['value'];suffix=row['ocr_description'].split()[-1]
  assert re.sub(r'^\(\d+\)\s*','',row['ocr_description'])==before+' '+suffix
  ref['fields']['description']['value']=before+' '+suffix
  amendments.append(dict(slot=row['slot'],reference_id=row['reference_id'],field='description',before=before,after=ref['fields']['description']['value']))
 assert len(amendments)==2
 return historical,updated,dict(user_confirmation='Printed in both; retain in the description',scope='Two trailing description codes only; quantities, prices and source regions not newly verified.',amendments=amendments)
def compare(old,new,ref):
 before=proof.lab.score(proof.actual(old),ref,old['observations']);after=proof.lab.score(proof.actual(new),ref,new['observations'])
 lost=sum(v in ('correct','correct_absence') and b['outcomes'].get(k)!=v for a,b in zip(before['line_results'],after['line_results']) for k,v in a['outcomes'].items())
 summary_lost=sum(proof.lab.field_result(l,proof.actual(old).get(k),k) in ('correct','correct_absence') and proof.lab.field_result(l,proof.actual(new).get(k),k) not in ('correct','correct_absence') for k,l in ref['fields'].items())
 return dict(before=before,after=after,lost_correct_line_fields=lost,lost_correct_summary_fields=summary_lost)
def main():
 os.umask(0o077);assert not OUT.exists();historical,updated,amendment=clarified();outputs={};checks=collections.Counter();scores=[]
 for slot,ref in enumerate(updated['receipts']):
  old=read(BASE/f'captures/capture-{slot}-1.json');new=run(old['observations']);paired=compare(old,new,ref);scores.append(paired)
  checks['clarified_reference_baseline']+=paired['before']['counts']['exact_purchase_pairs'];checks['clarified_reference_candidate']+=paired['after']['counts']['exact_purchase_pairs']
  checks['historical_reference_baseline']+=proof.lab.score(proof.actual(old),historical['receipts'][slot],old['observations'])['counts']['exact_purchase_pairs']
  checks['historical_reference_candidate']+=proof.lab.score(proof.actual(new),historical['receipts'][slot],new['observations'])['counts']['exact_purchase_pairs']
  for k in ('lost_correct_line_fields','lost_correct_summary_fields'):checks[k]+=paired[k]
  assert new['observations']==old['observations'];checks['raw_observations_preserved']+=1
  strip=lambda ls:[{k:v for k,v in l.items() if k!='id'} for l in ls]
  assert strip(new['parsed']['lines'][:len(old['parsed']['lines'])])==strip(old['parsed']['lines'])
  repeat=run(old['observations']);assert strip(repeat['parsed']['lines'])==strip(new['parsed']['lines']);checks['repeat_pairs_equal']+=1
  outputs[f'candidate-{slot}.json']=new
 for slot in (0,1):
  old=read(BASE/f'captures/capture-{slot}-checked-text.json');new=run(old['observations'])
  assert strip(old['parsed']['lines'])==strip(new['parsed']['lines']);checks['checked_transcripts_unchanged']+=1
 aggregate=dict(task='P7-03',receipts=5,held_out=0,checks=dict(checks),production_changed=False,reference_amendments=2)
 OUT.mkdir(parents=True)
 write(OUT/'reference-original.json',historical);write(OUT/'reference-clarified.json',updated);write(OUT/'amendment.json',amendment);write(OUT/'scores.json',scores)
 for name,data in outputs.items():write(OUT/name,data)
 write(OUT/'aggregate.json',aggregate)
 paths=[BASE/'reference-v2.json',*(BASE/'captures').glob('capture-*-1.json'),*(BASE/'captures').glob('capture-*-checked-text.json'),ROOT/'SlipletTests/ReceiptItemBoundaryCandidate.swift',Path(__file__)]
 write(OUT/'manifest.json',{str(p.relative_to(ROOT)):proof.digest(p) for p in paths})
 print(json.dumps(aggregate,indent=2))
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('P7-03 evaluation failed; private contents suppressed')
