"""Conservative lab-only field isolation; raw candidates remain immutable."""
import copy,re
import real_five as prior
base=prior.n.c.base.extract
lab=prior.n.c.base.lab

def canonical(candidate):
    lab.validate_shape(candidate,base.VALIDATION_SCHEMA)
    working=copy.deepcopy(candidate);invalid=[]
    def number(owner,key,path,money):
        try:base.decimal_token(owner[key],money)
        except lab.LabError:
            invalid.append(path);owner[key]=None
    for key in ['subtotal','total']:number(working,key,key,True)
    for index,row in enumerate(working['rows']):
        for key in ['amount','quantity','unit_price']:
            number(row,key,f'rows[{index}].{key}',key!='quantity')
        if row['unit'] is not None and (not row['unit'].strip() or re.search(r'[\d/@]',row['unit'])):
            invalid.append(f'rows[{index}].unit');row['unit']=None
    actual,validation=base.canonical(working)
    validation['invalid_fields']=invalid
    if invalid:
        validation['issues']=sorted(set(validation['issues']+['invalid_fields_need_review']))
    return actual,validation
