import unittest
from unittest.mock import patch
import diagnose_schema_compatibility as d

class DiagnosticTests(unittest.TestCase):
    def test_success_ladder_finishes_before_cap(self):
        history=[]
        for expected in ['minimal_with_thinking','nullable','enum_rows','full_schema_text','full_schema_image']:
            self.assertEqual(d.choose(history),expected)
            history.append({'case':expected,'passed':True,'status':'received'})
        self.assertIsNone(d.choose(history))
    def test_400_diagnostics_are_distinct_and_bounded(self):
        history=[];seen=[]
        for _ in range(6):
            case=d.choose(history);self.assertIsNotNone(case);seen.append(case)
            history.append({'case':case,'passed':False,'status':'provider_error','http_status':400})
        self.assertEqual(len(set(seen)),6);self.assertIsNone(d.choose(history))
    def test_quota_auth_and_network_stop(self):
        for result in [{'status':'network_or_timeout'},{'status':'invalid_response'}]+[{'status':'provider_error','http_status':s} for s in [401,403,429,503]]:
            self.assertIsNone(d.choose([{'case':'minimal_with_thinking',**result}]))
    def test_control_has_no_schema_or_images(self):
        with patch.object(d,'load',return_value={}):
            for case in ['minimal_with_thinking','minimal_without_thinking','json_schema_minimal','response_format_minimal','json_only_control','plain_control']:
                body=d.request(case)
                self.assertEqual(len(body['contents'][0]['parts']),1)
                self.assertEqual(set(body['contents'][0]['parts'][0]),{'text'})
            self.assertEqual(d.request('plain_control')['generationConfig'],{'maxOutputTokens':512})
    def test_unknown_or_misread_fields_fail(self):
        def env(text):return {'candidates':[{'finishReason':'STOP','content':{'parts':[{'text':text}]}}]}
        self.assertTrue(d.check('minimal_with_thinking',env('{"merchant":"SLIPLET TEST"}')))
        self.assertFalse(d.check('minimal_with_thinking',env('{"merchant":"SLIPLET TEST","extra":1}')))
        self.assertFalse(d.check('minimal_with_thinking',env('{"merchant":"WRONG"}')))

if __name__=='__main__':unittest.main()
