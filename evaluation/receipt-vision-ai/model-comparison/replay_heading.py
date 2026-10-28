"""Reproducible local-only heading recovery evaluation; no credentials or network."""
import json
from pathlib import Path
import structured_layout_v3 as layout
import confirm_structured as baseline


def run():
    out=baseline.OUT.parent/'p803-heading-replay-01'
    sources={'confirmation':baseline.OUT.parent/'structured-confirmation-finish-01/combined',
             'earlier_trial':baseline.trial.OUT}
    results={}
    for label,source in sources.items():
        target=out/label;(target/'responses').mkdir(parents=True,exist_ok=True,mode=0o700)
        changes=0
        for slot in range(5):
            name=f'real-{slot}-1.json'
            result=baseline.trial.load(source/'responses'/name)
            result['actual'],result['validation']=layout.canonical(result['candidate'])
            changes+=len(result['validation']['heading_review'])
            baseline.repair.write_once(target/'responses'/name,result)
        score,ledger=baseline.score_folder(target)
        baseline.repair.write_once(target/'ledger.json',ledger)
        results[label]={'changed_heading_rows':changes,'comparison':score}
    public={'status':'posthoc_local_replay','new_model_requests':0,'runs':results,
            'held_out_receipts':0,'requires_review':True,
            'limitation':'Same exposed corpus; saved responses only, not fresh model repeatability or unseen accuracy.'}
    baseline.repair.write_once(out/'replay-summary.json',public)
    (Path(__file__).parent/'heading-replay-result.json').write_text(json.dumps(public,indent=2)+'\n')
    return {label:{'core':r['comparison']['gemini']['core'],'adjustments':r['comparison']['gemini']['adjustments']} for label,r in results.items()}

if __name__=='__main__':print(json.dumps(run(),indent=2))
