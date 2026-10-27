import tempfile,unittest,json
from pathlib import Path
from unittest.mock import patch
import real_five as r
from report_real_five import decode

class Tests(unittest.TestCase):
    def test_only_five_requests_no_retries(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(r,'OUT',Path(directory)),patch.object(r,'freeze'),patch.object(r.n.c.old,'verified_real_images',return_value=[[{'data':b'fictional'}] for _ in range(5)]),patch.object(r.n.c.old,'wait_spacing',side_effect=lambda:setattr(r.n.c.old,'INTERVAL',0)),patch.object(r.n.c.credentials.keychain,'read_key',return_value='fixture'),patch.object(r.n,'send',side_effect=r.n.c.base.lab.LabError('provider_error',{'http_status':503})) as send:
                r.run();r.run()
                self.assertEqual(send.call_count,5)
                self.assertEqual({c['kind'] for c in r.n.c.load(Path(directory)/'calls.json')},{'real'})

    def test_incomplete_rejected(self):
        with self.assertRaises(r.n.c.base.lab.LabError):
            decode({'candidates':[{'finishReason':'MAX_TOKENS','content':{'parts':[{'text':'{}'}]}}]})

    def test_only_outer_fence_whitespace_is_ignored(self):
        value={key:None for key in r.n.c.base.extract.SCHEMA['properties']}
        value['rows']=[]
        text='```json\n'+json.dumps(value)+'```'
        envelope={'candidates':[{'finishReason':'STOP','content':{'parts':[{'text':text}]}}]}
        actual,validation,wrapped=decode(envelope)
        self.assertTrue(wrapped)
        self.assertEqual(actual['lines'],[])
        self.assertIsNone(actual['total'])

    def test_prose_not_removed(self):
        with self.assertRaises(r.n.c.base.lab.LabError):
            decode({'candidates':[{'finishReason':'STOP','content':{'parts':[{'text':'Here is your receipt: {}'}]}}]})

if __name__=='__main__':unittest.main()
