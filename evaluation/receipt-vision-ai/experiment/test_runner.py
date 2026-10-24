import copy,io,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from PIL import Image, ImageDraw, ImageFont
import runner as r
class SafetyTests(unittest.TestCase):
 def setUp(self):
  self.c=json.loads((r.lab.HERE/'fixtures/smoke.expected.json').read_text())
 def test_overlap_and_complete_tail(self):
  t=r.tiles(Image.new('RGB',(850,2015),'white'))
  self.assertEqual([x['rect'] for x in t],[[0,0,850,1600],[0,1440,850,2015]])
 def test_overlong_refused_not_truncated(self):
  with self.assertRaises(r.lab.LabError):r.tiles(Image.new('RGB',(100,7000),'white'))
 def test_scaled_image_has_no_metadata(self):
  im=Image.new('RGB',(2400,3200));im.info['Description']='secret'
  t=r.tiles(im);decoded=Image.open(io.BytesIO(t[0]['data']))
  self.assertEqual(decoded.size,(1200,1600));self.assertNotIn('Description',decoded.info)
 def test_unknown_source_refused(self):
  self.c['total']['evidence'][0]['image_id']='not-supplied'
  with self.assertRaises(r.lab.LabError):r.lab.validate_candidate(self.c,['image-0'])
 def test_multiple_images_source_supported(self):
  self.c['total']['evidence'][0]['image_id']='image-1'
  r.parse({'choices':[{'finish_reason':'stop','message':{'content':json.dumps(self.c)}}]},['image-0','image-1'])
 def test_partial_output_refused(self):
  with self.assertRaises(r.lab.LabError):r.parse({'choices':[{'finish_reason':'length','message':{'content':json.dumps(self.c)}}]},['image-0'])
 def test_no_reference_in_payload(self):
  payload=r.body_for(r.tiles(Image.new('RGB',(100,100))))
  self.assertEqual(set(payload),{'model','temperature','max_completion_tokens','stream','messages','response_format'})
  self.assertNotIn('reference',json.dumps(payload));self.assertNotIn('sha256',json.dumps(payload))
 def test_duplicate_and_budget_reservation(self):
  with tempfile.TemporaryDirectory() as d,patch.object(r,'OUT',Path(d)),patch.object(r,'INTERVAL',0),patch.object(r,'MAX_CALLS',{'fictional':1}):
   r.reserve('fictional','one','dummy')
   with self.assertRaises(r.lab.LabError):r.reserve('fictional','one','dummy')
   with self.assertRaises(r.lab.LabError):r.reserve('fictional','two','dummy')
 def test_two_reservations_remain_valid_json(self):
  with tempfile.TemporaryDirectory() as d,patch.object(r,'OUT',Path(d)),patch.object(r,'INTERVAL',0):
   r.reserve('fictional','one','dummy')
   r.reserve('fictional','two','dummy')
   r.reserve('fictional','three','dummy')
   self.assertEqual(len(r.load(Path(d)/'calls.json')),3)
 @unittest.skipUnless(Path('/tmp/sliplet-p802-ocr').exists(),'local Vision helper required')
 def test_ocr_hints_read_only_redacted_pixels(self):
  im=Image.new('RGB',(850,300),'white');draw=ImageDraw.Draw(im)
  font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf',32)
  draw.text((30,30),'FICTIONAL PRIVATE IDENTIFIER',font=font,fill='black')
  draw.text((30,160),'PEARS',font=font,fill='black')
  draw.rectangle((0,0,849,120),fill='black')
  with tempfile.TemporaryDirectory() as d,patch.object(r,'OUT',Path(d)):
   hints=r.raw_ocr(r.tiles(im))
  words=' '.join(o['text'] for image in hints for o in image['observations'])
  self.assertIn('PEARS',words);self.assertNotIn('PRIVATE',words);self.assertNotIn('IDENTIFIER',words)
 def test_approved_export_change_refused(self):
  real=r.load
  def tamper(path):
   data=real(path)
   if path.name=='approved-export-record.json':data['export_sha256']='wrong'
   return data
  with patch.object(r,'load',side_effect=tamper),self.assertRaises(r.lab.LabError):r.verified_real_images()
if __name__=='__main__':unittest.main()

class RateMetadataTests(unittest.TestCase):
 def test_only_numeric_quota_headers_are_retained(self):
  safe=r.lab.safe_rate_headers({'x-ratelimit-limit-tokens':'8000','retry-after':'2.5','x-ratelimit-reset-tokens':'1m2.5s','Authorization':'private','x-ratelimit-remaining-tokens':'secret text'})
  self.assertEqual(safe,{'retry-after':'2.5','x-ratelimit-limit-tokens':'8000','x-ratelimit-reset-tokens':'1m2.5s'})

class SafeErrorDiagnosticsTests(unittest.TestCase):
 def test_rate_error_never_retains_provider_message(self):
  import urllib.error
  from unittest.mock import Mock
  message='PRIVATE IDENTIFIER: tokens per minute (TPM): Limit 8000, Used 2000, Requested 9000.'
  error=urllib.error.HTTPError('https://api.groq.com/openai/v1/chat/completions',429,'rate',{},io.BytesIO(json.dumps({'error':{'code':'rate_limit_exceeded','message':message}}).encode()))
  opener=Mock();opener.open.side_effect=error
  with patch.object(r.lab.urllib.request,'build_opener',return_value=opener),self.assertRaises(r.lab.LabError) as caught:
   r.lab.send({},'fictional-test-key',{})
  diagnostic=caught.exception.diagnostic
  self.assertEqual(diagnostic['limit_scope'],'tokens_per_minute')
  self.assertEqual(diagnostic['requested_count'],9000)
  self.assertEqual(diagnostic['limit_count'],8000)
  self.assertNotIn('PRIVATE',json.dumps(diagnostic))
