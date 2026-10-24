import copy,json,unittest
import score as s
class ScoringTests(unittest.TestCase):
 def test_numeric_precision_not_string_format(self):
  self.assertTrue(s.equal('0.750','0.75','quantity'))
  self.assertFalse(s.equal('-1.00','1.00','amount'))
 def test_no_rounding_money(self):
  self.assertIsNone(s.minor('1.005'));self.assertEqual(s.minor('-1.00'),-100)
 def test_duplicate_source_not_arbitrarily_assigned(self):
  line={'id':'a','description':'APPLE','evidence':[]}
  obs=[{'id':str(i),'text':'APPLE'} for i in range(2)]
  self.assertEqual(s.source_anchors(line,[],obs)[2],'unresolved')
 def test_source_alignment_does_not_use_amount(self):
  obs=[{'id':'one','text':'PEARS'}]
  line={'id':'a','description':'PEARS','amount':'999.00','evidence':[]}
  self.assertEqual(s.source_anchors(line,[],obs)[0],['one'])
 def test_tile_source_transform(self):
  line={'id':'a','description':None,'evidence':[{'image_id':'image-1','quote':'','box':[0,.2,1,.4]}]}
  ims=[{'id':'image-1','rect':[0,1440,1000,2440],'size':[1000,3000]}]
  _,obs,method=s.source_anchors(line,ims,[])
  self.assertEqual(method,'model_box_claim');self.assertAlmostEqual(obs[0]['boundingBox']['y'],1-1840/3000)
 def test_payment_is_reported_separately(self):
  c=json.loads((s.r.lab.HERE/'fixtures/smoke.expected.json').read_text())
  actual,_,_,supp=s.canonical(c,[],[])
  self.assertEqual(len(actual['lines']),3);self.assertEqual(supp,{'payment':1})
if __name__=='__main__':unittest.main()
