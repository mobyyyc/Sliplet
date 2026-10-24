import unittest
from grounding import fill_omissions
class GroundingTests(unittest.TestCase):
 def run_case(self,texts,**kw):
  row=dict(role='purchase',text='PEARS MRJ',amount=None,quantity=None,unit=None,unit_price=None,sources=list(range(len(texts))));row.update(kw)
  return fill_omissions({'entries':[row]},[{'text':t} for t in texts])[0]['entries'][0]
 def test_weighted_omissions_from_explicit_fragments(self):
  r=self.run_case(['550001 PEARS MRJ','0.750 kg @ 4.00/kg','3.00'])
  self.assertEqual((r['text'],r['amount'],r['quantity'],r['unit'],r['unit_price']),('550001 PEARS MRJ','3.00','0.750','kg','4.00'))
 def test_no_calculated_extension(self):
  r=self.run_case(['0.750 kg @ 4.00/kg']);self.assertIsNone(r['amount'])
 def test_ambiguous_prices_remain_unknown(self):
  self.assertIsNone(self.run_case(['2.00','3.00'])['amount'])
 def test_nonmissing_values_not_overwritten(self):
  r=self.run_case(['3.00'],amount='4.00');self.assertEqual(r['amount'],'4.00')
 def test_no_default_quantity_or_price(self):
  r=self.run_case(['550001 PEARS MRJ']);self.assertIsNone(r['amount']);self.assertIsNone(r['quantity'])
 def test_names_identifiers_not_prices(self):
  for text in ['1234567890','TOTAL CEREAL 4.20','2 @ 3.00']:
   self.assertIsNone(self.run_case([text])['amount'])
 def test_trailing_minus_retained(self):
  self.assertEqual(self.run_case(['1.25-'],role='discount')['amount'],'1.25-')
if __name__=='__main__':unittest.main()

class CurrencyGroundingTests(unittest.TestCase):
 def test_currency_printed_with_date(self):
  from grounding import printed_header_currency
  result,changes=printed_header_currency({'entries':[{'role':'date','sources':[0]}]},[{'text':'2031-01-15 CAD'}])
  self.assertEqual(result['entries'][-1]['text'],'CAD');self.assertTrue(changes)
 def test_no_currency_from_store_name_or_dollar(self):
  from grounding import printed_header_currency
  for text in ['CAD FOODS','COSTCO','$3.00']:
   self.assertEqual(printed_header_currency({'entries':[{'role':'merchant','sources':[0]}]},[{'text':text}])[1],[])
 def test_conflicting_currencies_not_selected(self):
  from grounding import printed_header_currency
  self.assertEqual(printed_header_currency({'entries':[{'role':'date','sources':[0,1]}]},[{'text':'CAD'},{'text':'USD'}])[1],[])
