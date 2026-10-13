#!/usr/bin/env python3
"""Validate an explicit local human export and stage separately from automatic inputs."""
import argparse,copy,json,math,plistlib,uuid
from pathlib import Path
import experiment as e

def validate(data,identity):
    if data.get('schemaVersion')!=1 or data.get('nonce')!=identity['nonce']:raise ValueError('review_identity')
    expected={r['slot']:r for r in identity['receipts']};seen=set();texts=[];regions=[];currency=[]
    for receipt in data['receipts']:
        slot=receipt['slot']
        if type(slot) is not int or slot not in expected or slot in seen:raise ValueError('slot_identity')
        seen.add(slot)
        if any(receipt[k]!=expected[slot][k] for k in ('sourceHash','captureHash')):raise ValueError('source_identity')
        if type(receipt['humanVerified']) is not bool or type(receipt['regionVerified']) is not bool:raise ValueError('confirmation_type')
        if receipt['humanVerified']:
            obs=receipt['observations'];ids=set()
            if not obs or len(obs)>3000:raise ValueError('transcript_size')
            for row in obs:
                uuid.UUID(row['id'])
                if row['id'] in ids:raise ValueError('duplicate_row')
                ids.add(row['id'])
                if not isinstance(row['text'],str) or not row['text'].strip() or len(row['text'])>4000:raise ValueError('literal_text')
                if row.get('boundingBox') is None:raise ValueError('source_box_required')
                e.lab.validate_box(row['boundingBox'])
                c=row['engineConfidence']
                if type(c) not in (int,float) or not math.isfinite(c) or not 0<=c<=1:raise ValueError('invalid_confidence')
            texts.append({'slot':slot,'humanVerified':True,'observations':obs})
        if receipt['regionVerified']:
            e.lab.validate_box(receipt['region']);regions.append({'slot':slot,'humanVerified':True,'region':receipt['region']})
        value=receipt['currencyEvidence']
        if value not in ('unreviewed','CAD','not_printed','other_or_unclear'):raise ValueError('currency_state')
        if value!='unreviewed':currency.append({'slot':slot,'humanReportedEvidence':value})
    if not texts and not regions and not currency:raise ValueError('no_verified_work')
    return texts,regions,currency

def main():
    p=argparse.ArgumentParser();p.add_argument('--run',required=True);p.add_argument('--export',required=True);p.add_argument('--review',default=str(e.ROOT/'private-receipts/evaluation/p4-02-source-review'));a=p.parse_args()
    out=e.lab.private(a.run);m=e.read(out/'manifest.json');review=e.lab.private(a.review);identity=e.read(review/'identity.json');data=e.read(a.export)
    texts,regions,currency=validate(data,identity)
    for r in identity['receipts']:
        old=e.read(e.BASE/'manifest.json')['groups'][r['slot']]['images'][0]
        if e.digest(old['path'])!=r['sourceHash'] or e.digest(e.BASE/'captures'/f"capture-{r['slot']}-1.json")!=r['captureHash']:raise ValueError('source_changed')
    e.device_info(m['device']);container=Path(e.lab.run_tool(['xcrun','simctl','get_app_container',m['device'],e.lab.BUNDLE,'data']).strip());inbox=container/'Documents/P402Lab'/m['nonce']
    if (out/'human-export.json').exists():raise ValueError('existing_assistance_evidence')
    e.write(out/'human-export.json',data);e.write(out/'human-currency-evidence.json',currency)
    e.write(inbox/'transcripts.json',{'nonce':m['nonce'],'slots':texts});e.write(inbox/'regions.json',{'nonce':m['nonce'],'slots':regions})
    test=plistlib.loads((out/'private.xctestrun').read_bytes())
    targets=[t for c in test.get('TestConfigurations',[]) for t in c['TestTargets']] if 'TestConfigurations' in test else [test['SlipletTests']]
    targets[0]['EnvironmentVariables'].update(SLIPLET_P402_CHECKED_TEXT='YES' if texts else 'NO',SLIPLET_P402_CHECKED_REGIONS='YES' if regions else 'NO')
    (out/'assisted.xctestrun').write_bytes(plistlib.dumps(test))
    print(json.dumps({'checked_transcripts':len(texts),'verified_regions':len(regions),'currency_checks':len(currency)}))
if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('Human export validation failed; private contents were not printed')
