"""Offline verification and safe summary of the bounded image diagnostic."""
import json
from pathlib import Path
import diagnose_images as d

def report():
    config=d.n.c.load(d.OUT/'configuration.json')
    for name,digest in config['files'].items():
        assert d.n.c.old.digest((Path(__file__).parent/name).read_bytes())==digest
    requests=dict(d.requests())
    calls=d.n.c.load(d.OUT/'calls.json')
    assert len(calls)<=3 and len({x['name'] for x in calls})==len(calls)
    summary=[]
    for call in calls:
        name=call['name'];request=requests[name]
        assert call['kind']=='fictional'
        assert d.n.c.load(d.OUT/'requests'/f'{name}.json')==request
        response=d.n.c.load(d.OUT/'responses'/f'{name}.json')
        assert call['payload_sha256']==response['payload_sha256']==d.n.c.old.digest(json.dumps(request,sort_keys=True).encode())
        result={k:response[k] for k in ['case','status','elapsed_seconds']}
        if 'diagnostic' in response:result['diagnostic']=response['diagnostic']
        if response['status']=='received':
            envelope=d.n.c.load(d.OUT/'raw'/f'{name}.json')
            candidates=envelope['candidates']
            assert len(candidates)==1 and candidates[0]['finishReason']=='STOP'
            text=''.join(p.get('text','') for p in candidates[0]['content']['parts'] if not p.get('thought'))
            result['acknowledged']=text.strip().rstrip('.!').upper()=='OK'
        summary.append(result)
    result={'task':'P8-02E image diagnosis','verified':True,'attempts':len(calls),'real_uploads':0,'schema_used':False,'receipt_extraction_tested':False,'results':summary}
    d.n.c.write(d.OUT/'verification.json',result)
    print(json.dumps(result,indent=2))
    return result

if __name__=='__main__':report()
