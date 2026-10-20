#!/usr/bin/env python3
"""Dedicated Simulator staging/collection for P7-03; private inputs stay local."""
import collections,json,os,plistlib,shutil,subprocess,sys,uuid
from pathlib import Path
import importlib.util
spec=importlib.util.spec_from_file_location("p703_evaluator",Path(__file__).with_name("evaluate.py"))
ev=importlib.util.module_from_spec(spec);spec.loader.exec_module(ev)
ROOT=ev.ROOT;OUT=ev.OUT/'native';BUILD=Path('/tmp/sliplet-p703-build');BUNDLE='com.mobyyyc.Sliplet'
os.environ['DEVELOPER_DIR']='/Applications/Xcode.app/Contents/Developer'
def command(*args):
 p=subprocess.run(args,capture_output=True,text=True)
 if p.returncode:raise ValueError('tool_failed')
 return p.stdout.strip()
def device():
 identifier=Path('/tmp/sliplet-p703-device').read_text().strip()
 devices=json.loads(command('xcrun','simctl','list','devices','available','-j'))
 found=[d for ds in devices['devices'].values() for d in ds if d['udid']==identifier]
 assert len(found)==1 and found[0]['name']=='Sliplet P7-03 Item Lab' and found[0]['state']=='Booted'
 return identifier
def prepare():
 os.umask(0o077);assert not OUT.exists();identifier=device()
 app=BUILD/'Build/Products/Debug-iphonesimulator/Sliplet.app'
 # Derive the bundle identifier from the built artifact rather than guessing legacy signing identity.
 bundle=plistlib.loads((app/'Info.plist').read_bytes())['CFBundleIdentifier']
 command('xcrun','simctl','install',identifier,str(app))
 container=Path(command('xcrun','simctl','get_app_container',identifier,bundle,'data'))
 nonce=str(uuid.uuid4());inbox=container/'Documents/P401Lab'/nonce;inbox.mkdir(parents=True)
 frozen=ev.read(ev.BASE/'manifest.json');slots=[]
 for slot,g in enumerate(frozen['groups']):
  image=Path(g['images'][0]['path']);assert ev.proof.digest(image)==g['images'][0]['sha256']
  name=f'input-{slot}'+image.suffix.lower();shutil.copyfile(image,inbox/name)
  slots.append(dict(slot=slot,image=name,sha256=g['images'][0]['sha256']))
 ev.write(inbox/'request.json',dict(nonce=nonce,slots=slots))
 xct=next((BUILD/'Build/Products').glob('*.xctestrun'));data=plistlib.loads(xct.read_bytes())
 targets=[t for c in data.get('TestConfigurations',[]) for t in c['TestTargets']] if 'TestConfigurations' in data else [v for k,v in data.items() if k=='SlipletTests']
 for target in targets:target.setdefault('EnvironmentVariables',{}).update(SLIPLET_P703_PRIVATE='YES',SLIPLET_P401_NONCE=nonce)
 def resolve(v):
  if isinstance(v,dict):return {k:resolve(x) for k,x in v.items()}
  if isinstance(v,list):return [resolve(x) for x in v]
  return v.replace('__TESTROOT__',str(xct.parent)) if isinstance(v,str) else v
 OUT.mkdir();(OUT/'private.xctestrun').write_bytes(plistlib.dumps(resolve(data)))
 sources=[ROOT/'SlipletTests/ReceiptItemBoundaryCandidate.swift',ROOT/'SlipletTests/ReceiptItemBoundaryProofTests.swift',Path(__file__),ROOT/'evaluation/receipt-description-proof/evaluate.py',*list((ROOT/'Sliplet').rglob('*.swift'))]
 ev.write(OUT/'manifest.json',dict(device=identifier,bundle=bundle,nonce=nonce,inbox=str(inbox),sources={str(p.relative_to(ROOT)):ev.proof.digest(p) for p in sources},app_binary=ev.proof.digest(app/'Sliplet'),test_binary=ev.proof.digest(app/'PlugIns/SlipletTests.xctest/SlipletTests')))
 print('Private staging complete; five originals, no reference labels sent to the app.')
def collect():
 m=ev.read(OUT/'manifest.json');assert device()==m['device']
 assert all(ev.proof.digest(ROOT/p)==h for p,h in m['sources'].items())
 container=Path(command('xcrun','simctl','get_app_container',m['device'],m['bundle'],'data'))
 inbox=container/'Documents/P401Lab'/m['nonce']
 refs=ev.read(ev.OUT/'reference-clarified.json')['receipts'];historical=ev.read(ev.OUT/'reference-original.json')['receipts'];checks=collections.Counter();details=[];perpass=[]
 (OUT/'captures').mkdir(exist_ok=True)
 for pas in (1,2):
  count=collections.Counter()
  for slot,ref in enumerate(refs):
   pair=ev.read(inbox/f'p703-{slot}-{pas}.json');old,new=pair['baseline'],pair['candidate']
   assert old['observations']==new['observations'];checks['paired_inputs_equal']+=1
   comparison=ev.compare(old,new,ref);details.append(comparison)
   for k in ('lost_correct_line_fields','lost_correct_summary_fields'):checks[k]+=comparison[k]
   count['baseline']+=comparison['before']['counts']['exact_purchase_pairs'];count['candidate']+=comparison['after']['counts']['exact_purchase_pairs']
   for name,c in [('historical_baseline',old),('historical_candidate',new)]:count[name]+=ev.proof.lab.score(ev.proof.actual(c),historical[slot],c['observations'])['counts']['exact_purchase_pairs']
   replay=ev.run(old['observations']);strip=lambda ls:[{k:v for k,v in l.items() if k!='id'} for l in ls]
   assert strip(replay['parsed']['lines'])==strip(new['parsed']['lines']);checks['native_candidate_matches_host_replay']+=1
   if pas==2:
    first=ev.read(OUT/'captures'/f'pair-{slot}-1.json')
    raw=lambda c:[{k:v for k,v in o.items() if k!='id'} for o in c['observations']]
    checks['repeat_raw_text_geometry_equal']+=int(raw(first['baseline'])==raw(old))
   ev.write(OUT/'captures'/f'pair-{slot}-{pas}.json',pair)
  perpass.append(dict(count))
 ev.write(OUT/'scores.json',details)
 aggregate=dict(task='P7-03',type='fresh_actual_app_imports_with_evaluation_only_candidate',passes=perpass,checks=dict(checks),held_out=0,production_changed=False)
 ev.write(OUT/'aggregate.json',aggregate);print(json.dumps(aggregate,indent=2))
if __name__=='__main__':
 try:prepare() if sys.argv[1]=='prepare' else collect()
 except Exception:raise SystemExit('Native item proof failed; private contents suppressed')
