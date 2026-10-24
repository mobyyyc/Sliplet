"""Fill omitted fields only from uniquely identified, literal supplied fragments.
No reference answers, price arithmetic, name/amount matching or default quantity.
"""
import copy,re
PRICE=re.compile(r'^(\(?-?\$?\d+(?:,\d{3})*\.\d{2}[-−]?\)?)(?:\s+[A-Z])?$')
MEASURE=re.compile(r'^(\d+(?:\.\d+)?)\s*(kg|g|lb|lbs|l|ml)?\s*@\s*\$?(\d+\.\d{2})(?:\s*/\s*(kg|g|lb|lbs|l|ml))?$',re.I)

def fill_omissions(candidate,anchors):
    result=copy.deepcopy(candidate);changes=[]
    for index,e in enumerate(result['entries']):
        if e['role'] in ('merchant','date','currency'):continue
        texts=[anchors[i]['text'].strip() for i in e['sources']]
        # Standalone price fragments only. A unit-price formula, product name,
        # identifier, or multiple distinct values cannot stand in for extension.
        prices={m.group(1) for text in texts if (m:=PRICE.fullmatch(text))}
        if e['amount'] is None and len(prices)==1:
            e['amount']=next(iter(prices));changes.append({'entry_index':index,'field':'amount','rule':'unique_selected_standalone_price'})
        if e['role'] not in ('purchase','return'):continue
        measurements={m.groups() for text in texts if (m:=MEASURE.fullmatch(text))}
        if len(measurements)==1:
            qty,unit,price,rate_unit=next(iter(measurements))
            if unit and rate_unit and unit.lower()!=rate_unit.lower():continue
            values={'quantity':qty,'unit':unit or rate_unit,'unit_price':price}
            for field,value in values.items():
                if e[field] is None and value is not None:
                    e[field]=value;changes.append({'entry_index':index,'field':field,'rule':'explicit_selected_measurement'})
        # Restore an omitted literal SKU only when the remaining name matches
        # exactly, ignoring casing/whitespace, in one selected source fragment.
        if e['text'] and not re.match(r'^\d',e['text']):
            norm=lambda t:' '.join(t.upper().split())
            codes={m.group(1) for text in texts if (m:=re.fullmatch(r'(\d{5,})\s+(.+)',text)) and norm(m.group(2))==norm(e['text'])}
            if len(codes)==1:
                e['text']=next(iter(codes))+' '+e['text'];changes.append({'entry_index':index,'field':'text','rule':'exact_selected_sku_prefix'})
    return result,changes

def printed_header_currency(candidate,anchors):
    result=copy.deepcopy(candidate)
    if any(e['role']=='currency' for e in result['entries']):return result,[]
    codes='CAD|USD|EUR|GBP|CNY|HKD|JPY|AUD|NZD|CHF'
    exact=re.compile(r'^(?:CURRENCY\s*:?\s*)?('+codes+r')$',re.I)
    dated=re.compile(r'^(?:20\d{2}[-/]\d{2}[-/]\d{2}|\d{1,2}/\d{1,2}/\d{2,4})\s+('+codes+r')$',re.I)
    found={}
    for e in result['entries']:
        if e['role'] not in ('date','merchant'):continue
        for index in e['sources']:
            text=anchors[index]['text'].strip();m=exact.fullmatch(text) or (dated.fullmatch(text) if e['role']=='date' else None)
            if m:found.setdefault(m.group(1).upper(),[]).append(index)
    if len(found)!=1:return result,[]
    code,indexes=next(iter(found.items()))
    result['entries'].append(dict(role='currency',text=code,amount=None,quantity=None,unit=None,unit_price=None,sources=sorted(set(indexes))))
    return result,[{'entry_index':len(result['entries'])-1,'field':'currency','rule':'explicit_selected_header_currency'}]
