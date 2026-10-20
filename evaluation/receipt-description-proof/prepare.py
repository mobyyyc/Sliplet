#!/usr/bin/env python3
"""Prepare a local two-row boundary review; never emit receipt contents."""
import base64, collections, hashlib, html, json, mimetypes, os, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'private-receipts/evaluation/p5-06-final'
OUT=ROOT/'private-receipts/evaluation/p7-03-boundaries'
def read(p):return json.loads(p.read_text())
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 os.umask(0o077)
 assert not OUT.exists()
 refs=read(BASE/'reference-v2.json')['receipts']; manifest=read(BASE/'manifest.json');cards=[];evidence=[];hashes={}
 for slot in range(5):
  source=BASE/f'captures/capture-{slot}-1.json';old=read(source)
  prior=ROOT/f'private-receipts/evaluation/p7-02-final/candidate-{slot}.json';new=read(prior)
  hashes[str(source.relative_to(ROOT))]=digest(source);hashes[str(prior.relative_to(ROOT))]=digest(prior)
  for line in new['parsed']['lines'][len(old['parsed']['lines']):]:
   desc=line['description'];matches=[r for r in refs[slot]['lines'] if r['fields']['description'].get('value') in desc]
   if len(matches)!=1:continue
   ref=matches[0];name=ref['fields']['description']['value'];suffix=desc.split()[-1]
   others=sum(r['fields']['description'].get('value','').split()[-1:]==[suffix] for r in refs[slot]['lines'])
   image=Path(manifest['groups'][slot]['images'][0]['path']);assert digest(image)==manifest['groups'][slot]['images'][0]['sha256']
   boxes=[o['boundingBox'] for o in old['observations'] if o['id'] in line['sourceLineIDs']]
   left=min(b['x'] for b in boxes);right=max(b['x']+b['width'] for b in boxes)
   top=1-max(b['y']+b['height'] for b in boxes);bottom=1-min(b['y'] for b in boxes)
   data=base64.b64encode(image.read_bytes()).decode();mime=mimetypes.guess_type(image.name)[0] or 'image/jpeg'
   # Browser displays the original bytes. No new OCR or relabeling is performed.
   uri=f'data:{mime};base64,{data}'
   cards.append(f'''<section><h2>Row {len(cards)+1}</h2><p>Compare the highlighted row with the two text versions below. Click the original to open it at full size.</p>
   <div class="photo"><a href="{uri}" target="_blank"><img src="{uri}"></a><div class="outline" style="left:{left*100}%;top:{top*100}%;width:{(right-left)*100}%;height:{(bottom-top)*100}%"></div></div>
   <dl><dt>Retained OCR description</dt><dd>{html.escape(desc)}</dd><dt>Previously checked description</dt><dd>{html.escape(name)}</dd></dl>
   <p>Other checked names on this receipt retaining the same trailing code: {others}.</p></section>''')
   evidence.append(dict(slot=slot,source_ids=line['sourceLineIDs'],reference_id=ref['reference_id'],ocr_description=desc,checked_description=name,other_names_retaining_suffix=others,amount_matches_reference=line['amount']==ref['fields']['amount'].get('value')))
   hashes[str(image)]=digest(image)
 assert len(cards)==2
 hashes[str((BASE/'reference-v2.json').relative_to(ROOT))]=digest(BASE/'reference-v2.json')
 OUT.mkdir(parents=True)
 (OUT/'review.html').write_text('''<!doctype html><meta charset="utf-8"><title>Sliplet · Description boundary check</title><style>body{font:17px system-ui;max-width:760px;margin:40px auto;padding:20px;background:#f4f4f7;color:#222}section{padding:24px;margin:24px 0;background:white;border-radius:20px}h1{font-size:28px}.photo{position:relative;max-width:420px;margin:auto}.photo img{width:100%;display:block}.outline{position:absolute;border:3px solid #007aff;box-sizing:border-box;pointer-events:none}dd{margin:8px 0 24px;overflow-wrap:anywhere}dt{font-weight:600}</style><h1>Description boundary check</h1><p>This page is stored locally. Nothing is uploaded. Please check whether the trailing code is printed in each highlighted row and whether you want it retained in the description or kept separately as metadata. Your original labels remain unchanged.</p>'''+''.join(cards))
 (OUT/'trace.json').write_text(json.dumps(evidence,indent=2))
 (OUT/'manifest.json').write_text(json.dumps(hashes,indent=2))
 (OUT/'status.json').write_text(json.dumps(dict(task='P7-03',status='awaiting_targeted_boundary_confirmation',rows=2,production_changed=False,labels_changed=False),indent=2))
 print('Prepared two-row local boundary review. Originals and checked labels unchanged.')
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('Boundary review preparation failed; private contents suppressed')
