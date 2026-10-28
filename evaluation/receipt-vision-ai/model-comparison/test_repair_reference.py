"""Fictional checks for human-export binding and conservative reference updates."""
import copy
import unittest
import repair_reference as r


class RepairTests(unittest.TestCase):
    def fixture(self):
        proposal={'reviewID':'fictional','referenceHash':'hash','cases':[{'id':'test'}]}
        data={'schemaVersion':1,'complete':True,'reviewID':'fictional','referenceHash':'hash',
              'policy':'approve','cases':[{'id':'test','checked':True,'decision':'include',
              'kind':'purchase','description':'Fictional item','amount':'1.25'}]}
        return data,proposal

    def test_rejects_wrong_source_binding(self):
        for key in ('reviewID','referenceHash'):
            data,proposal=self.fixture();data[key]='other'
            with self.assertRaises(ValueError):r.validate_export(data,proposal,'hash')

    def test_rejects_unchecked_uncertain_or_missing_cases(self):
        for change in ({'checked':False},{'decision':'uncertain'}):
            data,proposal=self.fixture();data['cases'][0].update(change)
            with self.assertRaises(ValueError):r.validate_export(data,proposal,'hash')
        data,proposal=self.fixture();data['cases']=[]
        with self.assertRaises(ValueError):r.validate_export(data,proposal,'hash')

    def test_rejects_duplicate_cases_or_unapproved_policy(self):
        data,proposal=self.fixture();data['cases']*=2
        with self.assertRaises(ValueError):r.validate_export(data,proposal,'hash')
        data,proposal=self.fixture();data['policy']='discuss'
        with self.assertRaises(ValueError):r.validate_export(data,proposal,'hash')

    def test_exact_money_never_rounds_or_strips_markers(self):
        self.assertEqual(r.cents('-1.25'),-125)
        self.assertEqual(r.cents('0.10'),10)
        for token in ('1.001','1.25H','1e2','NaN','',1.25):
            with self.assertRaises(ValueError):r.cents(token)

    def test_valid_decisions_preserve_export(self):
        data,proposal=self.fixture();before=copy.deepcopy(data)
        self.assertEqual(len(r.validate_export(data,proposal,'hash')),1)
        self.assertEqual(data,before)
        data['cases'][0].update(decision='exclude',kind='other',amount='')
        self.assertEqual(r.validate_export(data,proposal,'hash')[0]['decision'],'exclude')

    def test_existing_evidence_cannot_be_overwritten(self):
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'result.json'
            r.write_once(path,{'value':1});r.write_once(path,{'value':1})
            with self.assertRaises(ValueError):r.write_once(path,{'value':2})
            self.assertEqual(r.load(path),{'value':1})


if __name__=='__main__':unittest.main()
