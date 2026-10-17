#!/usr/bin/env python3
"""Independent semantic/provenance comparison; only aggregate counters leave private storage."""
import collections,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(p): return json.loads(p.read_text())
def stable(c):
    positions={o['id']:i for i,o in enumerate(c['observations'])}
    def clean(v):
        if isinstance(v,dict):
            return {k:sorted(positions[x] for x in a) if k=='sourceLineIDs' else clean(a) for k,a in v.items() if k!='id'}
        if isinstance(v,list):return [clean(a) for a in v]
        return v
    return clean(c['draftFields'])
def main():
    root=(ROOT/sys.argv[1]).resolve()
    assert root.is_relative_to((ROOT/'private-receipts/evaluation').resolve())
    counts=collections.Counter()
    for slot in range(5):
        c=read(root/'captures'/f'capture-{slot}-1.json')
        old=read(ROOT/'private-receipts/evaluation/p5-05-final-v3/captures'/f'capture-{slot}-1.json')
        assert stable(c)==stable(old)
        counts['identical_p505_fields_and_sources']+=1
        for a in read(root/'captures'/f'reread-{slot}.json'):
            region=a['region']
            observations={o['id']:o for o in a['observations']}
            for o in observations.values():
                b=o['boundingBox'];assert region is not None and b is not None
                for key,extent in [('x','width'),('y','height')]:
                    assert b[key]>=region[key]-0.00001
                    assert b[key]+b[extent]<=region[key]+region[extent]+0.00001
                counts['contained_region_observations']+=1
            for choice in a['choices']:
                o=observations[choice['observationID']]
                raw=o['text'].encode('utf-16-le');start=choice['rangeStart']*2;end=start+choice['rangeLength']*2
                assert 0<=start<end<=len(raw)
                assert raw[start:end].decode('utf-16-le')==choice['literal']
                counts['literal_source_choices']+=1
    print(json.dumps(dict(counts),sort_keys=True))
if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('Detailed verification failed; private evidence suppressed')
