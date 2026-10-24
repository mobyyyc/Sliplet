"""Read retained evidence and reproduce aggregates without any network call."""
import contextlib,io,json
import runner as r
import score as s
import diagnose as d

def main():
    manifest=r.load(r.OUT/'final-manifest.json')
    for name,sha in manifest.items():
        if r.digest((r.ROOT/name).read_bytes())!=sha:raise ValueError('retained_input_changed')
    for name,sha in r.load(r.OUT/'scoring-freeze.json').items():
        if r.digest((r.ROOT/name).read_bytes())!=sha:raise ValueError('frozen_scorer_or_reference_changed')
    images=r.verified_real_images();calls=r.load(r.OUT/'calls.json')
    assert len(calls)==23 and len({x['name'] for x in calls})==23
    assert sum(x['kind']=='fictional' for x in calls)==12
    assert sum(x['kind']=='real' for x in calls)==11
    for call in calls:
        request=r.load(r.OUT/'requests'/f"{call['name']}.json")
        result=r.load(r.OUT/'responses'/f"{call['name']}.json")
        assert r.digest(json.dumps(request,sort_keys=True).encode())==call['payload_sha256']==result['payload_sha256']
        if call['kind']=='real':
            slot=int(call['name'].split('-')[1]);assert request==r.body_for(images[slot])
    public=r.load(r.ROOT/'docs/evidence/p8-02/aggregate.json')
    with contextlib.redirect_stdout(io.StringIO()):
        fictional=s.fictional();primary=s.real_scores();diagnostic=d.diagnose()
    for run in primary['passes']:run['validated_response_usage_only']=run.pop('usage')
    assert primary==public['primary'] and diagnostic==public['conditional_diagnostic']
    assert fictional==r.load(r.ROOT/'docs/evidence/p8-02/fictional.json')
    assert public['real']['schema_source_valid_outputs']==1
    assert public['real']['schema_source_valid_outputs_without_semantic_issues']==0
    print('PASS: 23 retained attempts, exact approved real payloads, frozen labels/scorer and aggregate reports reproduced offline. No network calls.')
if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('P8-02 verification failed; private details suppressed.')
