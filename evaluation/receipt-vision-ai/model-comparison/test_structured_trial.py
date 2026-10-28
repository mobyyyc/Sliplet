import json
import unittest
import structured_trial as trial
from test_structured_extract import candidate


class TrialTests(unittest.TestCase):
    def envelope(self,value,finish='STOP'):
        return {'candidates':[{'finishReason':finish,'content':{'parts':[{'text':json.dumps(value)}]}}]}
    def test_request_budget_and_duplicate_reservation(self):
        import tempfile
        from pathlib import Path
        from unittest.mock import patch
        old=trial.n.c.old
        with tempfile.TemporaryDirectory() as folder:
            with patch.object(old,'OUT',Path(folder)), patch.object(old,'MAX_CALLS',{'real':5,'fictional':2}), patch.object(old,'INTERVAL',0):
                old.reserve('real','case-0','fictional-hash')
                with self.assertRaises(Exception):old.reserve('real','case-0','fictional-hash')
                for i in range(1,5):old.reserve('real',f'case-{i}','fictional-hash')
                with self.assertRaises(Exception):old.reserve('real','case-5','fictional-hash')
                self.assertEqual(len(trial.load(Path(folder)/'calls.json')),5)
    def test_partial_completion_cannot_be_accepted(self):
        with self.assertRaises(trial.extract.lab.LabError):trial.parse(self.envelope(candidate(),'MAX_TOKENS'))
    def test_schema_violation_cannot_pass(self):
        c=candidate();c['rows'][0]['unexpected']='value'
        with self.assertRaises(trial.extract.lab.LabError):trial.parse(self.envelope(c))
    def test_prose_wrapper_is_rejected(self):
        e=self.envelope(candidate());e['candidates'][0]['content']['parts'][0]['text']='Here is the result: '+json.dumps(candidate())
        with self.assertRaises(trial.extract.lab.LabError):trial.parse(e)
    def test_fictional_gate_rejects_missing_extra_or_wrong_rows(self):
        expected={'total':125,'lines':[{'kind':'purchase','description':'FICTIONAL ITEM','amount':125}]}
        actual={'total':125,'lines':[dict(expected['lines'][0])]}
        self.assertTrue(trial.fictional_pass(actual,expected))
        actual['lines'][0]['amount']=126
        self.assertFalse(trial.fictional_pass(actual,expected))
        actual['lines']=expected['lines']*2
        self.assertFalse(trial.fictional_pass(actual,expected))
        actual['lines']=[]
        self.assertFalse(trial.fictional_pass(actual,expected))

if __name__=='__main__':unittest.main()
