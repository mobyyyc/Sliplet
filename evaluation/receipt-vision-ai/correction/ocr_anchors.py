"""Isolated, local OCR of prepared pixels; concurrent calls cannot share a file."""
import json,subprocess,tempfile
from pathlib import Path

def recognize(image_bytes,private_directory):
    scratch=private_directory/'ocr-scratch';scratch.mkdir(parents=True,exist_ok=True,mode=0o700)
    with tempfile.TemporaryDirectory(prefix='input-',dir=scratch) as folder:
        path=Path(folder)/'prepared.jpg';path.write_bytes(image_bytes);path.chmod(0o600)
        result=subprocess.run(['/tmp/sliplet-p802-ocr',str(path)],capture_output=True,timeout=60)
        if result.returncode:raise ValueError('local_ocr_failed')
        return json.loads(result.stdout)
