import unittest
from rules import should_mask

class RedactionTests(unittest.TestCase):
    def test_purchase_measurements_are_preserved(self):
        for text in ['0.750 kg @ 4.00/kg', '2 @ 3.49', '1.25 lb @ $2.00 / lb', 'QUANTITY 2', 'UNIT PRICE 3.50', '1234567890123 GREEN TEA 4.00']:
            with self.subTest(text=text):self.assertFalse(should_mask(text))
    def test_private_identifiers_still_masked(self):
        for text in ['help@example.test', 'MEMBER 123456789', 'CARD **** 1234', 'Phone 416-555-0123', 'AUTH 123456']:
            with self.subTest(text=text):self.assertTrue(should_mask(text))

if __name__=='__main__':unittest.main()
