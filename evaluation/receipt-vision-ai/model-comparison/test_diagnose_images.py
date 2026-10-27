import base64,io,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from PIL import Image
import diagnose_images as d

class ImageDiagnosticTests(unittest.TestCase):
    def test_paired_requests_differ_only_by_image(self):
        requests=d.requests()
        control=requests[0][1]
        for name,request in requests[1:]:
            part=request['contents'][0]['parts'].pop(0)
            self.assertEqual(request,control)
            self.assertEqual(part['inlineData']['mimeType'],'image/jpeg')
            with Image.open(io.BytesIO(base64.b64decode(part['inlineData']['data']))) as im:
                self.assertEqual(im.format,'JPEG')
                im.verify()
        self.assertNotIn('responseJsonSchema',control['generationConfig'])
        self.assertNotIn('systemInstruction',control)

    def test_failure_stops_before_images(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(d,'OUT',Path(directory)), patch.object(d.n.c,'preflight'), patch.object(d.n.c.old,'wait_spacing'), patch.object(d.n.c.credentials.keychain,'read_key',return_value='fixture-not-a-key'), patch.object(d.n,'send',side_effect=d.n.c.base.lab.LabError('provider_error',{'http_status':503})) as send:
                d.run()
                self.assertEqual(send.call_count,1)
                d.run()
                self.assertEqual(send.call_count,1)
                calls=d.n.c.load(Path(directory)/'calls.json')
                self.assertEqual(len(calls),1)

if __name__=='__main__':unittest.main()
