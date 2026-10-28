"""Post-run, review-required name-boundary recovery from literal transcription.

Never uses receipt labels, merchant names, specific suffixes or amounts to pair
rows. No change to the frozen model run. The original marker remains a proposal;
its tax meaning is unknown, not inferred from its position or absence of a legend.
"""
import copy
import re
import structured_extract as extraction


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
        if not re.search(pattern,raw):continue
        row['description']=name+' '+marker
        row['tax_marker']=None
        changes.append({'row':index,'reason':'literal_name_marker_amount_order_without_supporting_legend',
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
