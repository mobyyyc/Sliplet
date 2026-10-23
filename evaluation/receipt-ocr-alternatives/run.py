#!/usr/bin/env python3
"""Stage originals only, then retain native candidate outputs privately."""
import json,os,sys,subprocess,uuid,plistlib,hashlib,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'private-receipts/evaluation/p7-07-final';DEVICE='335C182A-7166-4449-BC60-E0A78EA0C22C';BUILD=Path('/tmp/sliplet-p707-build')
os.environ['DEVELOPER_DIR']='/Applications/Xcode.app/Contents/Developer'
def read(p):return json.loads(p.read_text())
def tool(*args):return subprocess.check_output(args,text=True,stderr=subprocess.DEVNULL).strip()
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def prepare():
 assert not OUT.exists();OUT.mkdir(parents=True)
 devices=json.loads(tool('xcrun','simctl','list','devices','available','-j'))
 assert any(d['udid']==DEVICE and d['name']=='Sliplet P7-07 OCR Lab' for ds in devices['devices'].values() for d in ds)
 container=Path(tool('xcrun','simctl','get_app_container',DEVICE,'com.mobyyyc.RcpLens','data'));nonce=str(uuid.uuid4());inbox=container/'Documents/P401Lab'/nonce;inbox.mkdir(parents=True)
 manifest=read(ROOT/'private-receipts/evaluation/p5-06-final/manifest.json');slots=[]
 for index,g in enumerate(manifest['groups']):
  source=g['images'][0];p=Path(source['path']);assert digest(p)==source['sha256'];name=f'input-{index}'+p.suffix;shutil.copyfile(p,inbox/name);slots.append(dict(slot=index,image=name,sha256=source['sha256']))
 (inbox/'request.json').write_text(json.dumps(dict(nonce=nonce,slots=slots)))
 x=next((BUILD/'Build/Products').glob('*.xctestrun'));data=plistlib.loads(x.read_bytes())
 targets=[t for c in data['TestConfigurations'] for t in c['TestTargets']] if 'TestConfigurations' in data else [data['SlipletTests']]
 for t in targets:t.setdefault('EnvironmentVariables',{}).update(SLIPLET_P707_PRIVATE='YES',SLIPLET_P401_NONCE=nonce)
 def resolve(v):
  if isinstance(v,dict):return {k:resolve(x) for k,x in v.items()}
  if isinstance(v,list):return [resolve(x) for x in v]
  return v.replace('__TESTROOT__',str(x.parent)) if isinstance(v,str) else v
 (OUT/'private.xctestrun').write_bytes(plistlib.dumps(resolve(data)))
 sources=['SlipletTests/ReceiptOCRAlternativeTests.swift','Sliplet/Parsing/Parsing.swift','evaluation/receipt-ocr-alternatives/README.md','evaluation/receipt-ocr-alternatives/run.py','private-receipts/evaluation/p7-05-final/reference-v3.json']
 (OUT/'manifest.json').write_text(json.dumps(dict(nonce=nonce,device=DEVICE,slots=slots,sources={s:digest(ROOT/s) for s in sources}),indent=2))
 print('Staged five original images; no expected values or human regions supplied to OCR.')
def collect():
 m=read(OUT/'manifest.json');container=Path(tool('xcrun','simctl','get_app_container',DEVICE,'com.mobyyyc.RcpLens','data'));inbox=container/'Documents/P401Lab'/m['nonce']
 assert all(digest(ROOT/p)==h for p,h in m['sources'].items());assert all(digest(inbox/s['image'])==s['sha256'] for s in m['slots'])
 for slot in range(5):
  for pair in (1,2):
   name=f'alternatives-{slot}-{pair}.json';d=read(inbox/name);assert len(d['regions'])<=8
   for r in [d['full']]+d['regions']:
    for o in r['observations']:
     assert 0<len(o['choices'])<=5;b=o['box'];assert 0<=b['x']<=1 and 0<=b['y']<=1 and b['width']>0 and b['height']>0
   shutil.copyfile(inbox/name,OUT/name)
 print('Collected ten native passes with bounded alternatives; input hashes verified.')
if __name__=='__main__':
 try:
  os.umask(0o077);{'prepare':prepare,'collect':collect}[sys.argv[1]]()
 except Exception:raise SystemExit('OCR experiment staging/collection failed; private data suppressed.')
