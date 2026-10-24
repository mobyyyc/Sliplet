"""Literal, source-scoped role corrections. Never balance-based role/sign inference."""
import copy,re
PAYMENT=re.compile(r'^(?:CARD|CASH|DEBIT|CREDIT|VISA|MASTERCARD|MASTER\s*CARD|AMEX|INTERAC|TENDER)(?:\s+(?:PAID|PAYMENT))?$',re.I)
LABEL_WITH_AMOUNT=re.compile(r'^(?:CARD|CASH|DEBIT|CREDIT|VISA|MASTERCARD|MASTER\s*CARD|AMEX|INTERAC|TENDER)(?:\s+(?:PAID|PAYMENT))?(?:\s+\$?\d+(?:[.,]\d{2})[-−]?)?$',re.I)

def payment_roles(candidate,anchors):
    result=copy.deepcopy(candidate);corrections=[]
    totals=[e for e in candidate['entries'] if e['role']=='total' and e['sources']]
    if len(totals)!=1:return result,corrections
    total_bottom=max(anchors[i]['box'][3] for i in totals[0]['sources'])
    for n,entry in enumerate(result['entries']):
        if entry['role'] in ('merchant','date','currency','subtotal','total','payment','change'):continue
        if not PAYMENT.fullmatch((entry['text'] or '').strip()):continue
        sources=[anchors[i] for i in entry['sources']]
        if not sources or min(x['box'][1] for x in sources)<total_bottom-.004:continue
        if not any(LABEL_WITH_AMOUNT.fullmatch(x['text'].strip()) for x in sources):continue
        # Exact payment label and footer location are independent of the requested total/amount.
        corrections.append({'entry_index':n,'from_role':entry['role'],'to_role':'payment','rule':'printed_payment_label_below_total'})
        entry['role']='payment'
    return result,corrections
