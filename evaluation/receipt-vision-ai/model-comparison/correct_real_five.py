"""Approved bounded correction experiment, preserving prior real outputs."""
import json,os,sys
from pathlib import Path
import real_five as r
import corrected_extract as corrected
import report_real_five as reporting
n=r.n
r.OUT=n.c.OUT/'real-five-correction-01'
original_body=r.pilot.body
original_freeze=r.freeze

def body(data,extraction=False):
    request=original_body(data,extraction)
    if extraction:
        request['contents'][0]['parts'][1]['text']+='\n'+Path(__file__).with_name('correction_prompt.txt').read_text()
    return request

def parse(envelope):
    choices=envelope.get('candidates',[])
    if len(choices)!=1 or choices[0].get('finishReason')!='STOP':raise n.c.base.lab.LabError('incomplete_or_blocked')
    text=''.join(p.get('text','') for p in choices[0]['content']['parts'] if not p.get('thought')).strip()
    wrapped=text.startswith('```json\n') and text.endswith('```')
    if wrapped:text=text[8:-3]
    value=n.c.base.lab.parse_json(text)
    actual,validation=corrected.canonical(value)
    return dict(candidate=value,actual=actual,validation=validation,outer_fence_removed=wrapped)

def decode(envelope):
    result=parse(envelope)
    return result['actual'],result['validation'],result['outer_fence_removed']

def freeze():
    original_freeze()
    config={'task':'P8-02E real correction','authorization':'User approved correction task and bounded actual-receipt test','max_real_attempts':5,'automatic_retries':0,'files':{p.name:n.c.old.digest(p.read_bytes()) for p in [Path(__file__),Path(corrected.__file__),Path(__file__).with_name('correction_prompt.txt'),Path(reporting.__file__)]}}
    path=r.OUT/'correction-configuration.json'
    if path.exists() and n.c.load(path)!=config:raise n.c.base.lab.LabError('correction_configuration_changed')
    if not path.exists():n.c.write(path,config)

r.pilot.body=body
r.parse=parse
r.freeze=freeze
reporting.decode=decode

if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['run']:r.run()
        elif sys.argv[1:]==['report']:reporting.report()
        else:raise n.c.base.lab.LabError('bounded_command_required')
    except Exception as error:
        sys.exit(str(error) if isinstance(error,n.c.base.lab.LabError) else 'correction_stopped_private_details_suppressed')
