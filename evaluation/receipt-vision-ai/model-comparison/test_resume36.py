import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import resume36 as r

class ResumptionTests(unittest.TestCase):
    def test_freeze_rejects_changed_policy(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(r.n, 'OUT', Path(directory)), patch.object(r, 'previous_freeze'):
                r.freeze()
                path = Path(directory) / 'resumption.json'
                policy = r.n.c.load(path)
                self.assertEqual(policy['real_attempts'], 0)
                self.assertEqual(policy['automatic_retries'], 0)
                self.assertEqual(policy['max_fictional_attempts'], 6)
                policy['max_fictional_attempts'] = 7
                r.n.c.write(path, policy)
                with self.assertRaises(r.n.c.base.lab.LabError):
                    r.freeze()

    def test_resume_cannot_retry_a_recorded_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(r.n, 'OUT', Path(directory)), patch.object(r.n.c, 'preflight'), patch.object(r.adapter, 'freeze'), patch.object(r.n, 'send') as send:
                fixture = r.n.c.load(r.n.c.base.FIXTURES / 'manifest.json')[0]
                path = Path(directory) / 'responses' / ('fictional-' + fixture['id'] + '.json')
                r.n.c.write(path, {'status': 'provider_error'})
                with self.assertRaises(r.n.c.base.lab.LabError):
                    r.adapter.run()
                send.assert_not_called()

if __name__ == '__main__':
    unittest.main()
