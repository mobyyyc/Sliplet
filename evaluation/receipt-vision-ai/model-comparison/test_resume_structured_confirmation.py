import unittest
import resume_structured_confirmation as r


class ResumeTests(unittest.TestCase):
    def test_first_success_cannot_be_resent(self):
        self.assertEqual(r.select([],{}),(1,'ready'))
        with self.assertRaises(ValueError):r.select([{'name':'real-0-1'}],{})
    def test_no_automatic_retry_after_failed_or_interrupted_retry(self):
        calls=[{'name':'real-1-1'}]
        for results in ({},{'real-1-1':{'status':'provider_error'}}):self.assertIsNone(r.select(calls,results)[0])
    def test_four_complete_requests_stop(self):
        calls=[{'name':f'real-{i}-1'} for i in range(1,5)]
        results={c['name']:{'status':'received'} for c in calls}
        self.assertEqual(r.select(calls,results),(None,'complete'))
    def test_duplicate_and_out_of_scope_requests_rejected(self):
        for calls in ([{'name':'real-1-1'}]*2,[{'name':'real-5-1'}]):
            with self.assertRaises(ValueError):r.select(calls,{})

if __name__=='__main__':unittest.main()
