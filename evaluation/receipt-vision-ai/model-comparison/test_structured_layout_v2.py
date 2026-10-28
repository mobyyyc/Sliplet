import unittest
import structured_layout_v2 as layout
import test_structured_layout as fixtures


class ContinuationTests(unittest.TestCase):
    def fixture(self):
        return fixtures.LayoutTests().fixture()
    def test_basic_boundary_guards_still_apply(self):
        c=self.fixture();self.assertEqual(len(layout.recover(c)[1]),1)
        c['tax_legend']='ABC=local tax';self.assertEqual(layout.recover(c)[1],[])
        c=self.fixture();c['rows'][0]['raw_text']='83472 OAT DRINK 5.40 ABC';self.assertEqual(layout.recover(c)[1],[])
        c=self.fixture();c['rows'][0].update(tax_marker='T',raw_text='83472 OAT DRINK T 5.40');self.assertEqual(layout.recover(c)[1],[])
    def weighted(self):
        c=self.fixture();c['rows'][0].update(quantity='0.750',unit='kg',unit_price='4.00',amount='3.00',raw_text='83472 OAT DRINK ABC\n0.750 kg @ $4.00/kg 3.00');return c
    def test_explicit_continuation_preserves_name(self):
        c=self.weighted();a,v=layout.canonical(c)
        self.assertEqual(a['lines'][0]['description'],'83472 OAT DRINK ABC');self.assertEqual(a['lines'][0]['amount'],300)
        self.assertEqual(a['lines'][0]['unitPrice'],400);self.assertTrue(v['boundary_review'])
    def test_conflicting_measurements_are_not_repaired(self):
        for field,value in [('quantity','2'),('unit_price','4.50'),('amount','3.50'),('unit','lb')]:
            c=self.weighted();c['rows'][0][field]=value
            self.assertEqual(layout.recover(c)[1],[])
    def test_missing_extension_is_not_calculated(self):
        c=self.weighted();c['rows'][0]['raw_text']='83472 OAT DRINK ABC\n0.750 kg @ $4.00/kg'
        self.assertEqual(layout.recover(c)[1],[])
    def test_non_measurement_next_line_is_not_attached(self):
        c=self.weighted();c['rows'][0]['raw_text']='83472 OAT DRINK ABC\nANOTHER PRODUCT 3.00'
        self.assertEqual(layout.recover(c)[1],[])

if __name__=='__main__':unittest.main()
