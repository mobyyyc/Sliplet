import copy
import unittest
import lab

def checked(value):return {'state':'printed_verified','value':value,'original_regions':[]}
def absent():return {'state':'not_printed_verified','original_regions':[]}
def fixture():
    expected={'merchant':'FICTIONAL','date':'2026-01-01','subtotal':300,'total':300,'lines':[
        {'kind':'purchase','description':'APPLE','amount':100}, {'kind':'purchase','description':'BREAD','amount':200}]}
    ref=lab.reference(expected);ref['fields']['currency']=checked('CAD');ref['all_summary_fields_verified']=True
    for line in ref['lines']:
        for k,f in line['fields'].items():
            if f['state']=='unreviewed':line['fields'][k]=absent()
    actual={**{k:v['value'] for k,v in ref['fields'].items()},'lines':copy.deepcopy(expected['lines'])}
    return actual,ref

class ProtocolTests(unittest.TestCase):
    def test_correct_requires_complete_reference(self):
        actual,ref=fixture();self.assertEqual(lab.score(actual,ref,[])['verdict'],'correct')
        ref['lines'][0]['fields']['unitPrice']={'state':'unreviewed','original_regions':[]}
        self.assertEqual(lab.score(actual,ref,[])['verdict'],'indeterminate')
    def test_canceling_wrong_amounts_fail_despite_total(self):
        actual,ref=fixture();actual['lines'][0]['amount']+=50;actual['lines'][1]['amount']-=50
        result=lab.score(actual,ref,[]);self.assertEqual(result['verdict'],'incorrect');self.assertEqual(result['counts']['wrong'],2)
    def test_missing_item_is_in_denominator(self):
        actual,ref=fixture();actual['lines'].pop()
        result=lab.score(actual,ref,[]);self.assertEqual(result['counts']['expected_purchases'],2);self.assertEqual(result['counts']['exact_purchase_pairs'],1)
        self.assertEqual(result['verdict'],'incorrect')
    def test_extra_line_is_not_perfect_receipt(self):
        actual,ref=fixture();actual['lines'].append({'kind':'purchase','description':'OTHER','amount':0})
        self.assertEqual(lab.score(actual,ref,[])['verdict'],'incorrect')
    def test_duplicate_pairing_does_not_use_amount(self):
        actual,ref=fixture();actual['lines'][1]['description']='APPLE';ref['lines'][1]['fields']['description']=checked('APPLE')
        actual['lines'][0]['amount'],actual['lines'][1]['amount']=actual['lines'][1]['amount'],actual['lines'][0]['amount']
        result=lab.score(actual,ref,[]);self.assertEqual(result['verdict'],'indeterminate');self.assertGreater(result['counts']['ambiguous_identity'],0)
    def test_duplicate_ambiguity_cannot_hide_unrelated_extra_or_missing_count(self):
        actual,ref=fixture();actual['lines'][1]['description']='APPLE';ref['lines'][1]['fields']['description']=checked('APPLE')
        actual['lines'].append({'kind':'purchase','description':'UNRELATED','amount':0})
        self.assertEqual(lab.score(actual,ref,[])['verdict'],'incorrect')
        actual['lines']=actual['lines'][:1]
        self.assertEqual(lab.score(actual,ref,[])['verdict'],'incorrect')
    def test_region_identity_needs_human_verification(self):
        actual,ref=fixture();ref['lines'][0]['original_regions']=[{'x':0,'y':0,'width':1,'height':1}]
        with self.assertRaises(ValueError):lab.score(actual,ref,[])
    def test_coverage_flags_must_be_boolean(self):
        actual,ref=fixture();ref['all_lines_verified']='false'
        with self.assertRaises(ValueError):lab.score(actual,ref,[])
    def test_original_regions_disambiguate_without_price(self):
        actual,ref=fixture();actual['lines'][1]['description']='APPLE';ref['lines'][1]['fields']['description']=checked('APPLE')
        observations=[];ref['source_regions_verified']=True
        for i,line in enumerate(ref['lines']):
            box={'x':0.1,'y':0.2+i*0.3,'width':0.8,'height':0.1};line['original_regions']=[box]
            actual['lines'][i]['sourceLineIDs']=[str(i)];observations.append({'id':str(i),'boundingBox':box})
        actual['lines'][0]['amount'],actual['lines'][1]['amount']=200,100
        self.assertEqual(lab.score(actual,ref,observations)['counts']['wrong'],2)
    def test_zero_absent_unreadable_and_unknown_are_distinct(self):
        self.assertEqual(lab.field_result(checked(0),0,'amount'),'correct')
        self.assertEqual(lab.field_result(checked(0),None,'amount'),'missing')
        self.assertEqual(lab.field_result(absent(),0,'amount'),'spurious')
        for state in ['unreviewed','unreadable']:
            self.assertEqual(lab.field_result({'state':state},0,'amount'),'unscorable')
    def test_reference_date_uses_legacy_checked_date_normalization(self):
        actual,ref=fixture();actual['date']='2026/01/01'
        self.assertEqual(lab.reference(actual)['fields']['date']['value'],'2026-01-01')
    def test_label_migration_does_not_fabricate_new_dimensions(self):
        actual,ref=fixture();migrated=lab.reference(actual)
        self.assertEqual(migrated['fields']['currency']['state'],'unreviewed')
        self.assertEqual(migrated['lines'][0]['fields']['quantity']['state'],'unreviewed')
        self.assertFalse(migrated['all_summary_fields_verified'])
    def test_invalid_minor_units_and_unverified_values_rejected(self):
        _,ref=fixture();ref['fields']['total']['value']=True
        with self.assertRaises(ValueError):lab.validate_reference(ref)
        _,ref=fixture();ref['fields']['total']={'state':'unreviewed','value':0}
        with self.assertRaises(ValueError):lab.validate_reference(ref)
    def test_printed_quantities_sku_rates_and_currency_are_scored(self):
        actual,ref=fixture();ref['fields']['currency']=checked('USD')
        for k,v in [('quantity','2'),('unitPrice',100),('sku','123'),('taxMarker','H')]:ref['lines'][0]['fields'][k]=checked(v)
        result=lab.score(actual,ref,[]);self.assertEqual(result['counts']['missing'],4);self.assertEqual(result['counts']['wrong'],1)
        self.assertEqual(lab.field_result(checked('0.13'),'0.05','rate'),'wrong')
    def test_swift_grouping_drives_interpretation_suspect(self):
        r={'parsed':{'lines':[]},'observations':[], 'groupedRows':[{'text':'APPLE 1.00'}], 'interpretedRows':[{'text':'APPLE 1.00'}]}
        expected={'lines':[{'kind':'purchase','description':'APPLE','amount':100}]}
        self.assertEqual(lab.stage_failures(r,expected)[0]['category'],'interpretation_or_description_match_suspect')
    def test_distant_amount_does_not_prove_association(self):
        r={'parsed':{'lines':[]},'groupedRows':[], 'interpretedRows':[], 'observations':[
            {'text':'APPLE','boundingBox':{'x':0,'y':0.8,'width':0.4,'height':0.02}},
            {'text':'TOTAL 1.00','boundingBox':{'x':0.8,'y':0.1,'width':0.1,'height':0.02}}]}
        expected={'lines':[{'kind':'purchase','description':'APPLE','amount':100}]}
        self.assertEqual(lab.stage_failures(r,expected)[0]['category'],'capture_ocr_or_reference_unresolved')
    def test_repeat_equivalence_retains_semantic_values(self):
        r={'observations':[{'id':'source-a','text':'FICTIONAL'}],'parsed':{'lines':[{'id':'line-a','quantity':{'coefficient':2,'scale':0},'sourceLineIDs':['source-a']}]},'fields':{'currency':'CAD'},'draftFields':{},'draft':{},'groupedRowIDs':[['source-a']],'interpretedRowIDs':[['source-a']]}
        b=copy.deepcopy(r);b['observations'][0]['id']='source-b';b['parsed']['lines'][0]['id']='line-b';b['parsed']['lines'][0]['sourceLineIDs']=['source-b'];b['groupedRowIDs']=[['source-b']];b['interpretedRowIDs']=[['source-b']]
        self.assertEqual(lab.stable(r),lab.stable(b))
        b['parsed']['lines'][0]['quantity']['coefficient']=3;self.assertNotEqual(lab.stable(r),lab.stable(b))
    def test_exposed_purchase_cannot_be_held_out(self):
        with self.assertRaises(ValueError):lab.legacy.validate_groups([{'purchase_id':'test','split':'held_out','previously_exposed':True,'store':'Costco','images':[{'sha256':'fake'}]}])

if __name__=='__main__':unittest.main()
