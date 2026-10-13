import unittest
import assisted
class AssistedTests(unittest.TestCase):
 def data(self):
  identity={'nonce':'run','receipts':[{'slot':0,'sourceHash':'source','captureHash':'capture'}]}
  receipt={**identity['receipts'][0],'humanVerified':False,'regionVerified':False,'region':None,'currencyEvidence':'unreviewed','observations':[]}
  return {'schemaVersion':1,'nonce':'run','receipts':[receipt]},identity
 def test_unchecked_is_not_transcript(self):
  d,i=self.data()
  with self.assertRaises(ValueError):assisted.validate(d,i)
 def test_currency_check_does_not_authorize_text(self):
  d,i=self.data();d['receipts'][0]['currencyEvidence']='not_printed'
  t,r,c=assisted.validate(d,i);self.assertEqual((len(t),len(r),len(c)),(0,0,1))
 def test_forged_source_identity_rejected(self):
  d,i=self.data();d['receipts'][0]['sourceHash']='changed'
  with self.assertRaises(ValueError):assisted.validate(d,i)
 def test_string_confirmation_rejected(self):
  d,i=self.data();d['receipts'][0]['humanVerified']='true'
  with self.assertRaises(ValueError):assisted.validate(d,i)
 def test_verified_region_does_not_authorize_transcript(self):
  d,i=self.data();d['receipts'][0].update(regionVerified=True,region={'x':0,'y':0,'width':1,'height':1})
  t,r,c=assisted.validate(d,i);self.assertEqual((len(t),len(r)),(0,1))
if __name__=='__main__':unittest.main()
