"""Post-hoc diagnostics only. Never changes primary scores, prompts or accepted output."""
import collections,copy,json,statistics,sys
import score as s
r=s.r

def diagnose():
    refs=r.load(r.ROOT/'private-receipts/evaluation/p7-05-final/reference-v3.json')['receipts']
    passes=[];ledger=[]
    for pair in (1,2):
        counts=collections.Counter();fields={};adjustments=collections.Counter();losses=collections.Counter();methods=collections.Counter();signs=collections.Counter();statuses=collections.Counter();projection_failures=collections.Counter();raw_fields={};readable=0
        for slot,ref in enumerate(refs):
            name=f'real-{slot}-{pair}-0'
            initial=r.OUT/'responses'/f'{name}.json'
            if not initial.exists():raise ValueError('incomplete_real_experiment')
            response=r.load(initial);statuses[response['status']]+=1
            # The only user-authorized retry is retained explicitly, never silently substituted in primary scoring.
            retry=r.OUT/'responses'/f'{name}-retry1.json'
            if retry.exists():name+='-retry1';response=r.load(retry)
            raw=r.OUT/'raw'/f'{name}.json';actual=s.empty();source={};c=None;assumed=False
            capture=r.load(r.ROOT/f'private-receipts/evaluation/p7-08-final/captures/capture-{slot}-{pair}.json');obs=capture['observations']
            if raw.exists():
                env=r.load(raw)
                try:
                    c=r.lab.parse_json(env['choices'][0]['message']['content']);r.lab.validate_shape(c,r.lab.SCHEMA);readable+=1
                    for k,label in ref['fields'].items():
                        value=s.minor(c[k]['value']) if k in ('subtotal','total') else c[k]['value']
                        raw_fields.setdefault(k,collections.Counter())[s.prior.field_result(label,value,k)]+=1
                    claims=[e for k in ['merchant','date','currency','subtotal','total'] for e in c[k]['evidence']]+[e for line in c['lines'] for e in line['evidence']]
                    ids={e['image_id'] for e in claims};images=response['input_images']
                    projected=copy.deepcopy(c)
                    # Conditional diagnostic only: bind a single claimed source to the single supplied image.
                    # This does NOT verify boxes/quotes, make the response admissible, or alter stored candidates.
                    if len(images)==1 and len(ids)==1 and ids!={images[0]['id']}:
                        assumed=True
                        for k in ['merchant','date','currency','subtotal','total']:
                            for e in projected[k]['evidence']:e['image_id']=images[0]['id']
                        for line in projected['lines']:
                            for e in line['evidence']:e['image_id']=images[0]['id']
                    r.lab.validate_candidate(projected,[im['id'] for im in images])
                    actual,obs,source,_=s.canonical(projected,images,obs)
                    signs['negative_amount_rows']+=sum(bool(x['amount'] and x['amount'].startswith('-')) for x in c['lines'])
                    signs['discount_kind_rows']+=sum(x['kind']=='discount' for x in c['lines'])
                except (r.lab.LabError,KeyError,ValueError) as error:
                    projection_failures[str(error) if isinstance(error,r.lab.LabError) else 'unprojectable_response']+=1
                    c=None;actual=s.empty()
            score=s.prior.score(actual,ref,obs);baseline=s.prior.score(s.prior.fields_actual(capture['reloadedFields']),ref,capture['observations'])
            for k in ['exact_purchase_pairs','expected_purchases','actual_purchases','missing_line_proxies','unrelated_unmatched_actual_lines']:counts[k]+=score['counts'].get(k,0)
            for key in ref['fields']:
                fields.setdefault(key,collections.Counter()).update(score['fields'][key])
                if baseline['fields'][key].get('correct',0)>score['fields'][key].get('correct',0):losses['summary_fields']+=1
            for row,old in zip(score['line_results'],baseline['line_results']):
                kind=ref['lines'][row['reference_line']]['fields']['kind'].get('value')
                exact=all(row['outcomes'].get(k)=='correct' for k in ['kind','description','amount']);was=all(old['outcomes'].get(k)=='correct' for k in ['kind','description','amount'])
                if was and not exact:losses['previously_exact_rows']+=1
                if kind!='purchase':adjustments['expected']+=1;adjustments['exact']+=int(exact)
            methods.update(source)
            ledger.append({'slot':slot,'pass':pair,'used_authorized_retry':name.endswith('retry1'),'assumed_single_image_binding':assumed,'score':score,'baseline_score':baseline,'source_methods':source})
        passes.append({'pass':pair,'readable_raw_responses':readable,'first_attempt_statuses':dict(statuses),'additional_projection_failures':dict(projection_failures),'raw_summary_fields_on_returned_outputs_only':{k:dict(v) for k,v in raw_fields.items()},'counts':dict(counts),'summary_fields':{k:dict(v) for k,v in fields.items()},'adjustments':dict(adjustments),'previously_correct_losses':dict(losses),'source_methods':dict(methods),'raw_sign_and_kind_counts':dict(signs)})
    response_files=sorted((r.OUT/'responses').glob('real-*.json'));usage=collections.Counter();times=[]
    for p in response_files:
        d=r.load(p);times.append(d['elapsed_seconds']);raw=r.OUT/'raw'/p.name
        if raw.exists():
            for k in ['prompt_tokens','completion_tokens','total_tokens']:usage[k]+=r.load(raw).get('usage',{}).get(k,0)
    report={'task':'P8-02','diagnostic_only':True,'assumption':'A single invalid claimed image ID is projected to the one supplied image solely for offline scoring. Model source boxes remain unverified claims. No candidate is accepted by this projection.','exposed_receipts':5,'held_out_receipts':0,'passes':passes,'real_requests_including_explicit_retry':len(response_files),'real_usage':dict(usage),'elapsed_seconds_including_keychain_network_validation':times,'app_changed':False,'full_acceptance':False}
    r.write(r.OUT/'conditional-diagnostic.json',report);r.write(r.OUT/'conditional-diagnostic-ledger.json',ledger)
    print(json.dumps(report,indent=2));return report
if __name__=='__main__':
    try:diagnose()
    except Exception:sys.exit('Diagnostic report stopped; private details suppressed.')
