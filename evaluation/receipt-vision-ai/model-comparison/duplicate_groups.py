"""Supplementary core-field correctness for indistinguishable duplicate groups."""
from collections import defaultdict

def assess(actual,reference,strict_score,norm):
    groups=defaultdict(list)
    for index,line in enumerate(reference['lines']):
        fields=line['fields']
        if any(fields[k]['state']!='printed_verified' for k in ['kind','description','amount']):continue
        if fields['kind']['value']!='purchase':continue
        groups[norm(fields['description']['value'])].append((index,fields['amount']['value']))
    ambiguous={x['reference_line'] for x in strict_score['line_results'] if x.get('ambiguous_identity')}
    confirmed=0;eligible=0;confirmed_groups=0
    for description,entries in groups.items():
        if len(entries)<2 or len({amount for _,amount in entries})!=1:continue
        eligible+=len(entries)
        # Supplement only rows excluded by the unchanged matcher.
        if not all(index in ambiguous for index,_ in entries):continue
        rows=[x for x in actual['lines'] if x.get('kind')=='purchase' and norm(x.get('description'))==description]
        if len(rows)==len(entries) and all(x.get('amount')==entries[0][1] for x in rows):
            confirmed+=len(entries);confirmed_groups+=1
    return {'strict_exact_purchase_pairs':strict_score['counts']['exact_purchase_pairs'],
            'eligible_indistinguishable_purchases':eligible,
            'confirmed_duplicate_group_purchases':confirmed,
            'confirmed_duplicate_groups':confirmed_groups,
            'core_correct_purchases_including_groups':strict_score['counts']['exact_purchase_pairs']+confirmed,
            'expected_purchases':strict_score['counts']['expected_purchases'],
            'individual_duplicate_source_identity_verified':False}
