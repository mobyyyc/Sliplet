"""Offline scoring of successfully decoded slots, including partial runs."""
import copy
import json
from collections import Counter, defaultdict
from pathlib import Path

from accept_echo_receipts import OUT, SLOTS, app, trial


def report():
    refs = app.load(trial.REFERENCE)['receipts']
    repair = app.baseline.repair
    lab = repair.scorer()
    statuses, purchases, adjustments = Counter(), Counter(), Counter()
    fields = defaultdict(Counter)
    parity, timings = [], []
    tokens, issues = Counter(), Counter()
    echoes = 0
    total_expected = sum(line['fields']['kind']['value']=='purchase' for ref in refs for line in ref['lines'])
    for slot in SLOTS:
        path = OUT/'responses'/f'real-{slot}-1.json'
        if not path.exists():
            continue
        result = app.load(path)
        statuses[result['status']] += 1
        timings.append(result['elapsed_seconds'])
        if result['status'] != 'received':
            continue
        envelope = app.load(OUT/'raw'/path.name)
        parts = envelope['candidates'][0]['content']['parts']
        text = ''.join(p.get('text','') for p in parts if not p.get('thought')).strip()
        candidate = trial.extract.lab.parse_json(text[8:-3] if text.startswith('```json\n') and text.endswith('```') else text)
        echoes += candidate.get('additionalProperties') is False
        for key in ('promptTokenCount','candidatesTokenCount','totalTokenCount'):
            tokens[key] += result.get('usage',{}).get(key,0)
        issues.update(result['validation'].get('issues',[]))
        ref = copy.deepcopy(refs[slot])
        for line in ref['lines']:
            line['original_regions'] = []
        actual = result['actual']
        score = lab.score(actual,ref,[])
        group = repair.assess(actual,ref,score,lab.legacy.e.norm)
        purchases.update({k:v for k,v in group.items() if type(v) is int})
        purchases['unrelated_output_rows'] += score['counts'].get('unrelated_unmatched_actual_lines',0)
        for name,counts in score['fields'].items():
            fields[name].update(counts)
        for row in score['line_results']:
            kind = ref['lines'][row['reference_line']]['fields']['kind']['value']
            if kind != 'purchase':
                adjustments[kind+'_expected'] += 1
                adjustments[kind+'_correct'] += all(row['outcomes'].get(k)=='correct' for k in ('kind','description','amount'))
        parity.append({'envelope':app.load(OUT/'raw'/path.name),'expected':actual,'imagePath':str(app.ROOT/f'private-receipts/evaluation/p8-01-redaction-review/receipt-{slot+1}-local.png')})
    summary = {'attempted':len(list(OUT.glob('call-*.json'))),'statuses':statuses,'seconds':timings,'purchases_on_received':purchases,
               'all_five_expected_purchases':total_expected,'adjustments_on_received':adjustments,'fields_on_received':fields,
               'echoes_accepted':echoes,'reported_tokens':tokens,'review_issues':issues,'held_out_receipts':0}
    app.write(OUT/'summary.json',summary)
    if parity:
        dest=Path('/tmp/sliplet-p803-private-parity.json')
        if dest.exists():
            raise FileExistsError('private parity fixture already present')
        app.write(dest,parity)
    return summary


if __name__=='__main__':
    import os
    os.umask(0o077)
    print(json.dumps(report(),indent=2))
