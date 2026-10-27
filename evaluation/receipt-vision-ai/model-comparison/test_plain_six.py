import tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import plain_six as s

class Tests(unittest.TestCase):
    def test_incomplete_never_parsed(self):
        with self.assertRaises(s.n.c.base.lab.LabError):
            s.parse({'candidates':[{'finishReason':'MAX_TOKENS','content':{'parts':[{'text':'{}'}]}}]})

    def test_original_pilot_request_unchanged(self):
        fixture=s.n.c.load(s.n.c.base.FIXTURES/'manifest.json')[0]
        body=s.pilot.body(s.n.c.fixture_image(fixture)['data'],True)
        saved=s.n.c.load(s.n.c.OUT/'resolution-diagnosis-01/requests/extraction-original.json')
        self.assertEqual(body,saved)

    def test_six_failures_never_retried(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(s,'OUT',Path(directory)),patch.object(s,'freeze'),patch.object(s.n.c.old,'wait_spacing',side_effect=lambda:setattr(s.n.c.old,'INTERVAL',0)),patch.object(s.n.c.credentials.keychain,'read_key',return_value='fictional-key'),patch.object(s.n,'send',side_effect=s.n.c.base.lab.LabError('provider_error',{'http_status':503})) as send:
                s.run();s.run()
                self.assertEqual(send.call_count,6)
                self.assertEqual(len(s.n.c.load(Path(directory)/'calls.json')),6)

    def test_rate_limit_stops_remaining(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(s,'OUT',Path(directory)),patch.object(s,'freeze'),patch.object(s.n.c.old,'wait_spacing',side_effect=lambda:setattr(s.n.c.old,'INTERVAL',0)),patch.object(s.n.c.credentials.keychain,'read_key',return_value='fictional-key'),patch.object(s.n,'send',side_effect=s.n.c.base.lab.LabError('rate_limited',{'http_status':429})) as send:
                s.run();s.run()
                self.assertEqual(send.call_count,1)

if __name__=='__main__':unittest.main()
