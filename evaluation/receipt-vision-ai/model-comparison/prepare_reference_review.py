"""Build an offline, private reference-conflict review. No inference or label edits."""
import base64
import hashlib
import json
from pathlib import Path
import source_audit as audit

HERE = Path(__file__).resolve().parent
OUT = audit.PRIVATE / 'p8-02e/reference-repair-01'
# Reference and output positions are one based; output is a proposal, never truth.
CASES = [(1,1,1,'Check the spelling against the printed product name.'),
         (5,2,4,'Check the printed size digit and the name boundary.'),
         (4,3,3,'The old name may be a stray fragment. Identify the actual product name.'),
         (4,5,5,'The old name may be a department heading. Identify the actual product name.'),
         (1,None,19,'A printed purchase appears absent from the reference. Confirm whether to include it.'),
         (4,None,17,'A printed tax line appears absent from the reference. Confirm its role and printed amount.'),
         (5,None,1,'This zero-valued identifier may be a membership/non-purchase line. Choose its role; do not assume every printed row is a purchase.')]


def build():
    audit.main()
    reference_path = audit.PRIVATE / 'p7-05-final/reference-v3.json'
    refs = json.loads(reference_path.read_text())['receipts']
    data = {'schemaVersion':1, 'referenceHash':hashlib.sha256(reference_path.read_bytes()).hexdigest(),
            'cases':[], 'images':{}}
    for case, (receipt,row,output,reason) in enumerate(CASES):
        old = refs[receipt-1]['lines'][row-1] if row else None
        actual = json.loads((audit.RUN / f'responses/real-{receipt-1}-1.json').read_text())['actual']['lines'][output-1]
        prior = {k:v.get('value') for k,v in old['fields'].items()} if old else None
        data['cases'].append({'id':f'case-{case+1}', 'receipt':receipt,
            'referenceRow':row, 'outputRow':output, 'reason':reason,
            'previous':prior, 'proposal':actual,
            'regions':old['original_regions'] if old else []})
        path = audit.PRIVATE / f'p8-01-redaction-review/receipt-{receipt}-local.png'
        data['images'][str(receipt)] = 'data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode()
    data['reviewID'] = hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()
    OUT.mkdir(mode=0o700, parents=True, exist_ok=True)
    payload = json.dumps(data).replace('<','\\u003c')
    html = (HERE/'reference-review.html').read_text().replace('__PAYLOAD__',payload)
    target = OUT/'index.html'
    target.write_text(html); target.chmod(0o600)
    (OUT/'proposal.json').write_text(json.dumps(data,indent=2))
    (OUT/'proposal.json').chmod(0o600)
    print('Prepared seven private row cases and one field-boundary policy confirmation. No uploads or label changes.')


if __name__ == '__main__':
    build()
