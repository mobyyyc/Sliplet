import copy,unittest
import corrected_extract as c

def fixture():
    value={key:None for key in c.base.SCHEMA['properties']}
    value.update(merchant='FICTIONAL MARKET',total='12.50',rows=[])
    for name,amount in [('FIRST','8.75 A'),('SECOND','3.75')]:
        row={key:None for key in c.base.SCHEMA['properties']['rows']['items']['properties']}
        row.update(kind='purchase',description=name,amount=amount);value['rows'].append(row)
    return value

class Tests(unittest.TestCase):
    def test_preserve_valid_fields_without_guessing(self):
        value=fixture();original=copy.deepcopy(value)
        actual,validation=c.canonical(value)
        self.assertEqual(value,original)
        self.assertIsNone(actual['lines'][0]['amount'])
        self.assertEqual(actual['lines'][1]['amount'],375)
        self.assertEqual(actual['total'],1250)
        self.assertTrue(validation['review_required'])
        self.assertEqual(validation['invalid_fields'],['rows[0].amount'])

    def test_no_rounding_or_forced_reconciliation(self):
        value=fixture();value['rows'][0]['amount']='1.234'
        actual,validation=c.canonical(value)
        self.assertIsNone(actual['lines'][0]['amount'])
        self.assertEqual(actual['total'],1250)

    def test_valid_input_unchanged(self):
        value=fixture();value['rows'][0]['amount']='8.75'
        actual,validation=c.canonical(value)
        self.assertEqual(actual,c.base.canonical(value)[0])
        self.assertFalse(validation['invalid_fields'])

    def test_structure_failure_not_repaired(self):
        value=fixture();value['rows'][0]['kind']='unknown'
        with self.assertRaises(c.lab.LabError):c.canonical(value)

if __name__=='__main__':unittest.main()
