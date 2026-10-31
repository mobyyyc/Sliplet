"""Offline audit of the first rejected native-payload response. Prints aggregate counts."""
import copy
import json
from collections import Counter
from pathlib import Path

import accept_current_app as acceptance

def audit():
    run = acceptance.OUT.with_name('p8-07-current-app-02')
    reference = acceptance.baseline.trial.REFERENCE
    frozen = acceptance.load(run / 'configuration.json')['files']
    for path in (reference, run / 'request-0.json'):
        assert acceptance.digest(path) == frozen[str(path.relative_to(acceptance.ROOT))]
    assert acceptance.load(run / 'calls.json')[0]['payload_sha256'] == acceptance.digest(run / 'request-0.json')
    envelope = acceptance.load(run / 'raw/real-0-1.json')
    trial = acceptance.baseline.trial
    try:
        trial.parse(envelope)
    except trial.extract.lab.LabError as error:
        assert str(error) == 'schema_keys'
    else:
        raise AssertionError('Original rejection did not reproduce')

    text = envelope['candidates'][0]['content']['parts'][0]['text'].strip()
    assert text.startswith('```json\n') and text.endswith('```')
    candidate = trial.extract.lab.parse_json(text[8:-3])
    required = set(trial.extract.VALIDATION_SCHEMA['required'])
    assert set(candidate) == required | {'additionalProperties'}
    assert candidate.pop('additionalProperties') is False
    actual, validation = acceptance.layout.canonical(candidate)
    repair = acceptance.baseline.repair
    lab = repair.scorer()
    expected = copy.deepcopy(acceptance.load(reference)['receipts'][0])
    for line in expected['lines']:
        line['original_regions'] = []  # Same field-based comparison as the existing scorer.
    score = lab.score(actual, expected, [])
    groups = repair.assess(actual, expected, score, lab.legacy.e.norm)
    adjustments = Counter()
    for row in score['line_results']:
        kind = expected['lines'][row['reference_line']]['fields']['kind']['value']
        if kind != 'purchase':
            adjustments[kind + '_expected'] += 1
            adjustments[kind + '_correct'] += all(
                row['outcomes'].get(k) == 'correct' for k in ('kind', 'description', 'amount')
            )
    return {'original_accepted': False, 'projected_shape_valid': True,
            'issues': validation['issues'], 'purchases': groups, 'adjustments': adjustments,
            'fields': score['fields'], 'unrelated_output_rows': score['counts']['unrelated_unmatched_actual_lines']}

if __name__ == '__main__':
    print(json.dumps(audit(), indent=2, sort_keys=True))
