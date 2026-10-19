#!/usr/bin/env python3
"""P7-01A local-only harness. Expected answers never enter the Simulator request."""
import argparse,collections,hashlib,json,plistlib,shutil,statistics,subprocess,sys,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'));import lab
BASE=ROOT/'private-receipts/evaluation/p6-02b-final'
PADDLE=Path('/tmp/sliplet-p701-paddle/deploy/ios_demo')
BUILD=Path('/tmp/sliplet-p701a-build/Build/Products')
WORKER=Path('/tmp/sliplet-p701a-parse')
def read(p):return json.loads(p.read_text())
def write(p,d):p.write_text(json.dumps(d,indent=2,sort_keys=True)+'\n')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def tool(args):return subprocess.check_output(args,env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'),text=True).strip()
def container(device):
 ds=json.loads(tool(['xcrun','simctl','list','devices','--json']))['devices']
 d=next(d for g in ds.values() for d in g if d['udid']==device);assert d['name']=='Sliplet P7-01A OCR Lab'
 return Path(tool(['xcrun','simctl','get_app_container',device,'com.paddleocr.demo','data']))/'Documents/P701'
def prepare(out,device):
 assert not out.exists();out.mkdir(parents=True,mode=0o700)
 m=read(BASE/'manifest.json');refs=BASE/'reference-v2.json';shutil.copy2(refs,out/'reference-v2.json')
 dest=container(device);dest.mkdir(parents=True,exist_ok=True)
 slots=[]
 for slot,g in enumerate(m['groups']):
  image=g['images'][0];src=Path(image['path']);assert digest(src)==image['sha256']
  region=read(BASE/'captures'/f'anchored-probe-{slot}.json')[0]['region'];assert region is not None
  name=f'original-{slot}.bin';shutil.copy2(src,dest/name)
  slots.append({'slot':slot,'image':name,'sha256':digest(src),'region':region})
 write(dest/'request.json',{'slots':slots});write(out/'request.json',{'slots':slots})
 sources=list((ROOT/'evaluation/receipt-independent-ocr').glob('*'))+list((ROOT/'Sliplet/Parsing').glob('*.swift'))+[ROOT/'Sliplet/Domain'/n for n in ['Receipt.swift','ReceiptReview.swift','ReceiptSplit.swift']]
 model_files=list((PADDLE/'PaddleOCRDemo/Models').rglob('*'))
 manifest={'sources':{str(p):digest(p) for p in sources if p.is_file()},'model_assets':{str(p):{'sha256':digest(p),'bytes':p.stat().st_size} for p in model_files if p.is_file()},'reference_hash':digest(refs),'worker_hash':digest(WORKER),'device':device,'app_bytes':sum(p.stat().st_size for p in (BUILD/'Release-iphonesimulator/PaddleOCRDemo.app').rglob('*') if p.is_file()),'private_baseline_manifest_hash':digest(BASE/'manifest.json'),'upstream_revision':'dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf','opencv_revision':'01b2c5a77ca6dbef3baef24ebc0a5984579231d9'}
 write(out/'manifest.json',manifest)
 xs=next(BUILD.glob('*.xctestrun'));data=plistlib.loads(xs.read_bytes())
 targets=[t for c in data['TestConfigurations'] for t in c['TestTargets']]
 for t in targets:
  t.setdefault('EnvironmentVariables',{})['SLIPLET_P701_PRIVATE']='YES'
 # Keep __TESTROOT__ resolving to the built products.
 target=BUILD/'SlipletP701Private.xctestrun';target.write_bytes(plistlib.dumps(data));shutil.copy2(target,out/'private.xctestrun')
 print('Private inputs staged; model, parser, reference and harness hashes frozen.')
def stable(p):
 ids={o['id']:i for i,o in enumerate(p['observations'])}
 def clean(v):
  if isinstance(v,dict):return {k:sorted(ids[x] for x in a) if k=='sourceLineIDs' else clean(a) for k,a in v.items() if k!='id'}
  if isinstance(v,list):return [clean(x) for x in v]
  return v
 return clean(p)
def collect(out):
 m=read(out/'manifest.json');dest=container(m['device']);shutil.copy2(dest/'load.json',out/'load.json')
 for slot in range(5):
  readings=read(dest/f'readings-{slot}.json');assert len(readings)==8
  for r in readings:
   # Mirror production Vision boundary normalization; retain raw observations above.
   normalized=[]
   for o in r['observations']:
    n=dict(o);b=o['boundingBox'];x=max(0,min(1,b['x']));y=max(0,min(1,b['y']))
    box=dict(x=x,y=y,width=min(b['width'],1-x),height=min(b['height'],1-y))
    n['boundingBox']=box if box['width']>0 and box['height']>0 else None
    n['engineConfidence']=o['confidence'];normalized.append(n)
   process=subprocess.run([str(WORKER)],input=json.dumps(normalized),capture_output=True,text=True,check=True)
   r['response']=json.loads(process.stdout)
  write(out/f'readings-{slot}.json',readings)
 write(out/'aggregate.json',evaluate(out));print('Private outputs collected; safe aggregate saved.')
def evaluate(out):
 m=read(out/'manifest.json');assert digest(out/'reference-v2.json')==m['reference_hash'];assert digest(WORKER)==m['worker_hash']
 for p,h in m['sources'].items():assert digest(Path(p))==h
 for p,v in m['model_assets'].items():assert digest(Path(p))==v['sha256']
 refs=read(out/'reference-v2.json')['receipts'];report={};alltimings={};rawcounts=collections.Counter();stable_count=0;loss=collections.Counter()
 for slot in range(5):
  readings=read(out/f'readings-{slot}.json');scores={};responses={}
  for engine in ['vision','paddle']:
   for condition in ['full','strip']:
    key=engine+'_'+condition;pair=[r for r in readings if r['engine']==engine and r['condition']==condition];assert len(pair)==2
    pair.sort(key=lambda r:r['pass']);stable_count+=int(stable(pair[0]['response'])==stable(pair[1]['response']))
    r=pair[0];p=r['response'];actual=lab.fields_actual(p['draftFields'])
    for line,item in zip(actual['lines'],p['draftFields']['items']):line['unit']=item.get('unit')
    score=lab.score(actual,refs[slot],r['observations']);scores[key]=score;responses[key]=actual
    c=report.setdefault(key,collections.Counter());c['receipts']+=1
    for field in ['merchant','date','subtotal','total']:
     c[field+'_correct']+=score['fields'].get(field,{}).get('correct',0)
    c['exact_purchase_pairs']+=score['counts'].get('exact_purchase_pairs',0);c['fully_correct_receipts']+=score['verdict']=='correct'
    c['wrong_field_outcomes']+=score['counts'].get('wrong',0)
    c['unrelated_unmatched_lines']+=score['counts'].get('unrelated_unmatched_actual_lines',0)
    alltimings.setdefault(key,[]).extend(v['milliseconds'] for v in pair)
    wanted=refs[slot]['fields']['total']['value'];literal=f'{abs(wanted)//100}.{abs(wanted)%100:02d}'
    # Diagnostic presence only: avoid claiming it is associated with TOTAL.
    import re
    rawcounts[key+'_exact_total_token_anywhere']+=any(re.search(r'(?<![\d.,:\-])'+re.escape(literal)+r'(?![\d.,:\-])',o['text']) for o in r['observations'])
    for o in p['observations']:
     b=o['boundingBox']
     if b is None:continue
     assert b['x']>=-0.001 and b['y']>=-0.001 and b['x']+b['width']<=1.001 and b['y']+b['height']<=1.001
  a=scores['vision_full'];b=scores['paddle_full']
  for field,label in refs[slot]['fields'].items():
   av=lab.field_result(label,responses['vision_full'].get(field),field);bv=lab.field_result(label,responses['paddle_full'].get(field),field)
   loss['lost_correct_summary_fields']+=av=='correct' and bv!='correct'
   loss['new_wrong_summary_fields']+=bv=='wrong' and av!='wrong'
  for before,after in zip(a['line_results'],b['line_results']):
   for field,status in before['outcomes'].items():loss['lost_correct_line_fields']+=status=='correct' and after['outcomes'].get(field)!='correct'
  expected=refs[slot]['fields']['total']['value'];va=responses['vision_full'].get('total');vb=responses['paddle_full'].get('total')
  loss['recovered_totals']+=va!=expected and vb==expected
  loss['new_wrong_line_fields']+=max(0,b['counts'].get('wrong',0)-a['counts'].get('wrong',0))
  loss['added_unrelated_output_proxies']+=max(0,b['counts'].get('unrelated_unmatched_actual_lines',0)-a['counts'].get('unrelated_unmatched_actual_lines',0))
 report={k:dict(v) for k,v in report.items()}
 return {'task':'P7-01A','held_out':0,'private_reads':40,'stable_read_pairs':stable_count,'counts':report,'raw_candidate_presence_only':dict(rawcounts),'regressions':dict(loss),'timing_ms':{k:{'median':statistics.median(v),'max':max(v)} for k,v in alltimings.items()},'model_load_ms':read(out/'load.json')['loadMilliseconds'],'max_sampled_resident_bytes':max(r['residentBytes'] for slot in range(5) for r in read(out/f'readings-{slot}.json')),'app_bundle_bytes':m['app_bytes'],'model_asset_bytes':sum(v['bytes'] for v in m['model_assets'].values()),'promotion_gate_passed':report['paddle_full']['total_correct']>=4 and loss['recovered_totals']>0 and not any(loss[k] for k in ['lost_correct_summary_fields','new_wrong_summary_fields','lost_correct_line_fields','new_wrong_line_fields','added_unrelated_output_proxies']),'production_changed':False,'scope':'Full-image final fields scored independently. Strip results and literal-token presence are diagnostics, not fused/app-integrated recovery. Memory is sampled whole-process RSS, not peak or engine-only usage.'}
def main():
 a=argparse.ArgumentParser();a.add_argument('command',choices=['prepare','collect','verify']);a.add_argument('--run',required=True);a.add_argument('--device');args=a.parse_args();out=(ROOT/args.run).resolve();assert out.is_relative_to(ROOT/'private-receipts/evaluation')
 if args.command=='prepare':prepare(out,args.device)
 elif args.command=='collect':collect(out)
 else:assert evaluate(out)==read(out/'aggregate.json');print('Frozen independent OCR evidence verified.')
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('Independent OCR evaluation failed; private content suppressed.')
