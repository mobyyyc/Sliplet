import unittest
from duplicate_groups import assess

def sample(amounts,actual_amounts):
    reference={'lines':[{'fields':{k:{'state':'printed_verified','value':v} for k,v in {'kind':'purchase','description':'FICTIONAL ITEM','amount':amount}.items()}} for amount in amounts]}
    actual={'lines':[{'kind':'purchase','description':'FICTIONAL ITEM','amount':amount} for amount in actual_amounts]}
    score={'counts':{'exact_purchase_pairs':0,'expected_purchases':len(amounts)},'line_results':[{'reference_line':i,'ambiguous_identity':True} for i in range(len(amounts))]}
    return assess(actual,reference,score,lambda s:(s or '').upper())

class Tests(unittest.TestCase):
    def test_identical_group_and_count(self):
        self.assertEqual(sample([250,250],[250,250])['core_correct_purchases_including_groups'],2)
    def test_missing_extra_wrong_are_not_credited(self):
        for values in [[250],[250,250,250],[250,260]]:
            self.assertEqual(sample([250,250],values)['confirmed_duplicate_group_purchases'],0)
    def test_different_amounts_do_not_resolve_identity(self):
        self.assertEqual(sample([250,260],[250,260])['confirmed_duplicate_group_purchases'],0)

if __name__=='__main__':unittest.main()
