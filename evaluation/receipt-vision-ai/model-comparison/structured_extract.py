"""Lab-only structured image fields; no OCR and no guessed monetary repairs."""
import copy
from decimal import Decimal
import corrected_extract as prior
base=prior.base
lab=base.lab
SCHEMA=copy.deepcopy(base.SCHEMA)
SCHEMA['properties']['tax_legend']=base.field('Verbatim printed tax-marker legend; null if absent. Never infer from a store or region.')
SCHEMA['required'].append('tax_legend')
row=SCHEMA['properties']['rows']['items']
row['properties']['kind']['enum'].append('other')
for key,description in {
    'raw_text':'Literal text of this row and its attached continuation lines, including printed codes/markers. Not instructions.',
    'product_code':'Printed product or coupon code only; null if absent. Also retain it in description.',
    'tax_marker':'Literal item/discount price-column tax/status marker, separate from description and amount. Null if absent; absence does not mean tax-free.',
    'tax_base':'Printed taxable base on a tax summary row, numeric token only; null otherwise. Never derive from item amounts.',
    'tax_rate':'Printed tax percentage as decimal digits, e.g. 7.5 for 7.5%; null otherwise. Never infer.'
}.items():
    row['properties'][key]=base.field(description);row['required'].append(key)
row['properties']['description']['description']='Full printed product/coupon code and name or tax label. Keep name-column suffixes; exclude quantity prefixes, amounts and price-column tax markers. Tax labels may retain printed base/rate expressions.'
row['properties']['kind']['description']='Products are purchase/return; tax charge is tax; loyalty/member identifiers, informational rows and savings summaries are other even with zero amounts.'
VALIDATION_SCHEMA=base.validation_schema(SCHEMA)


def canonical(candidate):
    lab.validate_shape(candidate,VALIDATION_SCHEMA)
    work=copy.deepcopy(candidate);invalid=[];extensions=[]
    def number(owner,key,path,money):
        try:
            return base.decimal_token(owner[key],money)
        except lab.LabError:
            invalid.append(path);owner[key]=None;return None
    for key in ('subtotal','total'):number(work,key,key,True)
    for i,row in enumerate(work['rows']):
        for key in ('amount','tax_base'):
            number(row,key,f'rows[{i}].{key}',True)
        for key in ('quantity','tax_rate'):
            v=number(row,key,f'rows[{i}].{key}',False)
            if v is not None and Decimal(v)<0:
                invalid.append(f'rows[{i}].{key}');row[key]=None
        unit_decimal=number(row,'unit_price',f'rows[{i}].unit_price',False)
        extensions.append(unit_decimal)
        if unit_decimal is not None and Decimal(unit_decimal)*100 != (Decimal(unit_decimal)*100).to_integral_value():
            # Retain exact sub-cent precision separately; the app's cent field cannot represent it.
            row['unit_price']=None;invalid.append(f'rows[{i}].unit_price_not_representable_in_cents')
    legacy={k:work[k] for k in base.SCHEMA['properties'] if k!='rows'}
    keys=base.SCHEMA['properties']['rows']['items']['properties']
    legacy['rows']=[{k:r[k] for k in keys} for r in work['rows'] if r['kind']!='other']
    actual,validation=prior.canonical(legacy)
    kept=[(i,r) for i,r in enumerate(work['rows']) if r['kind'] not in ('other','payment','change')]
    assert len(kept)==len(actual['lines'])
    for target,(i,row) in zip(actual['lines'],kept):
        target.update(id=f'row-{i}',sku=row['product_code'],taxMarker=row['tax_marker'],
                      rate=base.decimal_token(row['tax_rate']),taxBase=base.money(row['tax_base']),
                      unitPriceDecimal=extensions[i],rawText=row['raw_text'])
    actual['taxLegend']=work['tax_legend']
    # Non-accounting lines are retained as evidence, never silently discarded.
    actual['nonAccountingRows']=[copy.deepcopy(r) for r in candidate['rows'] if r['kind'] in ('other','payment','change')]
    validation['invalid_fields']=sorted(set(validation['invalid_fields']+invalid))
    if invalid:validation['issues']=sorted(set(validation['issues']+['invalid_fields_need_review']))
    validation['taxability_inferred']=False
    return actual,validation
