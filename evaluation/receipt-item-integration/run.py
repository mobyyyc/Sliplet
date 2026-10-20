#!/usr/bin/env python3
"""P7-04 production import/save gate; private originals and paired outputs stay local."""
import collections,json,os,plistlib,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-description-proof'));import native as prior
E=prior.ev
OUT=ROOT/'private-receipts/evaluation/p7-04-final'
BASELINE='/tmp/sliplet-p704-baseline';CURRENT='/tmp/sliplet-p704-parse'
os.environ['DEVELOPER_DIR']='/Applications/Xcode.app/Contents/Developer'
def run(worker,obs):
 p=subprocess.run([worker],input=json.dumps(obs),capture_output=True,text=True)
 if p.returncode:raise ValueError('parser_failed')
 return json.loads(p.stdout)
def refs():return E.read(E.OUT/'reference-clarified.json')['receipts']
def inspect(before,after,ref):
 score=E.compare(before,after,ref)
 assert score['lost_correct_line_fields']==score['lost_correct_summary_fields']==0
 assert before['observations']==after['observations']
 semantic=lambda l:{k:v for k,v in l.items() if k!='id'}
 old=before['parsed']['lines'];new=after['parsed']['lines']
 retained=[semantic(l) for l in new if any(set(l['sourceLineIDs'])==set(o['sourceLineIDs']) for o in old)]
 assert retained==[semantic(l) for l in old]
 added=[l for l in new if not any(set(l['sourceLineIDs'])==set(o['sourceLineIDs']) for o in old)]
 resolved={i for l in added for i in l['sourceLineIDs']}
 for issue in before['parsed']['issues']:
  if issue not in after['parsed']['issues']:
   assert issue['code'] in ('unpriced_source_row','quantity_association_uncertain')
   assert issue['sourceLineIDs'] and set(issue['sourceLineIDs']).issubset(resolved)
 assert any(i['code']=='source_review_required' for i in after['parsed']['issues'])
 return score,len(added)
def frozen():
 os.umask(0o077);assert not OUT.exists();OUT.mkdir();counts=collections.Counter();scores=[]
 shutil.copyfile('/tmp/sliplet-p704-baseline.swift',OUT/'baseline-parser.swift')
 assert E.proof.digest(OUT/'baseline-parser.swift')==E.proof.digest(Path('/tmp/sliplet-p704-baseline.swift'))
 for slot,ref in enumerate(refs()):
  capture=E.read(E.BASE/f'captures/capture-{slot}-1.json');obs=capture['observations']
  before,after=run(BASELINE,obs),run(CURRENT,obs);s,added=inspect(before,after,ref);scores.append(s)
  for name in ('before','after'):counts[name]+=s[name]['counts']['exact_purchase_pairs']
  counts['added_purchases']+=added
  E.write(OUT/f'frozen-{slot}.json',dict(baseline=before,current=after))
 for slot in (0,1):
  old=E.read(E.BASE/f'captures/capture-{slot}-checked-text.json');before,after=run(BASELINE,old['observations']),run(CURRENT,old['observations']);_,added=inspect(before,after,refs()[slot]);assert added==0;counts['checked_transcripts_unchanged']+=1
 E.write(OUT/'frozen-scores.json',scores);E.write(OUT/'frozen-aggregate.json',dict(task='P7-04',counts=dict(counts),lost_correct_fields=0,held_out=0))
 print(json.dumps(dict(counts)))
def device():
 identifier=Path('/tmp/sliplet-p704-device').read_text().strip();devices=json.loads(prior.command('xcrun','simctl','list','devices','-j'))
 found=[d for ds in devices['devices'].values() for d in ds if d['udid']==identifier]
 assert len(found)==1 and found[0]['name']=='Sliplet P7-04 Integration Lab' and found[0]['state']=='Booted'
 return identifier
def prepare():
 prior.OUT=OUT/'native';prior.BUILD=Path('/tmp/sliplet-p704-build');prior.device=device;prior.prepare()
 p=prior.OUT/'private.xctestrun';d=plistlib.loads(p.read_bytes())
 ts=[t for c in d.get('TestConfigurations',[]) for t in c['TestTargets']] if 'TestConfigurations' in d else [d['SlipletTests']]
 for t in ts:t['EnvironmentVariables'].update(SLIPLET_P401_PRIVATE='YES',SLIPLET_P703_PRIVATE='NO')
 p.write_bytes(plistlib.dumps(d))
 m=E.read(prior.OUT/'manifest.json')
 sources=[Path(__file__),ROOT/'SlipletTests/ReceiptCountExtensionTests.swift',ROOT/'SlipletTests/ReceiptRecognitionLabTests.swift',E.OUT/'reference-clarified.json',OUT/'baseline-parser.swift']
 m['sources'].update({str(p.relative_to(ROOT)):E.proof.digest(p) for p in sources});E.write(prior.OUT/'manifest.json',m)
def collect():
 n=OUT/'native';m=E.read(n/'manifest.json');assert device()==m['device']
 assert all(E.proof.digest(ROOT/p)==h for p,h in m['sources'].items())
 container=Path(prior.command('xcrun','simctl','get_app_container',m['device'],m['bundle'],'data'));inbox=container/'Documents/P401Lab'/m['nonce']
 (n/'captures').mkdir(exist_ok=True);counts=collections.Counter();passes=[];scores=[]
 for pas in (1,2):
  pc=collections.Counter()
  for slot,ref in enumerate(refs()):
   current=E.read(inbox/f'capture-{slot}-{pas}.json');before=run(BASELINE,current['observations']);s,added=inspect(before,current,ref);scores.append(s)
   for name in ('before','after'):pc[name]+=s[name]['counts']['exact_purchase_pairs']
   for key in ('originalBytesEqual','replayEqual','draftCanSave','storeRoundtripEqual','reviewInputEqual'):
    assert current[key] is True;counts[key]+=1
   assert current['draftCanFinalize'] is False;counts['draft_finish_blocked']+=1
   assert current['draftFields']==current['reloadedFields'];counts['fields_saved_and_reloaded_equal']+=1
   counts['added_purchases_across_imports']+=added
   E.write(n/'captures'/f'pair-{slot}-{pas}.json',dict(baseline=before,current=current))
  passes.append(dict(pc))
 E.write(n/'scores.json',scores)
 aggregate=dict(task='P7-04',passes=passes,checks=dict(counts),lost_correct_fields=0,held_out=0)
 E.write(n/'aggregate.json',aggregate);print(json.dumps(aggregate,indent=2))
if __name__=='__main__':
 try:{'frozen':frozen,'prepare':prepare,'collect':collect}[sys.argv[1]]()
 except Exception:raise SystemExit('P7-04 evaluation failed; private contents suppressed')
