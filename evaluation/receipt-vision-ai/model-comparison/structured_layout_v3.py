"""Separate explicitly transcribed department headings; keep all changes reviewable.

General section vocabulary, no merchant/receipt/product-specific substitutions.
Requires a standalone heading in BOTH multiline description and literal row text.
Never remove a same-line word, SKU, amount or quantity; never repair character errors.
"""
import copy
import re
import structured_layout_v2 as prior

DEPARTMENTS=frozenset(('BAKERY','DAIRY','DELI','FROZEN','GROCERY','GROCERIES','MEAT','PRODUCE','SEAFOOD'))

def separate(candidate):
    working=copy.deepcopy(candidate);changes=[]
    for index,row in enumerate(working['rows']):
        if row['kind']!='purchase':continue
        parts=(row.get('description') or '').splitlines()
        raw=row.get('raw_text') or ''
        if len(parts)!=2 or parts[0].strip()!=parts[0] or parts[0] not in DEPARTMENTS or not parts[1].strip():continue
        if not raw.startswith(parts[0]+'\n'+parts[1]):continue
        remainder=raw[len(parts[0])+1+len(parts[1]):]
        # Require an actual field boundary; do not truncate a longer product word.
        if remainder and not remainder[0].isspace():continue
        row['description']=parts[1]
        changes.append({'row':index,'heading':parts[0],'review_required':True})
    return working,changes

def canonical(candidate):
    prior.extraction.lab.validate_shape(candidate,prior.extraction.VALIDATION_SCHEMA)
    working,changes=separate(candidate)
    actual,validation=prior.canonical(working)
    by_id={row['id']:row for row in actual['lines']}
    for change in changes:
        by_id[f"row-{change['row']}"]['departmentHeading']=change['heading']
    validation['heading_review']=changes
    if changes:validation['issues']=sorted(set(validation['issues']+['department_heading_needs_review']))
    return actual,validation
