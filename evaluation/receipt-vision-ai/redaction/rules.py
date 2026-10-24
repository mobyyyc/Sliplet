import re

sensitive=re.compile(r'\b(member(?:ship)?|loyalty|account|acct|auth(?:orization)?|approval|terminal|cashier|operator|transaction|trans\s*#|receipt\s*#|invoice|reference|trace|ref\s*#|aid|tvr|tsi)\b|\b(?:tel|phone|fax)\b|\b\d{3}[-. ()]+\d{3}[-. ]+\d{4}\b|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|\b[A-Z]\d[A-Z][ -]?\d[A-Z]\d\b|\b\d+\s+.*\b(?:STREET|ROAD|AVENUE|DRIVE|BLVD|LANE|HWY)\b',re.I)
card=re.compile(r'(?:\*|[xX]){3,}\s*\d{3,}|\b\d{12,19}\b')

def should_mask(text):
    return bool(sensitive.search(text) or (card.search(text) and re.search(r'card|visa|master|debit|credit|\*|[xX]{3}',text,re.I)))
