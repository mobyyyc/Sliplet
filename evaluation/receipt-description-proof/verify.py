#!/usr/bin/env python3
"""Verify finalized private P7-03 evidence without a running Simulator."""
import collections, json
import native
E=native.ev

def main():
 for manifest in (E.OUT/'manifest.json',native.OUT/'manifest.json'):
  m=E.read(manifest);hashes=m.get('sources',m)
  assert all(E.proof.digest(E.ROOT/p)==h for p,h in hashes.items())
 old,updated,amendment=E.clarified()
 assert old==E.read(E.OUT/'reference-original.json')
 assert updated==E.read(E.OUT/'reference-clarified.json')
 assert amendment==E.read(E.OUT/'amendment.json')
 strip=lambda ls:[{k:v for k,v in line.items() if k!='id'} for line in ls]
 frozen=collections.Counter();frozen_scores=[]
 for slot,ref in enumerate(updated['receipts']):
  before=E.read(E.BASE/f'captures/capture-{slot}-1.json');after=E.read(E.OUT/f'candidate-{slot}.json')
  assert before['observations']==after['observations']
  assert strip(E.run(before['observations'])['parsed']['lines'])==strip(after['parsed']['lines'])
  comparison=E.compare(before,after,ref);frozen_scores.append(comparison)
  for name in ('before','after'):frozen[name]+=comparison[name]['counts']['exact_purchase_pairs']
  assert comparison['lost_correct_line_fields']==comparison['lost_correct_summary_fields']==0
 assert frozen==dict(before=43,after=45)
 assert frozen_scores==E.read(E.OUT/'scores.json')
 all_scores=[];passes=[]
 for pas in (1,2):
  counts=collections.Counter()
  for slot,ref in enumerate(updated['receipts']):
   pair=E.read(native.OUT/'captures'/f'pair-{slot}-{pas}.json');before,after=pair['baseline'],pair['candidate']
   assert before['observations']==after['observations']
   assert strip(E.run(before['observations'])['parsed']['lines'])==strip(after['parsed']['lines'])
   r=E.compare(before,after,ref);all_scores.append(r)
   assert r['lost_correct_line_fields']==r['lost_correct_summary_fields']==0
   for name in ('before','after'):counts[name]+=r[name]['counts']['exact_purchase_pairs']
  assert counts==dict(before=43,after=45);passes.append(dict(counts))
 assert all_scores==E.read(native.OUT/'scores.json')
 summary=E.read(native.OUT/'test-summary.json')
 assert summary['failedTests']==0 and summary['passedTests']==2
 print('Verified: two reference amendments; frozen and both fresh comparisons 43 to 45; no lost correct fields; two hosted test methods passed.')
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('P7-03 verification failed; private contents suppressed')
