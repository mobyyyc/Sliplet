import unittest
from semantics import payment_roles
class PaymentRoleTests(unittest.TestCase):
 def make(self,text='CARD',y=.8,ocr='CARD'):
  return {'entries':[{'role':'total','text':None,'sources':[0]},{'role':'tax','text':text,'sources':[1]}]},[{'text':'TOTAL','box':[0,.6,.7,.65]},{'text':ocr,'box':[0,y,.7,y+.04]}]
 def test_explicit_footer_payment(self):
  c,a=self.make();out,changes=payment_roles(c,a)
  self.assertEqual(out['entries'][1]['role'],'payment');self.assertEqual(c['entries'][1]['role'],'tax');self.assertEqual(len(changes),1)
 def test_gift_card_product_not_payment(self):
  c,a=self.make('GIFT CARD',.8,'550001 GIFT CARD');self.assertEqual(payment_roles(c,a)[1],[])
 def test_card_above_total_not_payment(self):
  c,a=self.make(y=.4);self.assertEqual(payment_roles(c,a)[1],[])
 def test_omitted_product_code_not_payment(self):
  c,a=self.make(ocr='550001 CARD');self.assertEqual(payment_roles(c,a)[1],[])
 def test_missing_source_label_not_payment(self):
  c,a=self.make(ocr='something else');self.assertEqual(payment_roles(c,a)[1],[])
if __name__=='__main__':unittest.main()
