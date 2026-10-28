"""Post-run, review-required name-boundary recovery from literal transcription.

Never uses receipt labels, merchant names, specific suffixes or amounts to pair
rows. No change to the frozen model run. The original marker remains a proposal;
its tax meaning is unknown, not inferred from its position or absence of a legend.
"""
import copy
import re
import structured_extract as extraction


def continuation_matches(raw, head, row):
    """Require one explicit attached quantity/rate/extension line; no arithmetic."""
    number=r'\d+(?:\.\d{1,6})?'
    expression=(r'[ \t]*(?P<q>'+number+r')(?:[ \t]+(?P<u>[A-Za-z]+))?'
                r'[ \t]*@[ \t]*\$?(?P<p>'+number+r')'
                r'(?:/(?P<pu>[A-Za-z]+))?[ \t]+\$?(?P<a>'+number+r')[ \t]*(?:\n|$)')
    matches=list(re.finditer(head+r'[ \t]*\n'+expression,raw))
    if len(matches)!=1 or row.get('quantity') is None or row.get('unit_price') is None:return False
    from decimal import Decimal
    m=matches[0]
    try:
        for group,key in [('q','quantity'),('p','unit_price'),('a','amount')]:
            if Decimal(m[group])!=Decimal(extraction.base.decimal_token(row[key])):return False
    except (extraction.lab.LabError,ValueError):return False
    units=[u.lower() for u in (m['u'],m['pu']) if u]
    if units and (not row.get('unit') or any(u!=row['unit'].lower() for u in units)):return False
    return True


def recover(candidate):
    extraction.lab.validate_shape(candidate,extraction.VALIDATION_SCHEMA)
    working=copy.deepcopy(candidate);changes=[]
    legend=candidate.get('tax_legend') or ''
    for index,row in enumerate(working['rows']):
        if row['kind']!='purchase':continue
        marker=row.get('tax_marker');name=row.get('description');amount=row.get('amount');raw=row.get('raw_text')
        if not (marker and re.fullmatch('[A-Z]{2,6}',marker) and name and amount and raw):continue
        # An explicit legend is stronger evidence for a tax field than this
        # provisional layout rule. Never override a printed legend.
        if re.search(r'(?<!\w)'+re.escape(marker)+r'(?!\w)',legend):continue
        if name.split()[-1]==marker:continue
        description=r'[ \t]+'.join(re.escape(word) for word in name.split())
        pattern=r'(?:^|\n)[ \t]*(?:\(\d+(?:\.\d+)?\)[ \t]*)?'+description+r'[ \t]+'+re.escape(marker)+r'[ \t]+'+re.escape(amount)+r'[ \t]*(?:\n|$)'
        same_line=bool(re.search(pattern,raw))
        head=r'(?:^|\n)[ \t]*(?:\(\d+(?:\.\d+)?\)[ \t]*)?'+description+r'[ \t]+'+re.escape(marker)
        attached=continuation_matches(raw,head,row) if not same_line else False
        if not (same_line or attached):continue
        row['description']=name+' '+marker
        row['tax_marker']=None
        changes.append({'row':index,'reason':('literal_name_with_attached_measurement_without_supporting_legend' if attached else 'literal_name_marker_amount_order_without_supporting_legend'),
                        'proposed_marker':marker,'tax_meaning':'unknown','review_required':True})
    return working,changes


def canonical(candidate):
    working,changes=recover(candidate)
    actual,validation=extraction.canonical(working)
    by_id={row['id']:row for row in actual['lines']}
    for change in changes:
        row=by_id[f"row-{change['row']}"]
        row['proposedStatusMarker']=change['proposed_marker']
        row['descriptionBoundaryNeedsReview']=True
    validation['boundary_review']=changes
    if changes:validation['issues']=sorted(set(validation['issues']+['description_boundary_needs_review']))
    return actual,validation
