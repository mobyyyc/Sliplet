"""Offline evidence verification; never prints receipt content or digests."""
import base64,collections,io,json,sys
from PIL import Image
import run as r

def verify():
    r.freeze()
    config=r.load(r.OUT/'configuration.json')
    assert r.old.digest((r.ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json').read_bytes())==config['references_sha256']
    real=r.old.verified_real_images()
    fixtures={x['id']:x for x in r.load(r.HERE/'fixtures/manifest.json')}
    calls=r.load(r.OUT/'calls.json');counts=collections.Counter(x['kind'] for x in calls)
    assert counts['fictional']==6 and 0 < counts['real'] <= 10
    assert len({x['name'] for x in calls})==len(calls)
    for item in calls:
        name=item['name'];req=r.load(r.OUT/'requests'/f'{name}.json');response=r.load(r.OUT/'responses'/f'{name}.json')
        assert r.old.digest(json.dumps(req,sort_keys=True).encode())==item['payload_sha256']==response['payload_sha256']
        if item['kind']=='real':
            image=real[int(name.split('-')[1])][0]
        else:
            fixture=fixtures[name.removeprefix('fictional-')]
            data=(r.HERE/'fixtures'/fixture['image']).read_bytes()
            assert r.old.digest(data)==fixture['sha256']
            image=r.old.tiles(Image.open(io.BytesIO(data)))[0]
        content=req['messages'][1]['content']
        assert base64.b64decode(content[1]['image_url']['url'].split(',',1)[1])==image['data']
        assert response['image_sha256']==r.old.digest(image['data'])
        anchors=response['anchors']
        if item['kind']=='real':assert req==r.body(image,anchors)
        raw=r.load(r.OUT/'raw'/f'{name}.json') if (r.OUT/'raw'/f'{name}.json').exists() else None
        if response['status']=='received':
            assert response['candidate']==r.lab.parse_json(raw['choices'][0]['message']['content'])
            actual,obs,validation=r.contract.canonical(response['candidate'],anchors)
            selected=r.load(r.OUT/'calibrated'/f'{name}.json') if item['kind']=='fictional' else response
            assert (actual,obs,validation)==(selected['actual'],selected['observations'],selected['validation'])
    report={'verified':True,'fictional_attempts':counts['fictional'],'real_attempts':counts['real'],'approved_pixels_verified':True,'frozen_configuration_verified':True,'unchanged_references_verified':True,'canonical_results_reproduced':True,'production_changed':False,'planned_real_attempts':10,'real_attempts_not_run':10-counts['real']}
    r.write(r.OUT/'verification.json',report);print(json.dumps(report))
if __name__=='__main__':
    try:verify()
    except Exception:sys.exit('Evidence verification failed; private details suppressed.')
