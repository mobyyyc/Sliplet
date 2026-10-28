"""Prepare owner-only Simulator parity fixtures from saved responses; no upload.

Run ReceiptModelTests/testExplicitPrivateParity then remove the temporary file.
The XCTest imports fictional image bytes with recorded actual response bytes; it
checks the adapter and persistence, not a new inference or photo upload.
"""
import json
import os
from pathlib import Path
import structured_layout_v3 as layout
import confirm_structured as baseline


def prepare():
    records=[]
    for slot in range(5):
        result=baseline.trial.load(baseline.OUT.parent/f'structured-confirmation-finish-01/combined/responses/real-{slot}-1.json')
        expected,_=layout.canonical(result['candidate'])
        envelope={'candidates':[{'finishReason':'STOP','content':{'parts':[{'text':json.dumps(result['candidate'])}]}}]}
        records.append({'envelope':envelope,'expected':expected})
    path=Path('/tmp/sliplet-p803-private-parity.json')
    with path.open('w') as stream:json.dump(records,stream)
    path.chmod(0o600)
    return {'prepared_receipts':len(records),'new_requests':0}

if __name__=='__main__':
    os.umask(0o077)
    print(json.dumps(prepare()))
