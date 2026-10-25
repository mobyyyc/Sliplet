"""Image-only fields. No OCR, inferred coordinates, or source IDs."""
import sys,datetime
from pathlib import Path
from decimal import Decimal
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'correction'))
from contract import decimal_token,merchant
import lab
N={'type':['string','null']}
def obj(fields):return {'type':'object','properties':fields,'required':list(fields),'additionalProperties':False}
SCHEMA=obj({**{k:N for k in ['merchant','date','currency','subtotal','total']},'rows':{'type':'array','maxItems':150,'items':obj({'kind':{'type':'string','enum':['purchase','return','discount','tax','fee','payment','change']},**{k:N for k in ['description','amount','quantity','unit','unit_price']}})}})
def money(value):
    number=decimal_token(value,True)
    return None if number is None else int(Decimal(number)*100)
def canonical(candidate):
    lab.validate_shape(candidate,SCHEMA)
    issues=[];date=candidate['date']
    if date is not None:
        try:
            if datetime.date.fromisoformat(date).isoformat()!=date:raise ValueError()
        except ValueError:date=None;issues.append('invalid_date')
    actual={k:candidate[k] for k in ['merchant','currency']};actual['merchant']=merchant(actual['merchant']);actual.update(date=date,subtotal=money(candidate['subtotal']),total=money(candidate['total']))
    rows=[]
    for i,row in enumerate(candidate['rows']):
        amount=money(row['amount']);unit_price=money(row['unit_price']);quantity=decimal_token(row['quantity'])
        if row['kind'] in ['payment','change']:continue
        rows.append({'id':f'row-{i}','kind':row['kind'],'description':row['description'],'amount':amount,'quantity':quantity,'unit':row['unit'],'unitPrice':unit_price,'sku':None,'taxMarker':None,'rate':None,'sourceLineIDs':[]})
        if amount is None:issues.append('missing_line_amount')
        if row['kind']=='discount' and amount is not None and amount>=0:issues.append('discount_sign_needs_review')
    actual['lines']=rows
    if actual['total'] is None:issues.append('missing_total')
    elif all(x['amount'] is not None for x in rows) and sum(x['amount'] for x in rows)!=actual['total']:issues.append('total_conflict')
    return actual,{'issues':sorted(set(issues)),'review_required':True,'source_claims_verified':False}
