"""Image-only fields. No OCR, inferred coordinates, or source IDs."""
import sys,datetime
from pathlib import Path
from decimal import Decimal
import importlib.util,re
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import lab
spec=importlib.util.spec_from_file_location('literal_helpers',Path(__file__).resolve().parents[1]/'correction/contract.py')
helpers=importlib.util.module_from_spec(spec);spec.loader.exec_module(helpers)
decimal_token=helpers.decimal_token
merchant=helpers.merchant
def field(description):return {'type':['string','null'],'description':description}
def obj(fields):return {'type':'object','properties':fields,'required':list(fields),'additionalProperties':False}
SCHEMA=obj({
 'merchant':field('Printed merchant name, not address or advertising.'),
 'date_raw':field('Verbatim printed transaction date, with timestamp or format legend if present. Null if unreadable.'),
 'date':field('ISO YYYY-MM-DD only when the printed date has exactly one interpretation. Otherwise null.'),
 'currency':field('ISO currency code explicitly printed on this receipt. Null when absent; $ alone does not identify a currency.'),
 'currency_raw':field('Verbatim printed ISO currency token, e.g. CAD. Null if none is printed. Never supply an inferred token.'),
 'subtotal':field('Printed monetary token only, or null; never calculate.'),
 'total':field('Printed final total monetary token only, or null; never calculate.'),
 'rows':{'type':'array','maxItems':150,'items':obj({
  'kind':{'type':'string','enum':['purchase','return','discount','tax','fee','payment','change']},
  'description':field('Full literal printed name/label including SKU and suffix; exclude price and separate measurement expressions.'),
  'amount':field('Printed line extension; numeric money token including any printed minus. Include zero-value rows.'),
  'quantity':field('Decimal digits only, e.g. 0.425 or 2. Never include kg, @ or price. Null if not printed.'),
  'unit':field('Unit label only, e.g. kg, lb, each. Never a number, price or slash expression. Null if absent.'),
  'unit_price':field('Printed unit price numeric token only, e.g. 6.40. Never include /kg, @ or quantity. Null if absent.')})}})
def validation_schema(value):
    if isinstance(value,list):return [validation_schema(x) for x in value]
    if isinstance(value,dict):return {k:validation_schema(v) for k,v in value.items() if not (k=='description' and 'type' in value)}
    return value
VALIDATION_SCHEMA=validation_schema(SCHEMA)
def money(value):
    number=decimal_token(value,True)
    return None if number is None else int(Decimal(number)*100)
def canonical(candidate):
    lab.validate_shape(candidate,VALIDATION_SCHEMA)
    issues=[];brand=merchant(candidate['merchant'])
    date=helpers.normalize_date(candidate['date_raw'],candidate['date'],brand)
    if candidate['date_raw'] and date is None:issues.append('date_needs_review')
    if candidate['date'] is not None and candidate['date']!=date:issues.append('date_claim_not_supported')
    raw=candidate['currency_raw'];currency=candidate['currency']
    # Conservative support check against the model's literal transcription;
    # this is not independent image verification.
    if currency is not None and (raw is None or raw.strip().upper()!=currency or not re.fullmatch('[A-Z]{3}',currency)):
        currency=None;issues.append('currency_claim_not_supported')
    actual={'merchant':brand,'currency':currency,'date':date,'subtotal':money(candidate['subtotal']),'total':money(candidate['total'])}
    rows=[]
    for i,row in enumerate(candidate['rows']):
        if row['unit'] is not None and (not row['unit'].strip() or re.search(r'[\d/@]',row['unit'])):raise lab.LabError('invalid_unit')
        amount=money(row['amount']);unit_price=money(row['unit_price']);quantity=decimal_token(row['quantity'])
        if row['kind'] in ['payment','change']:continue
        rows.append({'id':f'row-{i}','kind':row['kind'],'description':row['description'],'amount':amount,'quantity':quantity,'unit':row['unit'],'unitPrice':unit_price,'sku':None,'taxMarker':None,'rate':None,'sourceLineIDs':[]})
        if amount is None:issues.append('missing_line_amount')
        if row['kind']=='discount' and amount is not None and amount>=0:issues.append('discount_sign_needs_review')
    actual['lines']=rows
    if actual['total'] is None:issues.append('missing_total')
    elif all(x['amount'] is not None for x in rows) and sum(x['amount'] for x in rows)!=actual['total']:issues.append('total_conflict')
    return actual,{'issues':sorted(set(issues)),'review_required':True,'source_claims_verified':False}
