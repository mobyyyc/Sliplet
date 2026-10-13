#!/usr/bin/env python3
"""Independent essential-counter verification. Does not import the lab or legacy scorers."""
import argparse, collections, datetime, hashlib, json, math, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def load(p):return json.loads(Path(p).read_text())
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def date_key(value):
    if value is None:return None
    for fmt in ('%Y-%m-%d','%Y/%m/%d','%m/%d/%Y','%m/%d/%y','%d-%b-%Y','%b %d %Y'):
        try:return datetime.datetime.strptime(value,fmt).date().isoformat()
        except (ValueError,TypeError):pass
    return value

def norm(v):return ' '.join(str(v).casefold().split())
def verify(run):
    run=Path(run).resolve()
    if not run.is_relative_to(ROOT/'private-receipts'):raise ValueError()
    m=load(run/'manifest.json');report=load(run/'aggregate.json');refs=load(run/'reference-v2.json')['receipts']
    labels={r['id']:r for r in load(m['label_path'])['receipts']}
    assert len(m['groups'])==len(refs)==5
    assert sorted(r['slot'] for r in refs)==list(range(5))
    refs=sorted(refs,key=lambda r:r['slot'])
    statuses=collections.Counter();not_attempted=0
    blocked=collections.Counter()
    counts=collections.Counter(); coverage=collections.Counter(); failures=0; requests=0; all_wrong=0; draft_equal=0
    for slot,g in enumerate(m['groups']):
        label=labels[g['purchase_id']]
        assert label['reviewed'] and label['verification_method']=='human_against_original'
        assert all(label['verification_checks'].values())
        assert label['sha256']==g['images'][0]['sha256']
        for im in g['images']:assert digest(im['path'])==im['sha256']
        for repeat in (1,2):
            p=run/'captures'/f'capture-{slot}-{repeat}.json'
            status=load(run/'captures'/f'attempt-{slot}-{repeat}.json')['status'];statuses[status]+=1
            if status=='ok':
                assert p.exists();requests+=1
                capture=load(p);assert capture['nonce']==m['nonce'] and capture['slot']==slot and capture['pass']==repeat
                ids=[o['id'] for o in capture['observations']];assert len(ids)==len(set(ids))
                for key in ('groupedRowIDs','interpretedRowIDs'):
                    assert collections.Counter(ids)==collections.Counter(i for row in capture[key] for i in row)
                for line in capture['parsed']['lines']+capture['parsed']['issues']:
                    assert set(line['sourceLineIDs'])<=set(ids)
                for key in ('fields','draftFields'):
                    for line in capture[key]['items']+capture[key]['adjustments']:assert set(line['sourceLineIDs'])<=set(ids)
                assert capture['originalBytesEqual'] and capture['replayEqual']
                assert all(math.isfinite(capture[k]) and capture[k]>=0 for k in ('importToReviewMS','mainActorPollMaxGapMS'))
        p=run/'captures'/f'capture-{slot}-1.json'
        status=load(run/'captures'/f'attempt-{slot}-1.json')['status']
        if status!='ok':
            if status=='not_attempted_after_abort':not_attempted+=1
            else:failures+=1
            continue
        r=load(p);assert r['nonce']==m['nonce'];assert not r['draftCanFinalize']
        expected=label['expected'];actual=r['parsed'];actual_lines=actual['lines']
        ref_lines=expected['lines']
        expected_bag=collections.Counter((l['kind'],norm(l['description']),l['amount']) for l in ref_lines)
        actual_bag=collections.Counter(('adjustment' if l['kind']=='other' else l['kind'],norm(l['description']),l['amount']) for l in actual_lines)
        intersection=expected_bag & actual_bag
        counts['items_expected']+=sum(l['kind']=='purchase' for l in ref_lines)
        counts['lines_expected']+=len(ref_lines)
        counts['item_amounts_correct']+=sum(n for key,n in intersection.items() if key[0]=='purchase')
        counts['line_amounts_correct']+=sum(intersection.values())
        wrong=False
        for name in ('merchant','date','subtotal','total'):
            desired=expected[name]
            if desired is None:continue
            value=actual.get(name)
            if name=='date':
                desired=date_key(desired)
                if value:value='%04d-%02d-%02d'%(value['year'],value['month'],value['day'])
            equal=norm(value)==norm(desired) if name=='merchant' else value==desired
            counts[name+'_correct']+=int(equal);wrong |= not equal
        wrong |= expected_bag!=actual_bag
        all_wrong+=int(wrong)
        fields=r['fields'];draft=r['draftFields']
        if fields.get('currency') is None:
            blocked['currency_unresolved_receipts']+=1
            destination={line['id']:line for line in fields['items']+fields['adjustments']}
            for line in actual_lines:
                if line.get('amount') is not None and destination[line['id']].get('amount') is None:blocked['parser_line_amounts_blocked_by_currency']+=1
            for key in ('subtotal','total'):
                if actual.get(key) is not None and fields.get(key) is None:blocked['parser_summary_amounts_blocked_by_currency']+=1
        assert fields==draft # current adapter identity incl all fields, not just legacy amounts
        if r.get('storeRoundtripEqual'):
            assert r['reloadedFields']==draft and r['reviewInputEqual'];draft_equal+=1
        for fields in [refs[slot]['fields']]+[l['fields'] for l in refs[slot]['lines']]:
            for f in fields.values():coverage[f['state']]+=1
    assert dict(statuses)==report['attempt_statuses'] and not_attempted==report['first_not_attempted']
    assert sum(statuses.values())==report['attempts']==10
    assert requests==report['successful_attempts']==10 and failures==report['first_attempt_failures']==0
    request=load(run/'captures/staged-request.json');assert set(request)=={'nonce','slots'} and request['nonce']==m['nonce']
    assert len(request['slots'])==5 and sorted(s['slot'] for s in request['slots'])==list(range(5))
    assert all(set(s)=={'slot','image','sha256'} for s in request['slots'])
    assert report['repeat_pairs_equal']==5
    for key,n in counts.items():assert report['legacy'].get(key,0)==n
    assert dict(coverage)==report['coverage']
    for key,n in blocked.items():assert report[key]==n
    assert draft_equal==report['draft_storage_roundtrips_equal']
    # For this baseline, legacy discrepancies independently establish incorrectness;
    # expanded unknown fields cannot convert them into a correct or indeterminate result.
    assert all_wrong==report['verdicts'].get('incorrect',0)
    assert digest(m['label_path'])==m['label_hash'] and digest(run/'reference-v2.json')==m['reference_hash']
    for path,h in m['sources'].items():assert digest(ROOT/path)==h
    assert digest(ROOT/'Sliplet.xcodeproj/project.pbxproj')==m['project_hash']
    print(json.dumps({'independent_verification':'passed','purchases':len(m['groups']),'successful_attempts':requests,'essential_counts_checked':len(counts),'scope':'baseline aggregate/coverage/conversion/storage; not a second full scorer'}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',required=True)
    try:verify(p.parse_args().run)
    except Exception:print('Independent verification failed; private details suppressed.',file=sys.stderr);sys.exit(1)
