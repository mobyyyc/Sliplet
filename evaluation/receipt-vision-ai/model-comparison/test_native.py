import unittest,json
import native as n
class Tests(unittest.TestCase):
 def test_exact_inputs(self):
  image={'data':b'fixture'};old=n.c.base.body(image);body=n.body(image)
  self.assertEqual(body['systemInstruction']['parts'][0]['text'],old['messages'][0]['content'])
  self.assertEqual(body['contents'][0]['parts'][0]['inlineData']['data'],old['messages'][1]['content'][0]['image_url']['url'].split(',',1)[1])
  self.assertEqual(body['generationConfig']['responseFormat']['text']['schema'],old['response_format']['json_schema']['schema'])
 def test_no_tools_or_unsupported_sampling(self):
  b=n.body({'data':b'fixture'});self.assertNotIn('tools',b);self.assertNotIn('temperature',b['generationConfig']);self.assertEqual(b['generationConfig']['thinkingConfig'],{'thinkingLevel':'low'})
 def test_incomplete_rejected(self):
  with self.assertRaises(n.c.base.lab.LabError):n.candidate({'candidates':[{'finishReason':'MAX_TOKENS','content':{'parts':[{'text':'{}'}]}}]})
 def test_thoughts_not_candidate(self):
  self.assertEqual(n.candidate({'candidates':[{'finishReason':'STOP','content':{'parts':[{'text':'ignored','thought':True},{'text':'{"a":1}'}]}}]}),{'a':1})
 def test_no_candidate_rejected(self):
  with self.assertRaises(n.c.base.lab.LabError):n.candidate({})
if __name__=='__main__':unittest.main()
