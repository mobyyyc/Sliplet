import copy,unittest
from unittest.mock import patch
import compare as c
class Tests(unittest.TestCase):
 def test_model_is_only_body_difference(self):
  image={'data':b'fictional bytes'};original=c.base.body(image);actual=c.body(image)
  expected=copy.deepcopy(original);expected['model']=c.MODEL
  self.assertEqual(actual,expected);self.assertEqual(original['model'],'qwen/qwen3.8-27b')
 def test_groq_transport_unchanged(self):
  self.assertEqual(c.base.lab.ENDPOINT,'https://api.groq.com/openai/v1/chat/completions')
  self.assertEqual(c.transport.ENDPOINT,'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions')
 def test_separate_keychain(self):
  self.assertEqual(c.credentials.keychain.SERVICE,'com.sliplet.development.gemini')
  self.assertEqual(c.base.lab.lab_keychain.SERVICE,'com.sliplet.development.groq')
 def test_real_budget_zero(self):self.assertEqual(c.old.MAX_CALLS['real'],0)
 def test_request_has_only_image_and_frozen_prompt(self):
  with patch.object(c.old,'raw_ocr',side_effect=AssertionError('OCR forbidden')):
   body=c.body({'data':b'fixture'})
  self.assertEqual(len(body['messages'][1]['content']),1)
  self.assertEqual(body['messages'][0]['content'],(c.base.HERE/'prompt.txt').read_text())
 def test_no_tools_or_fallback(self):
  b=c.body({'data':b'fixture'})
  self.assertNotIn('tools',b);self.assertFalse(b['stream']);self.assertEqual(b['max_completion_tokens'],3500)
 def test_recovery_only_initial_503(self):
  import recover
  self.assertTrue(recover.eligible({'status':'provider_error','diagnostic':{'http_status':503}}))
  for code in [400,401,403,429,500]:self.assertFalse(recover.eligible({'status':'provider_error','diagnostic':{'http_status':code}}))
  self.assertFalse(recover.eligible({'status':'network_or_timeout'}))
if __name__=='__main__':unittest.main()
