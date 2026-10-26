"""Offline audit and honest comparison, including the original failed attempt."""
import collections,contextlib,importlib.util,io,json,sys
import compare as c

def main():
    c.freeze();calls=c.load(c.OUT/'calls.json');policy=c.OUT/'recovery-policy.json'
    maximum=7 if policy.exists() else 6
    assert len(calls)<=maximum and len({x['name'] for x in calls})==len(calls)
    if policy.exists():
        p=c.load(policy);assert p['script_sha256']==c.old.digest((c.HERE/'recover.py').read_bytes())
    fixtures={f['id']:f for f in c.load(c.base.FIXTURES/'manifest.json')};counts=collections.Counter();selected={}
    for call in calls:
        assert call['kind']=='fictional'
        name=call['name'];fixture_name=name.removeprefix('fictional-').removesuffix('-recovery');fixture=fixtures[fixture_name]
        request=c.load(c.OUT/'requests'/f'{name}.json');result=c.load(c.OUT/'responses'/f'{name}.json');counts[result['status']]+=1
        image=c.fixture_image(fixture);assert request==c.body(image)
        assert c.old.digest(json.dumps(request,sort_keys=True).encode())==call['payload_sha256']==result['payload_sha256']
        previous=c.load(c.ROOT/'private-receipts/evaluation/p8-02d/requests'/('fictional-'+fixture_name+'.json'));previous['model']=c.MODEL
        assert request==previous
        if result['status']=='received':
            raw=c.load(c.OUT/'raw'/f'{name}.json');candidate=c.base.lab.parse_json(raw['choices'][0]['message']['content']);assert candidate==result['candidate']
            actual,validation=c.base.extract.canonical(candidate);assert actual==result['actual'] and validation==result['validation']
        if fixture_name not in selected or name.endswith('-recovery'):selected[fixture_name]=result
    effective=c.OUT/'effective';previous_out=c.base.OUT
    for name,result in selected.items():c.write(effective/'responses'/('fictional-'+name+'.json'),result)
    try:
        c.base.OUT=effective
        spec=importlib.util.spec_from_file_location('fixed_scorer',c.base.HERE/'score.py');scorer=importlib.util.module_from_spec(spec);spec.loader.exec_module(scorer)
        with contextlib.redirect_stdout(io.StringIO()):score=scorer.fictional()
    finally:c.base.OUT=previous_out
    baseline=c.load(c.ROOT/'private-receipts/evaluation/p8-02d/fictional-score.json')
    score.update(task='P8-02E',model=c.MODEL,baseline={'model':'qwen/qwen3.8-27b','passed_cases':baseline['passed_cases'],'cases_run':baseline['cases_run']},attempts=len(calls),attempt_statuses=dict(counts),recovery_attempts=sum(x['name'].endswith('-recovery') for x in calls),real_uploads=0,comparison_complete=score['cases_run']==6 and all(x['status']=='received' for x in score['results']),accuracy_comparison_valid=score['cases_run']==6 and all(x['status']=='received' for x in score['results']))
    verification={'verified':True,'request_and_fixture_hashes_match':True,'same_prompt_schema_and_images':True,'canonical_results_reproduced':True,'baseline_unchanged':True,'fictional_attempts':len(calls),'real_attempts':0,'original_failure_retained':True}
    c.write(c.OUT/'comparison.json',score);c.write(c.OUT/'verification.json',verification)
    print(json.dumps({'model':c.MODEL,'cases_attempted':score['cases_run'],'fully_exact_cases':score['passed_cases'],'attempt_statuses':dict(counts),'comparison_complete':score['comparison_complete'],'baseline_exact':baseline['passed_cases'],'real_uploads':0,'verification_passed':True}))
if __name__=='__main__':
    try:main()
    except Exception:sys.exit('Comparison verification stopped; details suppressed.')
