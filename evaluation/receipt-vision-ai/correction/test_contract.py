import copy,unittest
import contract as c
class ContractTests(unittest.TestCase):
 def row(self,role,text=None,amount=None,sources=None):return dict(role=role,text=text,amount=amount,quantity=None,unit=None,unit_price=None,sources=[0] if sources is None else sources)
 def test_printed_signs(self):
  for t in ['1.25-','-1.25','(1.25)','1.25−']:self.assertEqual(c.decimal_token(t,True),'-1.25')
  self.assertEqual(c.decimal_token('1.25',True),'1.25')
 def test_malformed_numbers_not_guessed(self):
  for t in ['1?25','1.2S','1.00--','2 @ 3.00']:
   with self.assertRaises(c.lab.LabError):c.decimal_token(t,True)
 def test_no_fractional_cent_rounding(self):
  with self.assertRaises(c.lab.LabError):c.decimal_token('1.005',True)
 def test_unknown_image_and_anchor_rejected(self):
  s=c.schema(2);candidate={'image_id':'image-99','date_iso':None,'entries':[]}
  with self.assertRaises(c.lab.LabError):c.lab.validate_shape(candidate,s)
  candidate.update(image_id='image-0',entries=[self.row('purchase','ABC','1.00',[99])])
  with self.assertRaises(c.lab.LabError):c.lab.validate_shape(candidate,s)
 def test_source_ids_must_be_integers(self):
  with self.assertRaises(c.lab.LabError):c.canonical({'image_id':'image-0','date_iso':None,'entries':[self.row('purchase','ABC','1.00',[0.0])]},[{'text':'ABC','box':[0,0,.5,.1]}])
 def test_descriptions_and_repeated_occurrences_preserved(self):
  name='550001 PEARS ABC';rows=[self.row('purchase',name,'2.00'),self.row('purchase',name,'2.00'),self.row('total',None,'4.00')]
  a,_,v=c.canonical({'image_id':'image-0','date_iso':None,'entries':rows},[{'text':'not an answer','box':[0,0,.5,.1]}])
  self.assertEqual([x['description'] for x in a['lines']],[name,name]);self.assertEqual(v['issues'],[])
 def test_positive_discount_not_forced_negative(self):
  a,_,v=c.canonical({'image_id':'image-0','date_iso':None,'entries':[self.row('discount','COUPON','1.00')]},[{'text':'COUPON','box':[0,0,.5,.1]}])
  self.assertEqual(a['lines'][0]['amount'],100);self.assertIn('discount_sign_needs_review',v['issues'])
 def test_unreadable_total_not_calculated(self):
  a,_,v=c.canonical({'image_id':'image-0','date_iso':None,'entries':[self.row('purchase','ABC','2.00'),self.row('total')]},[{'text':'ABC','box':[0,0,.5,.1]}])
  self.assertIsNone(a['total']);self.assertIn('missing_total',v['issues'])
 def test_ambiguous_date_not_resolved_by_model_guess(self):
  self.assertIsNone(c.normalize_date('03/04/31','2031-03-04','FICTIONAL MARKET'))
  self.assertEqual(c.normalize_date('2031-01-15',None,'FICTIONAL MARKET'),'2031-01-15')
 def test_existing_nofrills_clock_rule(self):
  self.assertEqual(c.normalize_date('31/01/15 12:35',None,'NOFRILLS'),'2031-01-15')
 def test_brand_policy_not_substring_match(self):
  self.assertEqual(c.merchant('Costco Wholesale'),'COSTCO')
  self.assertEqual(c.merchant('Compare with Costco'),'Compare with Costco')
  self.assertEqual(c.merchant('FICTIONAL MARKET'),'FICTIONAL MARKET')
if __name__=='__main__':unittest.main()
