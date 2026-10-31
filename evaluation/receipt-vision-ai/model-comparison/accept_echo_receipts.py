"""Owner-approved five-slot acceptance; each frozen native payload is sent at most once."""
import fcntl
import hashlib
import json
import os
import ssl
import time
import urllib.error
import urllib.request
from pathlib import Path

import accept_current_app as app

OUT = app.OUT.with_name('p8-07-echo-acceptance-01')
SLOTS = range(5)
trial = app.baseline.trial


def parse(envelope):
    choices = envelope.get('candidates', [])
    if len(choices) != 1 or choices[0].get('finishReason') != 'STOP':
        raise ValueError('incomplete')
    parts = choices[0]['content']['parts']
    text = ''.join(p.get('text', '') for p in parts if not p.get('thought')).strip()
    if text.startswith('```json\n') and text.endswith('```'):
        text = text[8:-3]
    candidate = trial.extract.lab.parse_json(text)
    if isinstance(candidate, dict) and candidate.get('additionalProperties') is False:
        del candidate['additionalProperties']
    return app.layout.canonical(candidate)


def prepare():
    old = app.load(app.OUT / 'configuration.json')
    assert old['model'] == app.MODEL and old['endpoint'] == app.ENDPOINT
    # Only the local response reader changed. Confirm exact inputs and sending code.
    for path, expected in old['files'].items():
        if Path(path).name in ('ReceiptModelReader.swift',):
            continue
        assert app.digest(app.ROOT / path) == expected
    reference_run = app.OUT.with_name('p8-07-current-app-02')
    actual, _ = parse(app.load(reference_run / 'raw/real-0-1.json'))
    assert len(actual['lines']) == 22
    config = {'calls':5, 'spacing_seconds':95, 'timeout_seconds':120, 'retries':0,
              'model':app.MODEL, 'endpoint':app.ENDPOINT, 'original_freeze':app.digest(app.OUT/'configuration.json'),
              'reader':app.digest(app.ROOT/'Sliplet/Recognition/Model/ReceiptModelReader.swift'),
              'runner':app.digest(Path(__file__)), 'reference':app.digest(trial.REFERENCE)}
    path = OUT / 'configuration.json'
    if path.exists():
        assert app.load(path) == config
    else:
        app.write(path, config)


def run():
    os.umask(0o077)
    OUT.mkdir(mode=0o700,exist_ok=True)
    with (OUT/'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB)
        prepare()
        assert app.load(app.ROOT/'private-receipts/evaluation/p8-02e/account-confirmation.json')['free_tier_billing_disabled_user_confirmed']
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),app.NoRedirect(),
                                             urllib.request.HTTPSHandler(context=ssl.create_default_context()))
        for slot in SLOTS:
            path = OUT / 'responses' / f'real-{slot}-1.json'
            reservation = OUT / f'call-{slot}.json'
            if reservation.exists():
                if not path.exists() or app.load(path).get('http_status') in (401,403,429):
                    break
                continue
            if slot:
                time.sleep(max(0,95-(time.time()-app.load(OUT/f'call-{slot-1}.json')['time'])))
            body = (app.OUT / f'request-{slot}.json').read_bytes()
            digest = hashlib.sha256(body).hexdigest()
            assert digest == app.load(app.OUT/'configuration.json')['files'][str((app.OUT/f'request-{slot}.json').relative_to(app.ROOT))]
            key = app.keychain.read_key()
            if not key:
                raise RuntimeError('missing_key')
            req = urllib.request.Request(app.ENDPOINT,data=body,headers={'x-goog-api-key':key,'Content-Type':'application/json'},method='POST')
            app.write(reservation,{'time':time.time(),'payload_sha256':digest})
            start = time.monotonic()
            result = {}
            try:
                with opener.open(req,timeout=120) as response:
                    raw = response.read(262145)
                if len(raw)>262144:
                    raise ValueError('oversize')
                envelope = json.loads(raw)
                app.write(OUT/'raw'/path.name,envelope)
                actual,validation = parse(envelope)
                result.update(status='received',actual=actual,validation=validation,usage=envelope.get('usageMetadata',{}))
            except urllib.error.HTTPError as error:
                result.update(status='provider_error',http_status=error.code)
            except (urllib.error.URLError,OSError):
                result.update(status='network_or_timeout')
            except (ValueError,KeyError,TypeError,trial.extract.lab.LabError):
                result.update(status='invalid_response')
            finally:
                del key,req
            result['elapsed_seconds'] = round(time.monotonic()-start,3)
            app.write(path,result)
            print(slot+1,result['status'],result.get('http_status',''),result['elapsed_seconds'],flush=True)
            if result.get('http_status') in (401,403,429):
                break


if __name__=='__main__':
    run()
