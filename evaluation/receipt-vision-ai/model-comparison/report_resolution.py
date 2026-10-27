"""Offline reproduction and scoring of the bounded resolution experiment."""
import importlib.util,json
from pathlib import Path
import diagnose_resolution as d

def decode(text):
    # Only a single exact outer JSON fence is accepted; no prose or JSON repair.
    if text.startswith("```json\n") and text.endswith("\n```"):
        text = text[8:-4]
        return d.n.c.base.lab.parse_json(text), True
    return d.n.c.base.lab.parse_json(text), False

def report():
    config=d.n.c.load(d.OUT/'configuration.json')
    for name,digest in config['files'].items():
        assert d.n.c.old.digest((d.n.c.ROOT/name).read_bytes())==digest
    calls=d.n.c.load(d.OUT/'calls.json')
    assert len(calls)<=3 and len({x['name'] for x in calls})==len(calls)
    inputs=d.images();results={};summary=[]
    fixture=d.n.c.load(d.n.c.base.FIXTURES/'manifest.json')[0]
    for call in calls:
        name=call['name'];extraction=name.startswith('extraction-')
        image_name=name.removeprefix('extraction-')
        request=d.body(inputs[image_name],extraction)
        assert call['kind']=='fictional'
        assert d.n.c.load(d.OUT/'requests'/f'{name}.json')==request
        response=d.n.c.load(d.OUT/'responses'/f'{name}.json')
        assert call['payload_sha256']==response['payload_sha256']==d.n.c.old.digest(json.dumps(request,sort_keys=True).encode())
        results[name]=response
        entry={k:v for k,v in response.items() if k in ['case','status','elapsed_seconds','merchant_correct','diagnostic']}
        if response['status']=='received' or (extraction and response['status']=='invalid_json'):
            envelope=d.n.c.load(d.OUT/'raw'/f'{name}.json')
            choices=envelope['candidates'];assert len(choices)==1 and choices[0]['finishReason']=='STOP'
            text=''.join(p.get('text','') for p in choices[0]['content']['parts'] if not p.get('thought'))
            if not extraction:
                assert response['merchant_correct']==(' '.join(text.strip().split()).upper()==fixture['expected']['merchant'].upper())
            else:
                assert d.select(results)==image_name
                value,wrapper_removed=decode(text)
                actual,validation=d.n.c.base.extract.canonical(value)
                if response['status']=='received':
                    assert response['candidate']==value and response['actual']==actual and response['validation']==validation
                entry['offline_wrapper_removed']=wrapper_removed
                entry['local_validation_passed']=True
                spec=importlib.util.spec_from_file_location('frozen_score',d.n.c.base.HERE/'score.py')
                score=importlib.util.module_from_spec(spec);spec.loader.exec_module(score)
                expected=fixture['expected']
                fields={k:score.eq(actual.get(k),v,k) for k,v in expected.items() if k!='lines'}
                rows=[{k:i<len(actual['lines']) and score.eq(actual['lines'][i].get(k),v,k) for k,v in row.items()} for i,row in enumerate(expected['lines'])]
                entry['fields']=fields;entry['rows']=rows
                entry['exact']=all(fields.values()) and len(actual['lines'])==len(expected['lines']) and all(all(x.values()) for x in rows)
        summary.append(entry)
    selected=d.n.c.load(d.OUT/'selection.json')['selected'] if (d.OUT/'selection.json').exists() else None
    assert selected==d.select(results)
    result={'task':'P8-02E resolution diagnosis','verified':True,'attempts':len(calls),'real_uploads':0,'timeout_seconds':60,'selected_for_extraction':selected,'results':summary}
    d.n.c.write(d.OUT/'verification.json',result)
    print(json.dumps(result,indent=2))
    return result

if __name__=='__main__':report()
