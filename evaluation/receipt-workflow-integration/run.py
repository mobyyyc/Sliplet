#!/usr/bin/env python3
"""P7-08 fresh production import/review/save/reopen verification, private locally."""
import collections,json,os,plistlib,subprocess,sys,statistics,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-description-proof'));import native as prior
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'));import lab
OUT=ROOT/'private-receipts/evaluation/p7-08-final';BUILD=Path('/tmp/sliplet-p708-build')
os.environ['DEVELOPER_DIR']='/Applications/Xcode.app/Contents/Developer'
def read(p):return json.loads(p.read_text())
def write(p,d):p.write_text(json.dumps(d,indent=2)+'\n')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def device():
 identifier=Path('/tmp/sliplet-p708-device').read_text().strip();ds=json.loads(prior.command('xcrun','simctl','list','devices','available','-j'))
 assert any(d['udid']==identifier and d['name']=='Sliplet P7-08 Workflow Lab' and d['state']=='Booted' for group in ds['devices'].values() for d in group)
 return identifier
def prepare():
 prior.OUT=OUT;prior.BUILD=BUILD;prior.device=device;prior.prepare()
 p=OUT/'private.xctestrun';d=plistlib.loads(p.read_bytes())
 ts=[t for c in d['TestConfigurations'] for t in c['TestTargets']] if 'TestConfigurations' in d else [d['SlipletTests']]
 for t in ts:t.setdefault('EnvironmentVariables',{}).update(SLIPLET_P401_PRIVATE='YES',SLIPLET_P703_PRIVATE='NO',SLIPLET_P403_ADAPTIVE='NO')
 p.write_bytes(plistlib.dumps(d));m=read(OUT/'manifest.json')
 for path in [Path(__file__),ROOT/'SlipletTests/ReceiptRecognitionLabTests.swift',ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json']:
  m['sources'][str(path.relative_to(ROOT))]=digest(path)
 write(OUT/'manifest.json',m)
def worker(name,obs):
 p=subprocess.run([f'/tmp/sliplet-p708-{name}'],input=json.dumps(obs),text=True,capture_output=True);assert p.returncode==0
 return json.loads(p.stdout)
def inspect(c,ref):
 old=worker('before',c['observations']);new=worker('after',c['observations'])
 semantic=lambda p:{**p,'lines':[{k:v for k,v in x.items() if k!='id'} for x in p['lines']]}
 assert semantic(new['parsed'])==semantic(c['parsed'])
 a=lab.score(lab.fields_actual(old['draftFields']),ref,old['observations']);b=lab.score(lab.fields_actual(c['draftFields']),ref,c['observations'])
 for before,after in zip(a['line_results'],b['line_results']):
  for k,v in before['outcomes'].items():
   if v=='correct':assert after['outcomes'].get(k)=='correct'
 for k,v in a['fields'].items():assert b['fields'][k].get('correct',0)>=v.get('correct',0)
 for k in ('originalBytesEqual','replayEqual','draftCanSave','storeRoundtripEqual','reviewInputEqual'):assert c[k] is True
 assert c['draftCanFinalize'] is False and c['draftFields']==c['reloadedFields']
 assert c.get('readingEvidence') is None
 assert c['parserVersion']=='p7-06-weight-extensions-0.7.1'
 assert any(i['code']=='source_review_required' for i in c['parsed']['issues'])
 return a,b

def evaluate():
 refs=read(ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json')['receipts'];passes=[];times=[];gaps=[]
 for pair in (1,2):
  count=collections.Counter()
  for slot,ref in enumerate(refs):
   c=read(OUT/'captures'/f'capture-{slot}-{pair}.json');a,b=inspect(c,ref)
   count['before_exact']+=a['counts']['exact_purchase_pairs'];count['after_exact']+=b['counts']['exact_purchase_pairs']
   count['totals_correct']+=b['fields']['total'].get('correct',0);count['subtotals_correct']+=b['fields']['subtotal'].get('correct',0)
   count['verified_roundtrips']+=1;times.append(c['importToReviewMS']);gaps.append(c['mainActorPollMaxGapMS'])
  assert count['before_exact']==56 and count['after_exact']==57
  passes.append(dict(count))
 return dict(task='P7-08',passes=passes,held_out=0,production_changed=False,automatic_extra_reads=False,median_import_to_review_ms=statistics.median(times),max_import_to_review_ms=max(times),max_main_actor_poll_gap_ms=max(gaps),lost_correct_fields=0)
def collect():
 m=read(OUT/'manifest.json');assert device()==m['device'];assert all(digest(ROOT/p)==h for p,h in m['sources'].items())
 container=Path(prior.command('xcrun','simctl','get_app_container',m['device'],m['bundle'],'data'));inbox=container/'Documents/P401Lab'/m['nonce'];(OUT/'captures').mkdir(exist_ok=True)
 for slot in range(5):
  for pair in (1,2):write(OUT/'captures'/f'capture-{slot}-{pair}.json',read(inbox/f'capture-{slot}-{pair}.json'))
 aggregate=evaluate();write(OUT/'aggregate.json',aggregate);print(json.dumps(aggregate,indent=2))
def verify():
 m=read(OUT/'manifest.json');assert all(digest(ROOT/p)==h for p,h in m['sources'].items());assert evaluate()==read(OUT/'aggregate.json')
 print('Verified ten real imports, unchanged originals/evidence, draft save/reopen equality, review gates, no correct-field losses and repeated 56-to-57 exact pairs.')
if __name__=='__main__':
 try:
  os.umask(0o077);{'prepare':prepare,'collect':collect,'verify':verify}[sys.argv[1]]()
 except Exception:raise SystemExit('P7-08 workflow verification failed; private contents suppressed.')
