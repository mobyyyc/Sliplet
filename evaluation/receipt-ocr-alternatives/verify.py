#!/usr/bin/env python3
"""Verify candidate bounds, repeat stability, staging separation and audit hashes."""
import json,hashlib,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'private-receipts/evaluation/p7-07-final'
def read(p):return json.loads(p.read_text())
def main():
 m=read(OUT/'manifest.json');assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in m['sources'].items())
 aggregate=read(OUT/'aggregate.json');assert len(aggregate['passes'])==2
 assert aggregate['passes'][0]['counts']==aggregate['passes'][1]['counts']
 for slot in range(5):
  a=read(OUT/f'alternatives-{slot}-1.json');b=read(OUT/f'alternatives-{slot}-2.json')
  def stable(d):return [(r['region'],[(o['box'],o['choices']) for o in r['observations']],r.get('rejected',[])) for r in [d['full']]+d['regions']]
  assert stable(a)==stable(b)
  for d in (a,b):
   assert len(d['regions'])<=8
   for r in [d['full']]+d['regions']:
    rb=r['region']
    for o in r['observations']:
     assert 1<=len(o['choices'])<=5
     ob=o['box']
     for axis,extent in [('x','width'),('y','height')]:
      assert ob[axis]>=rb[axis]-1e-6 and ob[axis]+ob[extent]<=rb[axis]+rb[extent]+1e-6
 # No answers are included in the input slots; the checked reference hash is audit-only.
 assert all(set(s)=={'slot','image','sha256'} for s in m['slots'])
 print('Verified source hashes, ten captures, bounded regions/candidates, original-coordinate mapping and repeated candidate stability.')
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('OCR verification failed; private content suppressed.')
