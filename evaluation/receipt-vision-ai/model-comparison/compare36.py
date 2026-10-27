"""3.6 comparison using the original unchanged chat-compatible request format."""
import os,sys
from pathlib import Path
import compare as c
c.MODEL='gemini-3.6-flash';c.OUT=c.credentials.OUT/'compatible-36';c.old.OUT=c.OUT
def preflight():
    marker=c.credentials.OUT/'account-confirmation.json'
    if not marker.exists() or c.load(marker).get('free_tier_billing_disabled_user_confirmed') is not True:raise c.base.lab.LabError('free_account_confirmation_required')
    if not c.credentials.keychain.read_key():raise c.base.lab.LabError('gemini_keychain_entry_missing')
    c.source_configuration()
c.preflight=preflight
original_freeze=c.freeze

def freeze():
    original_freeze()
    selection={'model':c.MODEL,'reason':'3.6 text availability confirmed; compare through original chat-compatible format after native schema rejection','script_sha256':c.old.digest(Path(__file__).read_bytes()),'maximum_attempts':6,'real_attempts':0}
    path=c.OUT/'selection.json'
    if path.exists() and c.load(path)!=selection:raise c.base.lab.LabError('selection_changed')
    if not path.exists():c.write(path,selection)
c.freeze=freeze
if __name__=='__main__':
    os.umask(0o077)
    try:
        if sys.argv[1:]==['run']:c.run()
        elif sys.argv[1:]==['score']:c.score()
        else:raise c.base.lab.LabError('fictional_only_command_required')
    except Exception as e:sys.exit(str(e) if isinstance(e,(c.base.lab.LabError,c.transport.LabError)) else 'comparison_stopped_details_suppressed')
