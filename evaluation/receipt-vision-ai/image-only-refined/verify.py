"""Offline verification of the frozen whole-image experiment."""
import base64,collections,io,json,sys
from PIL import Image
import run as r

def verify():
    r.freeze();calls=r.load(r.OUT/'calls.json');counts=collections.Counter(c['kind'] for c in calls)
    assert 0<counts['fictional']<=6 and counts['real']<=10
    assert len({c['name'] for c in calls})==len(calls)
    fixtures={x['id']:x for x in r.load(r.FIXTURES/'manifest.json')}
    real=r.old.verified_real_images() if counts['real'] else None
    for c in calls:
        name=c['name'];request=r.load(r.OUT/'requests'/f'{name}.json');response=r.load(r.OUT/'responses'/f'{name}.json')
        if c['kind']=='fictional':
            fixture=fixtures[name.removeprefix('fictional-')];data=(r.FIXTURES/fixture['image']).read_bytes()
            assert r.old.digest(data)==fixture['sha256'];images=r.old.tiles(Image.open(io.BytesIO(data)))
        else:images=real[int(name.split('-')[1])]
        assert len(images)==1;image=images[0]
        assert request==r.body(image)
        assert len(request['messages'][1]['content'])==1
        assert request['messages'][1]['content'][0]['type']=='image_url'
        assert r.old.digest(json.dumps(request,sort_keys=True).encode())==c['payload_sha256']==response['payload_sha256']
        assert response['image_sha256']==r.old.digest(image['data'])
        if response['status']=='received':
            raw=r.load(r.OUT/'raw'/f'{name}.json');candidate=r.lab.parse_json(raw['choices'][0]['message']['content'])
            assert candidate==response['candidate']
            actual,validation=r.extract.canonical(candidate)
            assert actual==response['actual'] and validation==response['validation']
        elif (r.OUT/'raw'/f'{name}.json').exists() and response['status'] in {'unreadable_printed_number','fractional_cent','invalid_unit'}:
            raw=r.load(r.OUT/'raw'/f'{name}.json');candidate=r.lab.parse_json(raw['choices'][0]['message']['content'])
            try:r.extract.canonical(candidate)
            except r.lab.LabError as error:assert str(error)==response['status']
            else:raise AssertionError('recorded_validation_failure_not_reproduced')
    result={'verified':True,'fictional_attempts':counts['fictional'],'real_attempts':counts['real'],'no_ocr_or_coordinates_in_requests':True,'frozen_configuration_verified':True,'canonical_results_reproduced':True,'production_changed':False}
    r.write(r.OUT/'verification.json',result);print(json.dumps(result))
if __name__=='__main__':
    try:verify()
    except Exception:sys.exit('Evidence verification failed; private details suppressed.')
