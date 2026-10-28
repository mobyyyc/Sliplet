"""Separate post-hoc replay, never overwriting the frozen model result."""
import copy
import json
from pathlib import Path
import structured_trial as trial
import structured_layout_v2 as layout
import repair_reference as repair

OUT=trial.OUT/'layout-replay-02'


def run():
    frozen=trial.report()
    if not frozen['complete'] or frozen['statuses']!={'received':7}:raise ValueError('incomplete_trial')
    OUT.mkdir(mode=0o700,exist_ok=True);(OUT/'responses').mkdir(mode=0o700,exist_ok=True)
    inputs=[trial.OUT/'configuration.json',trial.REFERENCE,Path(__file__),Path(layout.__file__)]
    adjusted=0
    for slot in range(5):
        path=trial.OUT/'responses'/f'real-{slot}-1.json';inputs.append(path)
        original=trial.load(path);replayed=copy.deepcopy(original)
        actual,validation=layout.canonical(original['candidate'])
        adjusted+=len(validation['boundary_review'])
        replayed.update(actual=actual,validation=validation,post_hoc_layout_replay=True)
        repair.write_once(OUT/'responses'/path.name,replayed)
    previous=repair.audit.RUN
    try:
        repair.audit.RUN=OUT
        comparison,ledger=repair.evaluate(trial.load(trial.REFERENCE),repair.scorer())
    finally:repair.audit.RUN=previous
    repair.write_once(OUT/'score-ledger.json',ledger)
    result={'task':'post-hoc structured name-boundary replay','new_api_requests':0,
            'source_trial_requests':frozen['requests'],'post_hoc':True,'review_required':True,
            'rows_with_provisional_name_boundary_recovery':adjusted,'comparison':comparison,
            'held_out_receipts':0,'app_changed':False,
            'limitations':['Rule added after seeing this exposed corpus; needs frozen prospective confirmation.',
                           'Model literal transcription is not independent pixel verification.',
                           'Recovered boundaries require review; marker tax meaning remains unknown.']}
    repair.write_once(OUT/'manifest.json',{'inputs':{str(p.relative_to(trial.ROOT)):repair.digest(p) for p in inputs}})
    repair.write_once(OUT/'summary.json',result)
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    try:run()
    except Exception:raise SystemExit('layout_replay_stopped_private_details_suppressed')
