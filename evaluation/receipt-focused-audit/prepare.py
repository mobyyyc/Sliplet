#!/usr/bin/env python3
"""Build focused local review from immutable P7-04 evidence, never print receipt data."""
import base64,hashlib,json,os,subprocess,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'private-receipts/evaluation/p7-05-review'
def read(p):return json.loads(p.read_text())
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 os.umask(0o077);assert not OUT.exists();OUT.mkdir()
 audit=ROOT/'private-receipts/evaluation/p7-05-planning-audit';ledger=read(audit/'cases.json')
 refpath=ROOT/'private-receipts/evaluation/p7-03-final-v2/reference-clarified.json';refs=read(refpath)['receipts'];manifest=read(ROOT/'private-receipts/evaluation/p5-06-final/manifest.json');cases=[];images={};hashes={str(refpath.relative_to(ROOT)):digest(refpath),str((audit/'cases.json').relative_to(ROOT)):digest(audit/'cases.json')}
 reasons={'duplicate_identity_unverified':'Repeated name: identify this occurrence in top-to-bottom order, then read its price from the original. The expected price is deliberately hidden.', 'paired_wrong_amount':'The name matched but its amount did not. Check both the description and the literal price; preserve any sign.', 'name_not_exactly_contained_cause_unresolved':'The checked name is not exactly present in the interpreted rows. Check the original wording, including product code and trailing letters.', 'linked_description_differs':'The parser assembled different description text. Confirm the complete printed product description and its boundaries.', 'contained_name_unparsed':'The name was read but not assembled into a purchase. Include its separate quantity/rate and printed extension rows.'}
 for slot in range(5):
  path=ROOT/f'private-receipts/evaluation/p7-04-final/native/captures/pair-{slot}-1.json';capture=read(path)['current'];hashes[str(path.relative_to(ROOT))]=digest(path)
  image=Path(manifest['groups'][slot]['images'][0]['path']);assert digest(image)==manifest['groups'][slot]['images'][0]['sha256'];hashes[str(image)]=digest(image)
  preview=OUT/f'preview-{slot}.png';subprocess.run(['sips','-s','format','png',str(image),'--out',str(preview)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  images[str(slot)]='data:image/png;base64,'+base64.b64encode(preview.read_bytes()).decode()
  for entry in [l for l in ledger if l['slot']==slot]:
   ref=refs[slot]['lines'][entry['reference_line']];f=ref['fields'];duplicate=entry['category']=='duplicate_identity_unverified'
   description=f['description']['value'];rows=[]
   if not duplicate:
    for o in capture['observations']:
     if description.casefold() in o['text'].casefold(): rows.append(dict(text=o['text'],box=o.get('boundingBox')))
   cases.append(dict(id=str(uuid.uuid4()),slot=slot,kind='purchase',reference_id=ref['reference_id'],category=entry['category'],description=description,amount='' if duplicate else f"{f['amount']['value']/100:.2f}",rows=rows,reason=reasons[entry['category']]))
  if capture['draftFields'].get('total') is None:
   f=refs[slot]['fields']['total'];assert f['state']=='printed_verified'
   cases.append(dict(id=str(uuid.uuid4()),slot=slot,kind='total',reference_id=None,category='missing_total',description='',amount=f"{f['value']/100:.2f}",rows=[],reason='Check the total label and printed amount. Add a literal text row even when OCR missed the amount entirely. Do not copy a payment amount or calculate a total.'))
 assert len(cases)==23
 payload=dict(nonce=str(uuid.uuid4()),cases=cases,images=images)
 (OUT/'identity.json').write_text(json.dumps(dict(nonce=payload['nonce'],cases=cases,input_hashes=hashes),indent=2))
 template=Path(__file__).with_name('review.html').read_text();(OUT/'review.html').write_text(template.replace('__PAYLOAD__',json.dumps(payload).replace('<','\\u003c')))
 print('Prepared 23 focused cases across five original receipts; all confirmations start unchecked.')
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('Focused review preparation failed; private contents suppressed')
