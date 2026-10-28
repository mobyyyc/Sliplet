import copy
import unittest
import structured_extract as s


def candidate():
    root={k:None for k in s.SCHEMA['properties'] if k!='rows'}
    row={k:None for k in s.SCHEMA['properties']['rows']['items']['properties']}
    row.update(kind='purchase',description='83472 OAT DRINK ABC',amount='5.40',quantity='2',unit_price='2.70',product_code='83472',tax_marker='T',raw_text='83472 OAT DRINK ABC 5.40 T')
    root.update(total='5.40',rows=[row],tax_legend='T=GST')
    return root


class StructuredTests(unittest.TestCase):
    def test_fields_and_raw_are_preserved_without_taxability_guess(self):
        c=candidate();original=copy.deepcopy(c);a,v=s.canonical(c);r=a['lines'][0]
        self.assertEqual((r['sku'],r['taxMarker'],r['amount'],r['unitPrice'],r['quantity']),('83472','T',540,270,'2'))
        self.assertEqual(r['description'],'83472 OAT DRINK ABC');self.assertEqual(c,original)
        self.assertFalse(v['taxability_inferred']);self.assertTrue(v['review_required'])
    def test_tax_base_is_not_added_as_purchase_amount(self):
        c=candidate();c['rows'][0].update(kind='tax',description='T=GST',amount='0.50',tax_base='10.00',tax_rate='5.000');c['total']='0.50'
        a,v=s.canonical(c);self.assertEqual(a['lines'][0]['taxBase'],1000);self.assertEqual(a['lines'][0]['amount'],50)
        self.assertNotIn('total_conflict',v['issues'])
    def test_other_zero_rows_are_retained_but_not_accounted(self):
        c=candidate();r=copy.deepcopy(c['rows'][0]);r.update(kind='other',description='POINTS EARNED',amount='0.00');c['rows'].append(r)
        a,v=s.canonical(c);self.assertEqual(len(a['lines']),1);self.assertEqual(len(a['nonAccountingRows']),1)
        self.assertNotIn('total_conflict',v['issues'])
    def test_malformed_fields_do_not_erase_valid_readings(self):
        c=candidate();c['rows'][0]['amount']='5.40T'
        a,v=s.canonical(c);self.assertIsNone(a['lines'][0]['amount']);self.assertEqual(a['lines'][0]['unitPrice'],270);self.assertTrue(v['invalid_fields'])
    def test_subcent_unit_price_is_retained_without_rounding(self):
        c=candidate();c['rows'][0]['unit_price']='2.705'
        a,v=s.canonical(c);self.assertIsNone(a['lines'][0]['unitPrice']);self.assertEqual(a['lines'][0]['unitPriceDecimal'],'2.705');self.assertTrue(v['invalid_fields'])
    def test_zero_product_is_still_a_purchase(self):
        c=candidate();c['rows'][0]['amount']='0.00';c['total']='0.00'
        a,v=s.canonical(c);self.assertEqual(len(a['lines']),1);self.assertEqual(a['lines'][0]['amount'],0)
        self.assertEqual(a['nonAccountingRows'],[])
    def test_absent_marker_stays_unknown(self):
        c=candidate();c['rows'][0]['tax_marker']=None
        a,v=s.canonical(c);self.assertIsNone(a['lines'][0]['taxMarker']);self.assertNotIn('taxable',a['lines'][0])
    def test_invalid_structure_is_rejected(self):
        c=candidate();del c['rows'][0]['tax_marker']
        with self.assertRaises(s.lab.LabError):s.canonical(c)
    def test_repeated_rows_are_not_merged(self):
        c=candidate();c['rows']*=2;c['total']='10.80'
        a,v=s.canonical(c);self.assertEqual(len(a['lines']),2);self.assertNotEqual(a['lines'][0]['id'],a['lines'][1]['id'])

if __name__=='__main__':unittest.main()
