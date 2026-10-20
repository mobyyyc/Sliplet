#!/usr/bin/env python3
"""Offline P7-04 verification; no private content is printed."""
import collections,subprocess
import importlib.util
from pathlib import Path
spec=importlib.util.spec_from_file_location("p704_gate",Path(__file__).with_name("run.py"))
gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)

def main():
 E=gate.E;out=gate.OUT;m=E.read(out/'native/manifest.json')
 assert all(E.proof.digest(gate.ROOT/p)==h for p,h in m['sources'].items())
 expected=subprocess.check_output(['git','show','f96f36a:Sliplet/Parsing/Parsing.swift'],cwd=gate.ROOT)
 assert (out/'baseline-parser.swift').read_bytes()==expected
 def check(pair,ref):
  before,after=pair['baseline'],pair['current'];score,added=gate.inspect(before,after,ref)
  semantic=lambda parsed:{**parsed,'lines':[{k:v for k,v in l.items() if k!='id'} for l in parsed['lines']]}
  assert semantic(gate.run(gate.CURRENT,after['observations'])['parsed'])==semantic(after['parsed'])
  assert semantic(gate.run(gate.BASELINE,before['observations'])['parsed'])==semantic(before['parsed'])
  return score,added
 scores=[];counts=collections.Counter()
 for slot,ref in enumerate(gate.refs()):
  pair=E.read(out/f'frozen-{slot}.json');score,added=check(pair,ref);scores.append(score)
  for name in ('before','after'):counts[name]+=score[name]['counts']['exact_purchase_pairs']
 assert counts==dict(before=43,after=45);assert scores==E.read(out/'frozen-scores.json')
 scores=[];passes=[]
 for pas in (1,2):
  counts=collections.Counter()
  for slot,ref in enumerate(gate.refs()):
   pair=E.read(out/f'native/captures/pair-{slot}-{pas}.json');score,added=check(pair,ref);scores.append(score)
   current=pair['current']
   assert all(current[k] is True for k in ('originalBytesEqual','replayEqual','draftCanSave','storeRoundtripEqual','reviewInputEqual'))
   assert current['draftCanFinalize'] is False and current['draftFields']==current['reloadedFields']
   for name in ('before','after'):counts[name]+=score[name]['counts']['exact_purchase_pairs']
  assert counts==dict(before=43,after=45);passes.append(dict(counts))
 assert scores==E.read(out/'native/scores.json')
 assert passes==E.read(out/'native/aggregate.json')['passes']
 total=0
 for name in ('test-summary.json','parser-summary.json'):
  result=E.read(out/'native'/name);assert result['failedTests']==0 and result['passedTests']>0;total+=result['passedTests']
 print(f'P7-04 verified: frozen and two fresh passes 43 to 45; ten draft save/reopen checks; {total} tests passed.')
if __name__=='__main__':
 try:main()
 except Exception:raise SystemExit('P7-04 verification failed; private contents suppressed')
