import io,unittest
from PIL import Image
import diagnose_resolution as d

class ResolutionTests(unittest.TestCase):
    def test_only_image_changes_in_pair(self):
        inputs=d.images()
        requests=[d.body(inputs[x]) for x in ['reduced','original']]
        for request in requests:request['contents'][0]['parts'].pop(0)
        self.assertEqual(requests[0],requests[1])
        self.assertEqual(d.n.TIMEOUT,60)
        with Image.open(io.BytesIO(inputs['reduced'])) as im:self.assertEqual(im.size,(640,608))
        with Image.open(io.BytesIO(inputs['original'])) as im:self.assertEqual(im.size,(1000,950))

    def test_extraction_requires_correct_reading(self):
        self.assertIsNone(d.select({'original':{'status':'received','merchant_correct':False}}))
        self.assertEqual(d.select({'reduced':{'merchant_correct':True}}),'reduced')
        self.assertEqual(d.select({'original':{'merchant_correct':True},'reduced':{'merchant_correct':True}}),'original')

    def test_no_server_schema_or_answers(self):
        request=d.body(b'fictional',True)
        self.assertNotIn('responseJsonSchema',request['generationConfig'])
        text=request['contents'][0]['parts'][1]['text']
        self.assertIn('"maxItems": 150',text)
        self.assertNotIn('FICTIONAL MARKET',text)
        self.assertNotIn('23.63',text)

if __name__=='__main__':unittest.main()
