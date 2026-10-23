#!/usr/bin/env python3
"""Offline labeled availability analysis; never a runtime candidate selector."""
import json,subprocess,sys,collections,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'private-receipts/evaluation/p7-07-final'
sys.path.insert(0,str(ROOT/'evaluation/receipt-lab'));import lab

def read(p):return json.loads(p.read_text())
def line(o,rank=0):return dict(id=o['id'],text=o['choices'][rank]['text'],engineConfidence=o['choices'][rank]['confidence'],boundingBox=o['box'])
def parse(obs):
 p=subprocess.run(['/tmp/sliplet-p706-parse'],input=json.dumps(obs),text=True,capture_output=True);assert p.returncode==0
 return json.loads(p.stdout)
def metrics(c,ref):
 s=lab.score(lab.fields_actual(c['draftFields']),ref,c['observations'])
 exact={d['reference_line'] for d in s['line_results'] if ref['lines'][d['reference_line']]['fields']['kind']['value']=='purchase' and all(d['outcomes'].get(k)=='correct' for k in ('kind','description','amount'))}
 return s,exact

def main():
 refs=read(ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json')['receipts'];report={'passes':[],'production_changed':False,'held_out':0,'selection_rule':'none; candidate gains are label-assisted availability diagnostics only'};ledger=[]
 for pair in (1,2):
  count=collections.Counter();times=[]
  for slot,ref in enumerate(refs):
   probe=read(OUT/f'alternatives-{slot}-{pair}.json');full=probe['full'];obs=[line(o) for o in full['observations']];baseline=parse(obs);bs,be=metrics(baseline,ref)
   count['baseline_exact_pairs']+=len(be);count['baseline_totals_correct']+=bs['fields']['total'].get('correct',0);count['full_observations']+=len(obs);count['region_reads']+=len(probe['regions']);times.extend(r['milliseconds'] for r in [full]+probe['regions']);count['invalid_geometry_observations']+=sum(len(r.get('rejected',[])) for r in [full]+probe['regions'])
   gains=set();totalAvailable=False
   for index,o in enumerate(full['observations']):
    count['full_alternative_strings']+=len(o['choices'])-1
    for rank in range(1,len(o['choices'])):
     alt=list(obs);alt[index]=line(o,rank);candidate=parse(alt);s,exact=metrics(candidate,ref);gains|=exact-be
     totalAvailable|=s['fields']['total'].get('correct',0)>bs['fields']['total'].get('correct',0)
     ledger.append(dict(slot=slot,passIndex=pair,kind='full-alternative',observation=index,rank=rank,gained=list(exact-be),lost=list(be-exact),total_correct=s['fields']['total'].get('correct',0)))
   count['full_alternative_oracle_recoverable_pairs']+=len(gains);count['full_alternative_oracle_recoverable_totals']+=totalAvailable
   regionGains=set();regionTotal=False
   for index,r in enumerate(probe['regions']):
    b=r['region'];inside=lambda o: b['x']<=o['boundingBox']['x']+o['boundingBox']['width']/2<=b['x']+b['width'] and b['y']<=o['boundingBox']['y']+o['boundingBox']['height']/2<=b['y']+b['height']
    rest=[o for o in obs if not inside(o)];local=[line(o) for o in r['observations']]
    count['region_alternative_strings']+=sum(len(o['choices'])-1 for o in r['observations'])
    variants=[('top1',local)]
    for j,o in enumerate(r['observations']):
     for rank in range(1,len(o['choices'])):
      alt=list(local);alt[j]=line(o,rank);variants.append((f'{j}:{rank}',alt))
    for mode,localCandidate in variants:
     candidate=parse(rest+localCandidate);s,exact=metrics(candidate,ref);regionGains|=exact-be;regionTotal|=s['fields']['total'].get('correct',0)>bs['fields']['total'].get('correct',0)
     ledger.append(dict(slot=slot,passIndex=pair,kind='region',region=index,mode=mode,gained=list(exact-be),lost=list(be-exact),total_correct=s['fields']['total'].get('correct',0)))
   count['region_oracle_recoverable_pairs']+=len(regionGains);count['region_oracle_recoverable_totals']+=regionTotal
   (OUT/f'baseline-{slot}-{pair}.json').write_text(json.dumps(baseline,indent=2)+'\n')
  report['passes'].append(dict(counts=count,median_read_ms=statistics.median(times),max_read_ms=max(times)))
 failed=covered=0
 for slot,ref in enumerate(refs):
  c=read(OUT/f'baseline-{slot}-1.json');score,_=metrics(c,ref);regions=read(OUT/f'alternatives-{slot}-1.json')['regions']
  for d in score['line_results']:
   item=ref['lines'][d['reference_line']]
   if item['fields']['kind']['value']=='purchase' and not all(d['outcomes'].get(k)=='correct' for k in ('kind','description','amount')):
    failed+=1
    covered+=any(r['region']['y']<=b['y']+b['height']/2<=r['region']['y']+r['region']['height'] for b in item['original_regions'] for r in regions)
 report['coverage']=dict(failed_purchase_rows=failed,failed_purchase_regions_covered=covered,region_replays_losing_correct_pairs=sum(bool(x['lost']) for x in ledger if x['kind']=='region'))
 (OUT/'availability-ledger.json').write_text(json.dumps(ledger,indent=2)+'\n');(OUT/'aggregate.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('Availability analysis failed; private contents suppressed.')
