"""One explicitly approved resumption, preserving the stopped 503 attempt."""
import os
import sys
from pathlib import Path
import native36_bounded_local as adapter

n = adapter.n
n.OUT = n.c.OUT / 'native-36-resumption-01'
previous_freeze = adapter.freeze

def freeze():
    previous_freeze()
    evidence = {
        'task': 'P8-02E',
        'reason': 'User approved resuming the stopped fictional comparison',
        'max_fictional_attempts': 6,
        'real_attempts': 0,
        'automatic_retries': 0,
        'files': {p.name: n.c.old.digest(p.read_bytes()) for p in [
            Path(__file__), Path(adapter.__file__)
        ]}
    }
    path = n.OUT / 'resumption.json'
    if path.exists() and n.c.load(path) != evidence:
        raise n.c.base.lab.LabError('resumption_configuration_changed')
    if not path.exists():
        n.c.write(path, evidence)

adapter.freeze = freeze
n.freeze = freeze

def report():
    n.report()
    result = n.c.load(n.OUT / 'comparison.json')
    result['configuration_differences'].append('provider_maxItems_omitted_local_150_bound_retained')
    result['prior_attempts_retained'] = True
    n.c.write(n.OUT / 'comparison.json', result)
    verification = n.c.load(n.OUT / 'verification.json')
    verification['same_image_prompt_schema_scorer'] = False
    verification['same_image_prompt_local_schema_scorer'] = True
    verification['provider_schema_difference'] = 'rows.maxItems omitted'
    n.c.write(n.OUT / 'verification.json', verification)

if __name__ == '__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:] == ['run']:
            adapter.run()
        elif sys.argv[1:] == ['report']:
            report()
        else:
            raise n.c.base.lab.LabError('fictional_only_command_required')
    except Exception as error:
        sys.exit(str(error) if isinstance(error, n.c.base.lab.LabError)
                 else 'resumption_stopped_details_suppressed')
