#!/usr/bin/env python3
"""Validate a focused human export without applying reference changes."""
import hashlib,json,math,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PRIVATE=ROOT/'private-receipts/evaluation/p7-05-review'
def box(b):
 if not isinstance(b,dict) or set(b)!=set(('x','y','width','height')):return False
 if any(type(v) not in (int,float) or not math.isfinite(v) for v in b.values()):return False
 return b['x']>=0 and b['y']>=0 and b['width']>0 and b['height']>0 and b['x']+b['width']<=1+1e-9 and b['y']+b['height']<=1+1e-9
def overlap(a,b):
 area=max(0,min(a['x']+a['width'],b['x']+b['width'])-max(a['x'],b['x']))*max(0,min(a['y']+a['height'],b['y']+b['height'])-max(a['y'],b['y']))
 return area/min(a['width']*a['height'],b['width']*b['height'])
def validate(data,identity):
 assert data.get('schemaVersion')==1 and data.get('nonce')==identity['nonce'] and data.get('complete') is True
 cases=data['cases'];expected={c['id']:c for c in identity['cases']}
 assert len(cases)==len(expected) and {c['id'] for c in cases}==set(expected)
 for c in cases:
  assert c.get('confirmed') is True and c.get('unresolved') is False
  assert box(c.get('region')) and isinstance(c.get('amount'),str) and re.fullmatch(r'-?\d+\.\d{2}',c['amount'])
  assert abs(int(c['amount'].replace('.','')))<=100_000_000_000
  assert expected[c['id']]['kind']=='total' or isinstance(c.get('description'),str) and c['description'].strip()
  assert isinstance(c.get('rows'),list) and all(isinstance(r.get('text'),str) and r['text'].strip() and box(r.get('box')) for r in c['rows'])
 for i,a in enumerate(cases):
  ea=expected[a['id']]
  for b in cases[i+1:]:
   eb=expected[b['id']]
   if ea['slot']==eb['slot'] and ea['category']==eb['category']=='duplicate_identity_unverified' and ea['description']==eb['description']:
    assert overlap(a['region'],b['region'])<.2, 'duplicate_regions_overlap'
 return len(cases)
def main():
 identity=json.loads((PRIVATE/'identity.json').read_text())
 assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in identity['input_hashes'].items())
 data=json.loads(Path(sys.argv[1]).read_text());n=validate(data,identity)
 print(f'{n} confirmed cases passed structural validation; source and reference amendments still require review. No labels changed.')
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('Export is incomplete, mismatched, or has invalid/overlapping source regions; private contents suppressed. No labels changed.')
