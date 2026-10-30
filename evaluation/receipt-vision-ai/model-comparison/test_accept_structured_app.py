import unittest
from unittest.mock import patch
import accept_structured_app as runner

class Boundaries(unittest.TestCase):
    def test_failed_probe_prevents_real_upload(self):
        with patch.object(runner, 'freeze'), patch.object(runner, 'load', return_value={'passed': False}), patch.object(runner.keychain, 'read_key') as key:
            with self.assertRaisesRegex(RuntimeError, 'fictional_gate_required'): runner.next_call()
            key.assert_not_called()

    def test_failure_stops_without_reading_key(self):
        history=[{'slot':0,'time':0}]
        with patch.object(runner, 'freeze'), patch('pathlib.Path.exists', return_value=True), patch.object(runner, 'load', side_effect=[{'passed':True},history,{'status':'provider_error'}]), patch.object(runner.keychain, 'read_key') as key:
            self.assertEqual(runner.next_call()['status'],'stopped_after_failure')
            key.assert_not_called()

    def test_completed_five_never_resends(self):
        history=[{'slot':i,'time':0} for i in range(5)]
        with patch.object(runner, 'freeze'), patch('pathlib.Path.exists', return_value=True), patch.object(runner, 'load', side_effect=[{'passed':True},history]+[{'status':'received'}]*5), patch.object(runner.keychain, 'read_key') as key:
            self.assertEqual(runner.next_call()['status'],'complete')
            key.assert_not_called()

    def test_duplicate_inventory_rejected(self):
        with patch.object(runner, 'freeze'), patch('pathlib.Path.exists', return_value=True), patch.object(runner, 'load', side_effect=[{'passed':True},[{'slot':0},{'slot':0}]]), patch.object(runner.keychain, 'read_key') as key:
            with self.assertRaisesRegex(RuntimeError,'invalid_inventory'): runner.next_call()
            key.assert_not_called()

if __name__=='__main__': unittest.main()
