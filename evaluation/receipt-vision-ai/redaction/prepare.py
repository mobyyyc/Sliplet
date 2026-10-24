"""Create offline editable redaction previews. No network or provider credentials."""
import base64,hashlib,json,os,re,subprocess,sys
from pathlib import Path
from PIL import Image,ImageOps,ImageDraw
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'private-receipts/evaluation/p8-01-redaction-review'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 os.umask(0o077)
 if OUT.exists():raise ValueError('existing_review_preserved')
 groups=json.loads((ROOT/'private-receipts/evaluation/p2-01-final/corpus.json').read_text())['groups']
 assert len(groups)==5 and all(len(g['images'])==1 for g in groups)
 sources={digest(p):p for p in (ROOT/'private-receipts').iterdir() if p.suffix.lower() in ('.heic','.png','.jpg','.jpeg')}
 captures=ROOT/'private-receipts/evaluation/p7-08-final/captures'
 OUT.mkdir(mode=0o700)
 entries=[]
 sensitive=re.compile(r'\b(member(?:ship)?|loyalty|account|acct|auth(?:orization)?|approval|terminal|cashier|operator|transaction|trans\s*#|receipt\s*#|invoice|reference|trace|ref\s*#|aid|tvr|tsi)\b|\b(?:tel|phone|fax)\b|\b\d{3}[-. ()]+\d{3}[-. ]+\d{4}\b|@|\b[A-Z]\d[A-Z][ -]?\d[A-Z]\d\b|\b\d+\s+.*\b(?:STREET|ROAD|AVENUE|DRIVE|BLVD|LANE|HWY)\b',re.I)
 card=re.compile(r'(?:\*|[xX]){3,}\s*\d{3,}|\b\d{12,19}\b')
 for slot,g in enumerate(groups):
  source=sources[g['images'][0]['sha256']]
  converted=OUT/f'converted-{slot}.png'
  subprocess.run(['/usr/bin/sips','-s','format','png',str(source),'--out',str(converted)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  with Image.open(converted) as raw:
   image=ImageOps.exif_transpose(raw).convert('RGB')
  clean=Image.new('RGB',image.size,'white');clean.paste(image)
  c=json.loads((captures/f'capture-{slot}-1.json').read_text())
  w,h=clean.size
  cw,ch=c['pixelWidth'],c['pixelHeight']
  if c['orientation'] in (5,6,7,8):cw,ch=ch,cw
  if abs(w/h-cw/ch)>.02:raise ValueError('orientation_requires_review')
  masks=[]
  for obs in c['observations']:
   text=obs['text']
   # Product codes alone are not identifiers; long-number rule is limited to card/context lines.
   flagged=sensitive.search(text) or (card.search(text) and re.search(r'card|visa|master|debit|credit|\*|[xX]{3}',text,re.I))
   if not flagged:continue
   box=obs['boundingBox'];pad=8
   x=max(0,box['x']*w-pad);y=max(0,(1-box['y']-box['height'])*h-pad)
   right=min(w,(box['x']+box['width'])*w+pad);bottom=min(h,(1-box['y'])*h+pad)
   masks.append([round(x),round(y),round(right-x),round(bottom-y)])
  original=OUT/f'receipt-{slot+1}-local.png';clean.save(original)
  preview=clean.copy();draw=ImageDraw.Draw(preview)
  for x,y,rw,rh in masks:draw.rectangle((x,y,x+rw,y+rh),fill='black')
  preview.save(OUT/f'receipt-{slot+1}-suggested.png')
  converted.unlink()
  entries.append(dict(slot=slot,original_sha256=digest(source),image='data:image/png;base64,'+base64.b64encode(original.read_bytes()).decode(),width=w,height=h,masks=masks))
 template=(Path(__file__).parent/'review.html').read_text()
 page=template.replace('/*RECEIPT_DATA*/',json.dumps(entries).replace('<','\\u003c'))
 (OUT/'index.html').write_text(page)
 (OUT/'manifest.json').write_text(json.dumps({'status':'awaiting_human_redaction_review','network_used':False,'entries':[{k:v for k,v in e.items() if k!='image'} for e in entries]},indent=2)+'\n')
 print(json.dumps({'prepared_receipts':len(entries),'suggested_masks':sum(len(e['masks']) for e in entries),'uploaded':False,'review_required':True}))
if __name__=='__main__':
 try:main()
 except Exception:sys.exit('Preview preparation stopped; private details suppressed. Existing files preserved.')
