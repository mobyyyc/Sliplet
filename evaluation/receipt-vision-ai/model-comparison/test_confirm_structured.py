import unittest
import confirm_structured as c


class ConfirmationTests(unittest.TestCase):
    def test_stops_after_failed_or_interrupted_request(self):
        history=[{'name':'real-0-1'}]
        for results in ({},{'real-0-1':{'status':'rate_limited'}}):
            self.assertIsNone(c.choose_next(history,results)[0])
    def test_duplicate_or_sixth_request_rejected(self):
        for history in ([{'name':'real-0-1'}]*2,[{'name':'real-5-1'}]):
            with self.assertRaises(ValueError):c.choose_next(history,{})
    def test_completed_run_does_not_dispatch_again(self):
        history=[{'name':f'real-{i}-1'} for i in range(5)]
        results={r['name']:{'status':'received'} for r in history}
        self.assertEqual(c.choose_next(history,results),(None,'complete'))
    def test_only_next_unattempted_receipt_is_selected(self):
        self.assertEqual(c.choose_next([],{}),(0,'ready'))
        self.assertEqual(c.choose_next([{'name':'real-0-1'}],{'real-0-1':{'status':'received'}}),(1,'ready'))
    def test_acceptance_does_not_round_up_below_ninety_percent(self):
        value={'gemini':{'core':{'expected_purchases':66,'core_correct_purchases_including_groups':59},'adjustments':{'expected':9,'exact':8},'fields':{'total':{'correct':5},'date':{'correct':4}}}}
        self.assertFalse(c.acceptance(value)['purchase_target'])
        value['gemini']['core']['core_correct_purchases_including_groups']=60
        self.assertTrue(all(c.acceptance(value).values()))
        value['gemini']['fields']['total']['correct']=4
        self.assertFalse(c.acceptance(value)['all_totals_correct'])

if __name__=='__main__':unittest.main()
