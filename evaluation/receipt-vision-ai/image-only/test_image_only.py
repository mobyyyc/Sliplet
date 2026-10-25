import copy,unittest
from unittest.mock import patch
import run
extract=run.extract
class Tests(unittest.TestCase):
    def candidate(self):return dict(merchant='FICTIONAL MARKET',date='2031-01-15',currency=None,subtotal='4.00',total='3.00',rows=[self.row('purchase','550001 SOAP','4.00'),self.row('discount','COUPON','1.00-')])
    def row(self,kind,text,amount):return dict(kind=kind,description=text,amount=amount,quantity=None,unit=None,unit_price=None)
    def test_literal_sign(self):
        actual,v=extract.canonical(self.candidate());self.assertEqual(actual['lines'][1]['amount'],-100);self.assertEqual(v['issues'],[])
    def test_no_balance_repair(self):
        c=self.candidate();c['total']='8.00';a,v=extract.canonical(c);self.assertEqual(a['total'],800);self.assertIn('total_conflict',v['issues'])
    def test_no_default_quantity(self):self.assertIsNone(extract.canonical(self.candidate())[0]['lines'][0]['quantity'])
    def test_repeated_preserved(self):
        c=self.candidate();c['rows'].append(copy.deepcopy(c['rows'][0]));self.assertEqual(len(extract.canonical(c)[0]['lines']),3)
    def test_missing_total(self):
        c=self.candidate();c['total']=None;self.assertIsNone(extract.canonical(c)[0]['total'])
    def test_payment_excluded(self):
        c=self.candidate();c['rows'].append(self.row('payment','CARD','3.00'));self.assertEqual(len(extract.canonical(c)[0]['lines']),2)
    def test_source_fields_rejected(self):
        c=self.candidate();c['rows'][0]['sources']=[0]
        with self.assertRaises(extract.lab.LabError):extract.canonical(c)
    def test_invalid_date(self):
        c=self.candidate();c['date']='2031-02-30';self.assertIsNone(extract.canonical(c)[0]['date'])
    def test_fractional_cent_rejected(self):
        c=self.candidate();c['total']='1.234'
        with self.assertRaises(extract.lab.LabError):extract.canonical(c)
    def test_request_image_only(self):
        with patch.object(run.old,'raw_ocr',side_effect=AssertionError('OCR forbidden')):
            b=run.body({'data':b'fictional-image'})
        self.assertEqual(len(b['messages'][1]['content']),1);self.assertEqual(b['messages'][1]['content'][0]['type'],'image_url')
        self.assertNotIn('sources',str(b['response_format']));self.assertNotIn('coordinates',str(b['response_format']))

class EvaluationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import importlib.util
        spec=importlib.util.spec_from_file_location('image_only_score',run.HERE/'score.py');cls.score=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.score)
    def test_geometry_removed_only_from_copy(self):
        original={'lines':[{'original_regions':[{'x':0,'y':0,'width':1,'height':1}]}]}
        result=self.score.without_regions(original)
        self.assertEqual(result['lines'][0]['original_regions'],[]);self.assertEqual(len(original['lines'][0]['original_regions']),1)
    def test_unique_name_not_price_matching(self):
        ref={'lines':[{'original_regions':[],'fields':{'kind':{'value':'purchase'},'description':{'value':'SOAP'}}}]}
        actual=[{'kind':'purchase','description':'OTHER','amount':100}]
        pairs,unmatched,ambiguous=self.score.prior.pairing(actual,ref,[])
        self.assertEqual(pairs,[(0,None)]);self.assertEqual(unmatched,[0])
    def test_duplicate_names_remain_ambiguous(self):
        row={'original_regions':[],'fields':{'kind':{'value':'purchase'},'description':{'value':'SOAP'}}}
        ref={'lines':[copy.deepcopy(row),copy.deepcopy(row)]}
        actual=[{'kind':'purchase','description':'SOAP','amount':100},{'kind':'purchase','description':'SOAP','amount':200}]
        pairs,unmatched,ambiguous=self.score.prior.pairing(actual,ref,[])
        self.assertEqual(ambiguous,[0,1]);self.assertTrue(all(j is None for i,j in pairs))

if __name__=='__main__':unittest.main()
