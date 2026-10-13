import copy
import unittest
import experiment as e

class ProtocolTests(unittest.TestCase):
    def response(self,lines):
        return {'parsed':{'lines':[{'kind':'purchase','description':d,'amount':a} for d,a in lines]}}
    def test_regression_counts_duplicate_multiplicity(self):
        ref={'lines':[{'kind':'purchase','description':'APPLES','amount':100}]*2}
        result=e.regressions(self.response([('APPLES',100)]*2),self.response([('APPLES',100)]),ref)
        self.assertEqual(result['lost_previously_exact_lines'],1)
    def test_new_wrong_amount_is_not_offset_by_correct_gain(self):
        ref={'lines':[{'kind':'purchase','description':'APPLE','amount':100},{'kind':'purchase','description':'BREAD','amount':200}]}
        result=e.regressions(self.response([('APPLE',100)]),self.response([('APPLE',150),('BREAD',200)]),ref)
        self.assertEqual(result['lost_previously_exact_lines'],1)
        self.assertEqual(result['new_unmatched_line_proxies'],1)
        self.assertEqual(result['gained_exact_lines'],1)
    def test_unknown_summary_does_not_become_loss(self):
        self.assertEqual(e.regressions(self.response([]),self.response([]),{'lines':[]})['lost_correct_summary_fields'],0)
    def test_semantics_preserve_source_membership(self):
        a={'observations':[{'id':'a','text':'ONE'},{'id':'b','text':'TWO'}],'parsed':{'lines':[{'id':'x','sourceLineIDs':['a']}]},'fields':{},'groupedRowIDs':[['a'],['b']],'interpretedRowIDs':[['a'],['b']]}
        b=copy.deepcopy(a);b['parsed']['lines'][0]['sourceLineIDs']=['b']
        self.assertNotEqual(e.semantic(a),e.semantic(b))
    def test_semantics_ignore_only_generated_ids(self):
        a={'observations':[{'id':'a','text':'ONE'}],'parsed':{'lines':[{'id':'x','sourceLineIDs':['a']}]},'fields':{},'groupedRowIDs':[['a']],'interpretedRowIDs':[['a']]}
        b={'observations':[{'id':'b','text':'ONE'}],'parsed':{'lines':[{'id':'y','sourceLineIDs':['b']}]},'fields':{},'groupedRowIDs':[['b']],'interpretedRowIDs':[['b']]}
        self.assertEqual(e.semantic(a),e.semantic(b))
if __name__=='__main__':unittest.main()
