"""P8-02B compact literal ledger with supplied OCR source anchors."""
import datetime,re,sys,unicodedata
from decimal import Decimal
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import lab
ROLES=['merchant','date','currency','subtotal','total','purchase','return','discount','tax','fee','payment','change','other']

def obj(properties):return {'type':'object','properties':properties,'required':list(properties),'additionalProperties':False}
def schema(count):
    if not 1<=count<=250:raise lab.LabError('ocr_anchor_count_out_of_bounds')
    nullable={'type':['string','null']}
    row=obj({'role':{'type':'string','enum':ROLES},'text':nullable,'amount':nullable,'quantity':nullable,'unit':nullable,'unit_price':nullable,'sources':{'type':'array','items':{'type':'number','enum':list(range(count))},'maxItems':12}})
    return obj({'image_id':{'type':'string','enum':['image-0']},'date_iso':nullable,'entries':{'type':'array','items':row,'maxItems':150}})

def decimal_token(value,money=False):
    if value is None:return None
    t=unicodedata.normalize('NFKC',value).strip().replace('−','-')
    # A printed sign is syntax, never inferred from the ledger total or row role.
    negative=False
    if re.fullmatch(r'\([\d,.]+\)',t):negative=True;t=t[1:-1]
    elif t.endswith('-'):negative=True;t=t[:-1].strip()
    elif t.startswith('-'):negative=True;t=t[1:].strip()
    if t.startswith('$'):t=t[1:]
    if not re.fullmatch(r'(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,6})?',t):raise lab.LabError('unreadable_printed_number')
    d=Decimal(t.replace(',',''))
    if money and d*100!=(d*100).to_integral_value():raise lab.LabError('fractional_cent')
    if negative:d=-d
    return format(d,'f')

def merchant(text):
    if text is None:return None
    t=' '.join(unicodedata.normalize('NFKC',text).upper().split())
    # Existing application's full-header brand policy, not labels from this experiment.
    if re.search(r'\b(COMPARE|WITH|THAN|SHOP|AT|VISIT|FROM|SAVE|SAVINGS|BAG|PRODUCT|THANK|RETURN|NOT|LIKE|NEAR|OPPOSITE|TO)\b',t):return text
    if re.fullmatch(r'COSTCO(?:\s+WHOLESALE)?[ ®™*]*',t):return 'COSTCO'
    if re.fullmatch(r"(?:(?:[A-Z]+(?:[ -][A-Z]+)*['’]S)\s+)?NO\s*FRILLS",t):return 'NOFRILLS'
    if re.fullmatch(r'T\s*&\s*T(?:\s+SUPERMARKET)?',t):return 'T&T SUPERMARKET'
    return text

def normalize_date(raw,proposed,brand):
    if not raw:return None
    iso=re.search(r'\b(20\d{2})[-/](\d{2})[-/](\d{2})\b',raw)
    options=set()
    if iso:options.add('-'.join(iso.groups()))
    else:
        short=re.search(r'\b(\d{1,2})/(\d{1,2})/((?:20)?\d{2})\b',raw)
        if short:
            a,b,c=map(int,short.groups())
            if brand=='NOFRILLS' and len(short.group(3))==2 and re.search(r'\b\d{1,2}:\d{2}|YY/MM/DD',raw):options.add(f'{2000+a:04}-{b:02}-{c:02}')
            else:
                year=c if c>=100 else 2000+c
                if a<=12:options.add(f'{year:04}-{a:02}-{b:02}')
                if b<=12:options.add(f'{year:04}-{b:02}-{a:02}')
        else:
            for fmt in ('%d-%b-%Y','%B %d, %Y','%b %d, %Y'):
                try:options.add(datetime.datetime.strptime(raw.strip(),fmt).date().isoformat())
                except ValueError:pass
    valid=set()
    for value in options:
        try:datetime.date.fromisoformat(value);valid.add(value)
        except ValueError:pass
    # Proposed normalized values cannot resolve ambiguous printed dates on their own.
    return next(iter(valid)) if len(valid)==1 else None

def literal_canonical(candidate,anchors):
    lab.validate_shape(candidate,schema(len(anchors)))
    for entry in candidate['entries']:
        if not entry['sources'] or any(type(i) is not int for i in entry['sources']):raise lab.LabError('missing_or_noninteger_source_anchor')
        if len(set(entry['sources']))!=len(entry['sources']):raise lab.LabError('duplicate_source_anchor')
    summaries={}
    lines=[];observations=[];issues=[]
    for i,a in enumerate(anchors):
        left,top,right,bottom=a['box']
        if not (0<=left<right<=1 and 0<=top<bottom<=1):raise lab.LabError('invalid_supplied_anchor')
        observations.append({'id':f'ocr-{i}','text':a['text'],'boundingBox':{'x':left,'y':1-bottom,'width':right-left,'height':bottom-top}})
    for index,e in enumerate(candidate['entries']):
        role=e['role'];text=e['text']
        if role in ['merchant','date','currency','subtotal','total']:
            if role in summaries:raise lab.LabError('duplicate_summary')
            summaries[role]=e;continue
        amount=decimal_token(e['amount'],True)
        quantity=decimal_token(e['quantity'])
        unit_price=decimal_token(e['unit_price'],True)
        # Negative alone does not prove a discount. Preserve role; reconciliation will flag conflicts.
        if role=='discount' and amount is not None and Decimal(amount)>=0:issues.append('discount_sign_needs_review')
        if role in ['purchase','return','discount','tax','fee'] and amount is None:issues.append('missing_line_amount')
        lines.append({'id':f'row-{index}','kind':role,'description':text,'amount':None if amount is None else int(Decimal(amount)*100),'quantity':quantity,'unit':e['unit'],'unitPrice':None if unit_price is None else int(Decimal(unit_price)*100),'sku':None,'taxMarker':None,'rate':None,'sourceLineIDs':[f'ocr-{i}' for i in e['sources']]})
    def summary_text(role):return summaries.get(role,{}).get('text')
    brand=merchant(summary_text('merchant'))
    actual={'merchant':brand,'date':normalize_date(summary_text('date'),candidate['date_iso'],brand),'currency':summary_text('currency'),'lines':[l for l in lines if l['kind'] not in ['payment','change']]}
    for role in ['subtotal','total']:
        raw=summaries.get(role,{}).get('amount');value=decimal_token(raw,True);actual[role]=None if value is None else int(Decimal(value)*100)
    if actual['total'] is None:issues.append('missing_total')
    elif all(l['amount'] is not None for l in actual['lines']) and sum(l['amount'] for l in actual['lines'])!=actual['total']:issues.append('total_conflict')
    if summary_text('date') and actual['date'] is None:issues.append('date_needs_review')
    return actual,observations,{'issues':sorted(set(issues)),'source_claims_verified':False,'review_required':True,'unscored_payment_change_rows':len(lines)-len(actual['lines'])}


def canonical(candidate,anchors):
    # Validate before indexing any untrusted source list. Normalization never
    # creates an OCR anchor or changes the retained model response.
    lab.validate_shape(candidate,schema(len(anchors)))
    for e in candidate['entries']:
        if not e['sources'] or any(type(i) is not int for i in e['sources']):raise lab.LabError('missing_or_noninteger_source_anchor')
    from grounding import fill_omissions,printed_header_currency
    from semantics import payment_roles
    normalized,a=fill_omissions(candidate,anchors)
    normalized,b=printed_header_currency(normalized,anchors)
    normalized,c=payment_roles(normalized,anchors)
    actual,observations,validation=literal_canonical(normalized,anchors)
    validation['source_grounded_corrections']=a+b+c
    return actual,observations,validation
