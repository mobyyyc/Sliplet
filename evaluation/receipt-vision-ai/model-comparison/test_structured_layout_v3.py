import unittest
import copy
import structured_layout_v3 as v3
import test_structured_layout as fixtures

class HeadingTests(unittest.TestCase):
    def fixture(self):
        c=fixtures.LayoutTests().fixture();c['rows'][0].update(description='PRODUCE\n83472 FICTIONAL APPLES',raw_text='PRODUCE\n83472 FICTIONAL APPLES 5.40',tax_marker=None);return c
    def test_separates_literal_heading_without_mutating_evidence(self):
        c=self.fixture();before=copy.deepcopy(c);a,v=v3.canonical(c)
        self.assertEqual(a['lines'][0]['description'],'83472 FICTIONAL APPLES');self.assertEqual(c,before)
        self.assertEqual(a['lines'][0]['departmentHeading'],'PRODUCE');self.assertTrue(v['heading_review'])
    def test_requires_both_separate_lines_and_field_boundary(self):
        for desc,raw in [('PRODUCE 83472 FICTIONAL APPLES','PRODUCE 83472 FICTIONAL APPLES 5.40'),('PRODUCE\n83472 FICTIONAL APPLES','83472 FICTIONAL APPLES 5.40'),('PRODUCE\n83472 FICTIONAL APPLES','PRODUCE\n83472 FICTIONAL APPLESAUCE 5.40')]:
            c=self.fixture();c['rows'][0].update(description=desc,raw_text=raw);self.assertFalse(v3.separate(c)[1])
    def test_preserves_unknown_headings_nonpurchases_and_multiple_lines(self):
        for key,value in [('kind','discount'),('description','UNKNOWN\n83472 FICTIONAL APPLES'),('description','PRODUCE\n83472 FICTIONAL\nAPPLES')]:
            c=self.fixture();c['rows'][0][key]=value;self.assertFalse(v3.separate(c)[1])
