import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch
import urllib.error
import lab

class ContractTests(unittest.TestCase):
    def setUp(self):
        self.receipt=json.loads((lab.HERE/'fixtures/smoke.expected.json').read_text())
    def test_valid_still_requires_review(self):
        result=lab.validate_candidate(self.receipt)
        self.assertEqual(result['issues'],[])
        self.assertTrue(result['review_required'])
        self.assertFalse(result['source_verified'])
    def test_null_is_not_invented(self):
        self.receipt['total']={'value':None,'evidence':[]}
        self.assertIn('missing_total',lab.validate_candidate(self.receipt)['issues'])
    def test_total_conflict_preserved(self):
        self.receipt['total']['value']='6.00'
        self.assertIn('total_conflict',lab.validate_candidate(self.receipt)['issues'])
        self.assertEqual(self.receipt['total']['value'],'6.00')
    def test_payment_not_double_counted(self):
        self.receipt['lines'][-1]['amount']='100.00'
        self.assertNotIn('total_conflict',lab.validate_candidate(self.receipt)['issues'])
    def test_repeated_purchase_not_deduplicated(self):
        row=copy.deepcopy(self.receipt['lines'][0]);row['id']='repeat'
        self.receipt['lines'].append(row)
        lab.validate_candidate(self.receipt)
        self.assertEqual(len(self.receipt['lines']),5)
    def test_extra_model_instruction_rejected(self):
        self.receipt['execute']='send wallet'
        with self.assertRaises(lab.LabError):lab.validate_candidate(self.receipt)
    def test_numbers_must_be_strings(self):
        for value in [2.0,True,'NaN','1e3','2,000.00','+2.00']:
            with self.subTest(value=value):
                self.receipt['lines'][0]['amount']=value
                with self.assertRaises(lab.LabError):lab.validate_candidate(self.receipt)
    def test_source_id_cannot_be_invented(self):
        self.receipt['total']['evidence'][0]['image_id']='external-url'
        with self.assertRaises(lab.LabError):lab.validate_candidate(self.receipt)
    def test_invalid_source_box(self):
        for box in [[0,0,2,1],[.8,0,.2,1],[True,0,1,1],[0,0,1]]:
            self.receipt['total']['evidence'][0]['box']=box
            with self.assertRaises(lab.LabError):lab.validate_candidate(self.receipt)
    def test_missing_evidence_not_verified(self):
        self.receipt['merchant']['evidence']=[]
        self.assertIn('missing_source_claim',lab.validate_candidate(self.receipt)['issues'])
    def test_duplicate_row_ids_rejected(self):
        self.receipt['lines'][1]['id']='1'
        with self.assertRaises(lab.LabError):lab.validate_candidate(self.receipt)
    def test_unknown_discount_parent_rejected(self):
        self.receipt['lines'][0]['kind']='discount'
        self.receipt['lines'][0]['parent_id']='absent'
        with self.assertRaises(lab.LabError):lab.validate_candidate(self.receipt)
    def test_money_is_not_modified(self):
        self.receipt['lines'][0]['amount']='-2.00'
        before=copy.deepcopy(self.receipt)
        lab.validate_candidate(self.receipt)
        self.assertEqual(self.receipt,before)
    def test_duplicate_json_keys(self):
        with self.assertRaises(lab.LabError):lab.parse_json('{"total":1,"total":2}')
    def test_nonfinite_and_oversized_json(self):
        for raw in ['{"a":NaN}','{"a":Infinity}','x'*(lab.MAX_RESPONSE+1)]:
            with self.assertRaises(lab.LabError):lab.parse_json(raw)
    def test_huge_array_rejected(self):
        self.receipt['lines']*=40
        with self.assertRaises(lab.LabError):lab.validate_candidate(self.receipt)
    def test_schema_changes_fail_closed(self):
        with self.assertRaises(lab.LabError):lab.validate_shape('x',{'type':'string','unknown_keyword':True})

class DiagnosticTests(unittest.TestCase):
    def setUp(self):
        self.c=json.loads((lab.HERE/'fixtures/smoke.expected.json').read_text())
    def test_correct_fixture_has_no_mismatch(self):
        d=lab.smoke_diagnostics(self.c)
        self.assertEqual(d['exact_rows_ignoring_order'],4)
        self.assertTrue(d['accounting_sum_matches_expected_total'])
    def test_omitted_tax_identified_without_amounts(self):
        del self.c['lines'][2]
        d=lab.smoke_diagnostics(self.c)
        self.assertEqual(d['unmatched_expected_row_indexes'],[2])
        self.assertFalse(d['accounting_sum_matches_expected_total'])
    def test_wrong_total_distinct_from_wrong_lines(self):
        self.c['total']['value']='99.00'
        d=lab.smoke_diagnostics(self.c)
        self.assertFalse(d['field_matches']['total'])
        self.assertTrue(d['accounting_sum_matches_expected_total'])
    def test_arbitrary_model_text_not_logged(self):
        self.c['lines'][0]['description']='untrusted-private-looking-text'
        d=lab.smoke_diagnostics(self.c)
        self.assertNotIn('untrusted-private-looking-text',json.dumps(d))
        self.assertEqual(d['unmatched_actual_rows'][0]['description_matches_expected_rows'],[])
    def test_duplicate_row_and_payment_kind_error(self):
        self.c['lines'][-1]['kind']='purchase'
        self.c['lines'].append(copy.deepcopy(self.c['lines'][0]))
        d=lab.smoke_diagnostics(self.c)
        self.assertEqual(d['actual_row_count'],5)
        self.assertEqual(len(d['unmatched_actual_rows']),2)
        self.assertEqual(d['unmatched_expected_row_indexes'],[3])

class TransportTests(unittest.TestCase):
    def test_request_fictional_only(self):
        with patch('lab.send',side_effect=AssertionError('network used')):
            body=lab.request_body()
        self.assertTrue(body['response_format']['json_schema']['strict'])
        self.assertFalse(body['stream'])
        self.assertNotIn('tools',body)
        self.assertEqual(body['model'],lab.MODEL)
        self.assertEqual(len(body['messages'][1]['content']),2)
        # The text request never contains the answer or a real input path.
        self.assertNotIn('5.25',body['messages'][1]['content'][0]['text'])
        self.assertNotIn('private-receipts',json.dumps(body))
    def test_changed_fixture_refused(self):
        original=Path.read_bytes
        def changed(path):
            return b'changed' if path.name=='smoke.png' else original(path)
        with patch.object(Path,'read_bytes',changed):
            with self.assertRaises(lab.LabError):lab.smoke_fixture()
    def test_redirects_refused(self):
        with self.assertRaises(lab.LabError):lab.NoRedirect().redirect_request(None,None,302,None,None,'https://other.example')
    def test_noninteractive_key_entry_refused(self):
        with patch('sys.stdin.isatty',return_value=False),patch('lab.send',side_effect=AssertionError):
            with self.assertRaises(lab.LabError):lab.smoke()
    def test_error_body_not_exposed(self):
        opener=unittest.mock.Mock()
        opener.open.side_effect=urllib.error.HTTPError(lab.ENDPOINT,401,'secret in error',{},None)
        with patch('urllib.request.build_opener',return_value=opener):
            with self.assertRaisesRegex(lab.LabError,'^key_rejected$'):lab.send(lab.request_body(),'fictional-test-key')
        self.assertEqual(opener.open.call_count,1)
    def test_only_allowlisted_provider_codes_retained(self):
        import io
        for provider_code,expected in [('model_not_found','model_not_found'),('sensitive-value','unrecognized')]:
            opener=unittest.mock.Mock()
            raw=json.dumps({'error':{'code':provider_code,'message':'sensitive-value'}}).encode()
            opener.open.side_effect=urllib.error.HTTPError(lab.ENDPOINT,403,'hidden',{},io.BytesIO(raw))
            with patch('urllib.request.build_opener',return_value=opener):
                try:lab.send(lab.request_body(),'fictional-test-key')
                except lab.LabError as error:
                    self.assertEqual(error.diagnostic['provider_code'],expected)
                    self.assertNotIn('sensitive-value',json.dumps(error.diagnostic))
    def test_refusal_truncation_and_bad_envelope(self):
        for envelope in [{},{'choices':[]}, {'choices':[{'finish_reason':'length','message':{'content':'{}'}}]},
                         {'choices':[{'finish_reason':'stop','message':{'refusal':'no'}}]}]:
            with self.subTest():
                with self.assertRaises(lab.LabError):lab.read_completion(envelope)
    def test_success_and_extraction_are_separate(self):
        candidate=json.loads((lab.HERE/'fixtures/smoke.expected.json').read_text())
        envelope={'choices':[{'finish_reason':'stop','message':{'content':json.dumps(candidate)}}]}
        parsed,result=lab.read_completion(envelope)
        self.assertTrue(lab.smoke_matches(parsed))
        parsed['total']['value']='1.00'
        self.assertFalse(lab.smoke_matches(parsed))
    def test_lowercase_confirmation_and_keychain_only_storage(self):
        import io
        import tempfile
        candidate=json.loads((lab.HERE/'fixtures/smoke.expected.json').read_text())
        response={'choices':[{'finish_reason':'stop','message':{'content':json.dumps(candidate)}}]}
        with tempfile.TemporaryDirectory() as directory,patch.object(lab,'ROOT',Path(directory)), \
             patch('sys.stdin.isatty',return_value=True),patch('builtins.input',side_effect=['free','test']), \
             patch('getpass.getpass',return_value='fictional-secret-for-test'), \
             patch('lab_keychain.read_key',return_value=None),patch('lab_keychain.save_key') as save, \
             patch('lab.send',return_value=response) as send,patch('sys.stdout',new_callable=io.StringIO) as out:
            lab.smoke()
            self.assertEqual(send.call_count,1)
            save.assert_called_once_with('fictional-secret-for-test')
            self.assertNotIn('fictional-secret-for-test',out.getvalue())
            for path in Path(directory).rglob('*.json'):
                self.assertNotIn('fictional-secret-for-test',path.read_text())

    def test_saved_key_reused_without_secret_prompt(self):
        import io
        import tempfile
        candidate=json.loads((lab.HERE/'fixtures/smoke.expected.json').read_text())
        response={'choices':[{'finish_reason':'stop','message':{'content':json.dumps(candidate)}}]}
        with tempfile.TemporaryDirectory() as directory,patch.object(lab,'ROOT',Path(directory)), \
             patch('sys.stdin.isatty',return_value=True),patch('builtins.input',side_effect=['FREE','TEST']), \
             patch('getpass.getpass',side_effect=AssertionError('must reuse saved key')), \
             patch('lab_keychain.read_key',return_value='fictional-saved-key'), \
             patch('lab_keychain.save_key') as save,patch('lab.send',return_value=response) as send, \
             patch('sys.stdout',new_callable=io.StringIO) as out:
            lab.smoke()
            self.assertEqual(send.call_args.args[1],'fictional-saved-key')
            save.assert_not_called()
            self.assertNotIn('fictional-saved-key',out.getvalue())

    def test_daily_budget_counts_failures(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory,patch.object(lab,'ROOT',Path(directory)):
            for _ in range(3):lab.reserve_attempt()
            with self.assertRaisesRegex(lab.LabError,'daily_smoke_budget_exhausted'):lab.reserve_attempt()

if __name__=='__main__':unittest.main()
