"""Explicit alternative candidate after 3.8 unavailability; not an automatic fallback.
Six fictional cases, same immutable images/prompt/schema/scorer. No real uploads.
"""
import os,sys
from pathlib import Path
import native as n
n.c.MODEL='gemini-3.6-flash'
n.ENDPOINT='https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent'
n.OUT=n.c.OUT/'native-36'
original_freeze=n.freeze

def freeze():
    availability=n.c.load(n.c.OUT/'availability-36/result.json')
    if availability.get('status')!='response_received' or availability.get('candidate_count')!=1:raise n.c.base.lab.LabError('alternative_availability_not_confirmed')
    original_freeze()
    selection={'model':'gemini-3.6-flash','reason':'3.8 native image timeout and text 503; 3.6 text response received','script_sha256':n.c.old.digest(Path(__file__).read_bytes()),'max_fictional_attempts':6,'real_attempts':0,'no_automatic_model_fallback':True}
    path=n.OUT/'selection.json'
    if path.exists() and n.c.load(path)!=selection:raise n.c.base.lab.LabError('alternative_selection_changed')
    if not path.exists():n.c.write(path,selection)
n.freeze=freeze

if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['run']:n.run()
        elif sys.argv[1:]==['report']:n.report()
        else:raise n.c.base.lab.LabError('fictional_only_command_required')
    except Exception as error:sys.exit(str(error) if isinstance(error,n.c.base.lab.LabError) else 'alternative_comparison_stopped_details_suppressed')
