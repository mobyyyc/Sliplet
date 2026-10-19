#!/usr/bin/env python3
"""Verify retained P7-02 evidence without printing private contents."""
import collections, json
import run as proof

def main():
    out=proof.OUT
    hashes=proof.read(out/'manifest.json')
    assert all(proof.digest(proof.ROOT/p)==h for p,h in hashes.items())
    refs=proof.read(proof.BASE/'reference-v2.json')['receipts']
    scores=proof.read(out/'scores.json'); exact=collections.Counter()
    strip=lambda lines:[{k:v for k,v in line.items() if k!='id'} for line in lines]
    for slot,ref in enumerate(refs):
        old=proof.read(proof.BASE/f'captures/capture-{slot}-1.json')
        saved=proof.read(out/f'candidate-{slot}.json');fresh=proof.run(old['observations'])
        assert saved['observations']==fresh['observations']==old['observations']
        assert strip(saved['parsed']['lines'])==strip(fresh['parsed']['lines'])
        for key in set(saved['parsed'])|set(fresh['parsed']):
            if key!='lines': assert saved['parsed'].get(key)==fresh['parsed'].get(key)
        for which,capture in [('before',old),('after',saved)]:
            score=proof.lab.score(proof.actual(capture),ref,capture['observations'])
            assert score==scores[slot][which]
            exact[which]+=score['counts']['exact_purchase_pairs']
    aggregate=proof.read(out/'aggregate.json')
    assert exact['before']==aggregate['checks']['exact_pairs_before']==43
    assert exact['after']==aggregate['checks']['exact_pairs_after']==43
    assert aggregate['promotion']=='rejected'
    assert proof.fictional()==11
    print('P7-02: private evidence, five parser replays, scores and 11 fictional cases verified.')
if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('P7-02 verification failed; private contents suppressed')
