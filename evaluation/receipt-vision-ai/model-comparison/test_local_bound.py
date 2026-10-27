import copy
import unittest
import native36_bounded_local as adapter

class LocalBoundTests(unittest.TestCase):
    def test_only_provider_array_bound_removed(self):
        baseline = adapter.n.c.base.body({'data': b'fixture'})
        expected = copy.deepcopy(baseline['response_format']['json_schema']['schema'])
        expected['properties']['rows'].pop('maxItems')
        actual = adapter.body({'data': b'fixture'})
        self.assertEqual(actual['generationConfig']['responseJsonSchema'], expected)
        self.assertEqual(adapter.n.c.base.extract.SCHEMA['properties']['rows']['maxItems'], 150)
        self.assertEqual(actual['systemInstruction']['parts'][0]['text'], baseline['messages'][0]['content'])

    def test_local_validator_rejects_151_rows(self):
        extract = adapter.n.c.base.extract
        value = {key: None for key in extract.SCHEMA['properties']}
        row = {key: None for key in extract.SCHEMA['properties']['rows']['items']['properties']}
        row['kind'] = 'purchase'
        value['rows'] = [row] * 151
        with self.assertRaises(adapter.n.c.base.lab.LabError):
            extract.canonical(value)

if __name__ == '__main__':
    unittest.main()
