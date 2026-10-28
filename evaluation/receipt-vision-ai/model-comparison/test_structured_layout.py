import copy
import unittest
import structured_layout as layout
from test_structured_extract import candidate


class LayoutTests(unittest.TestCase):
    def fixture(self):
        c=candidate();c['tax_legend']=None;c['rows'][0].update(description='83472 OAT DRINK',tax_marker='ABC',raw_text='83472 OAT DRINK ABC 5.40')
        return c
    def test_literal_prefix_order_preserves_text_and_flags_review(self):
        c=self.fixture();before=copy.deepcopy(c);a,v=layout.canonical(c)
        self.assertEqual(a['lines'][0]['description'],'83472 OAT DRINK ABC')
        self.assertEqual(a['lines'][0]['amount'],540);self.assertIsNone(a['lines'][0]['taxMarker'])
        self.assertEqual(a['lines'][0]['proposedStatusMarker'],'ABC');self.assertTrue(v['boundary_review']);self.assertEqual(c,before)
    def test_marker_after_price_is_not_moved(self):
        c=self.fixture();c['rows'][0]['raw_text']='83472 OAT DRINK 5.40 ABC'
        self.assertEqual(layout.recover(c)[1],[])
    def test_explicit_legend_prevents_recovery(self):
        c=self.fixture();c['tax_legend']='ABC=local tax'
        self.assertEqual(layout.recover(c)[1],[])
    def test_single_letter_tax_marker_stays_separate(self):
        c=self.fixture();c['rows'][0].update(tax_marker='T',raw_text='83472 OAT DRINK T 5.40')
        self.assertEqual(layout.recover(c)[1],[])
    def test_no_cross_row_or_invented_text_recovery(self):
        for raw in ['83472 OAT DRINK\nABC 5.40','83472 OAT DRINK ABC 7.20','different product ABC 5.40']:
            c=self.fixture();c['rows'][0]['raw_text']=raw
            self.assertEqual(layout.recover(c)[1],[])
    def test_nonpurchase_rows_not_changed(self):
        c=self.fixture();c['rows'][0]['kind']='tax'
        self.assertEqual(layout.recover(c)[1],[])

if __name__=='__main__':unittest.main()
