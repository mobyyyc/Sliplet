"""Complete unattempted fictional cases after a recorded local validation failure.
Never retry a request, bypass provider failure, or allow private inference.
"""
import io,os,sys
from PIL import Image
import run as r
LOCAL_FAILURES={'unreadable_printed_number','fractional_cent','schema_type','schema_keys','schema_enum','schema_array_size','invalid_completion','incomplete_completion','model_refusal'}
def main():
    r.freeze()
    for response in (r.OUT/'responses').glob('fictional-*.json'):
        if r.load(response)['status'] not in LOCAL_FAILURES|{'received'}:raise r.lab.LabError('provider_failure_do_not_resume')
    for fixture in r.load(r.FIXTURES/'manifest.json'):
        name='fictional-'+fixture['id']
        if (r.OUT/'responses'/f'{name}.json').exists():continue
        data=(r.FIXTURES/fixture['image']).read_bytes()
        if r.old.digest(data)!=fixture['sha256']:raise r.lab.LabError('fixture_changed')
        images=r.old.tiles(Image.open(io.BytesIO(data)))
        if len(images)!=1:raise r.lab.LabError('full_image_required')
        r.old.wait_spacing();result=r.call('fictional',name,images[0])
        if result['status'] not in LOCAL_FAILURES|{'received'}:raise r.lab.LabError('provider_failure_do_not_resume')
if __name__=='__main__':
    os.umask(0o077)
    try:main()
    except Exception as e:sys.exit(str(e) if isinstance(e,r.lab.LabError) else 'fictional_run_stopped')
