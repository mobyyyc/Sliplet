import json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import ocr_anchors
class OCRIsolationTests(unittest.TestCase):
 def test_calls_use_distinct_private_input_files(self):
  seen=[]
  def fake(args,**kw):
   path=Path(args[1]);seen.append(path)
   self.assertEqual(path.read_bytes(),b'fictional-prepared-bytes')
   return type('Result',(),{'returncode':0,'stdout':b'[]'})()
  with tempfile.TemporaryDirectory() as folder,patch.object(ocr_anchors.subprocess,'run',side_effect=fake):
   for _ in range(2):ocr_anchors.recognize(b'fictional-prepared-bytes',Path(folder))
   self.assertNotEqual(seen[0],seen[1]);self.assertTrue(all(not p.exists() for p in seen))
if __name__=='__main__':unittest.main()
