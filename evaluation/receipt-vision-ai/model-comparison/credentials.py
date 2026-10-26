"""Separate macOS Keychain item for fictional Gemini comparison."""
import importlib.util,json,os,sys,getpass,datetime,warnings
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
spec=importlib.util.spec_from_file_location('gemini_keychain',HERE.parent/'lab_keychain.py')
keychain=importlib.util.module_from_spec(spec);spec.loader.exec_module(keychain)
keychain.SERVICE='com.sliplet.development.gemini'
OUT=ROOT/'private-receipts/evaluation/p8-02e'

def configure():
    if not sys.stdin.isatty():raise RuntimeError('hidden_entry_requires_terminal')
    print('Sliplet — Gemini fictional model comparison')
    print('Only six fictional receipt images. No personal receipts. No billing changes.')
    print('Use a Free-tier Google AI Studio project with billing disabled.')
    if input('Type FREE to confirm that project setting: ').strip().upper()!='FREE':return
    with warnings.catch_warnings():
        warnings.simplefilter('error',getpass.GetPassWarning)
        secret=getpass.getpass('Paste Gemini API key (hidden): ').strip()
    if not secret or len(secret)>512 or any(c.isspace() for c in secret):raise RuntimeError('invalid_key_format')
    keychain.save_key(secret);del secret
    OUT.mkdir(parents=True,exist_ok=True,mode=0o700)
    marker=OUT/'account-confirmation.json'
    marker.write_text(json.dumps({'provider':'Google Gemini','free_tier_billing_disabled_user_confirmed':True,'confirmed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'fictional_only':True})+'\n');marker.chmod(0o600)
    print('Saved in macOS Keychain. No API call made yet. Return to Main and say finished.')
if __name__=='__main__':
    os.umask(0o077)
    try:configure()
    except Exception:sys.exit('Key setup did not finish; no secret details displayed.')
