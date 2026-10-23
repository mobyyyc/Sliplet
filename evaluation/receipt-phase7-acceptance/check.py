#!/usr/bin/env python3
"""Reproduce Phase 7 acceptance; private inputs never appear in output."""
import collections
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PRIVATE = ROOT / 'private-receipts/evaluation'
OUT = PRIVATE / 'p7-09-final'
PUBLIC = ROOT / 'docs/evidence/p7-09/aggregate.json'
sys.path.insert(0, str(ROOT / 'evaluation/receipt-lab'))
import lab

def read(path):
    return json.loads(path.read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def evaluate():
    spec = importlib.util.spec_from_file_location('workflow', ROOT / 'evaluation/receipt-workflow-integration/run.py')
    workflow = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(workflow)
    workflow.verify()
    source = PRIVATE / 'p7-08-final'
    comparator = read(source / 'comparator-manifest.json')
    old_source = subprocess.check_output(['git', 'show', comparator['baseline_revision'] + ':Sliplet/Parsing/Parsing.swift'], cwd=ROOT)
    assert old_source == (source / 'baseline-parser.swift').read_bytes()
    assert hashlib.sha256(old_source).hexdigest() == comparator['baseline_source_sha256']
    assert digest(ROOT / 'Sliplet/Parsing/Parsing.swift') == comparator['current_source_sha256']
    for name, key in [('before', 'baseline_worker_sha256'), ('after', 'current_worker_sha256')]:
        assert digest(Path('/tmp/sliplet-p708-' + name)) == comparator[key]
    ref_path = PRIVATE / 'p7-05-final/reference-v3.json'
    refs = read(ref_path)['receipts']
    inputs = [ref_path, source / 'manifest.json', source / 'comparator-manifest.json', Path(__file__), ROOT / 'evaluation/receipt-lab/lab.py']
    passes, ledger = [], []
    for pair in (1, 2):
        counts = collections.Counter()
        fields = {}
        failures = collections.Counter()
        adjustments = collections.Counter()
        for slot, ref in enumerate(refs):
            path = source / 'captures' / f'capture-{slot}-{pair}.json'
            inputs.append(path)
            c = read(path)
            assert c['draftFields'] == c['reloadedFields']
            score = lab.score(lab.fields_actual(c['reloadedFields']), ref, c['observations'])
            for key in ('exact_purchase_pairs', 'expected_purchases', 'unrelated_unmatched_actual_lines', 'missing_line_proxies', 'ambiguous_group_count_mismatch'):
                counts[key] += score['counts'].get(key, 0)
            for key in ref['fields']:
                fields.setdefault(key, collections.Counter()).update(score['fields'][key])
            for row in score['line_results']:
                kind = ref['lines'][row['reference_line']]['fields']['kind'].get('value')
                exact = all(row['outcomes'].get(k) == 'correct' for k in ('kind', 'description', 'amount'))
                if kind == 'purchase' and not exact:
                    reason = '+'.join(k for k in ('kind', 'description', 'amount') if row['outcomes'].get(k) != 'correct')
                    failures[reason] += 1
                    ledger.append(dict(pass_number=pair, receipt_slot=slot, **row))
                elif kind != 'purchase':
                    adjustments['expected'] += 1
                    adjustments['exact_kind_description_amount'] += int(exact)
                    for key in ('kind', 'description', 'amount'):
                        adjustments[key + '_' + row['outcomes'].get(key, 'ambiguous')] += 1
            ledger.append(dict(pass_number=pair, receipt_slot=slot, score=score))
        threshold = math.ceil(.9 * counts['expected_purchases'])
        passes.append(dict(counts=dict(counts), summary_fields={k: dict(v) for k,v in fields.items()}, purchase_failures=dict(failures), adjustments=dict(adjustments), required_exact_pairs=threshold, purchase_gate=counts['exact_purchase_pairs'] >= threshold, summary_gate=fields['total'].get('correct', 0) == 5 and fields['subtotal'].get('correct', 0) == 4))
    assert passes[0] == passes[1]
    aggregate = dict(task='P7-09', status='complete_partial_accuracy_not_accepted', exposed_receipts=5, held_out_receipts=0, fresh_imports_reused=10, passes=passes, production_changed=False, workflow_verification_passed=True, previously_correct_fields_lost=0, human_correction_time_measured=False, all_fields_accuracy_claim=False, reference_frozen_algorithm_gain=dict(before=56, after=57, denominator=65), historical_reference_only_scores=[dict(exact=45, denominator=66),dict(exact=55, denominator=66),dict(exact=56, denominator=65)])
    hashes = {str(p.relative_to(ROOT)):digest(p) for p in inputs}
    return aggregate, dict(inputs=hashes), ledger

def main():
    os.umask(0o077)
    aggregate, manifest, ledger = evaluate()
    if len(sys.argv) == 2 and sys.argv[1] == 'write':
        OUT.mkdir(exist_ok=False)
        PUBLIC.parent.mkdir(parents=True, exist_ok=True)
        for path, data in [(OUT/'aggregate.json',aggregate),(OUT/'manifest.json',manifest),(OUT/'error-ledger.json',ledger),(PUBLIC,aggregate)]:
            path.write_text(json.dumps(data,indent=2)+'\n')
    else:
        assert aggregate == read(OUT/'aggregate.json') == read(PUBLIC)
        assert manifest == read(OUT/'manifest.json')
        assert ledger == read(OUT/'error-ledger.json')
    print(json.dumps(aggregate, indent=2))

if __name__ == '__main__':
    try:
        main()
    except Exception:
        raise SystemExit('Phase 7 acceptance check failed; private contents suppressed.')
