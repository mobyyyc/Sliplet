import unittest
import report_resolution as r

class WrapperTests(unittest.TestCase):
    def test_exact_wrapper_only(self):
        self.assertEqual(r.decode('```json\n{"a":1}\n```'),({'a':1},True))
        self.assertEqual(r.decode('{"a":1}'),({'a':1},False))

    def test_prose_and_multiple_blocks_rejected(self):
        for text in ['Here is JSON:\n```json\n{}\n```','```json\n{}\n```\n```json\n{}\n```']:
            with self.assertRaises(r.d.n.c.base.lab.LabError):r.decode(text)

    def test_invalid_json_not_repaired(self):
        for text in ['```json\n{"a":1,}\n```','```json\n{"a":1,"a":2}\n```']:
            with self.assertRaises(r.d.n.c.base.lab.LabError):r.decode(text)

if __name__=='__main__':unittest.main()
