"""Read existing local evidence and print aggregate purchase-link coverage only."""
import hashlib
import itertools
import json
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "private-receipts/evaluation/p8-02e/reference-repair-01/final/reference-v4.json"
RESPONSES = ROOT / "private-receipts/evaluation/p8-07-echo-acceptance-01/responses"


def normalized(value):
    return " ".join(unicodedata.normalize("NFKC", value or "").casefold().split())


def cross_receipt_pairs(rows):
    return [(a, b) for a, b in itertools.combinations(rows, 2) if a[0] != b[0]]


def audit():
    references = json.loads(REFERENCE.read_text())["receipts"]
    checked = []
    for receipt in references:
        for line in receipt["lines"]:
            fields = line["fields"]
            if fields["kind"].get("value") == "purchase":
                checked.append((receipt["slot"], normalized(receipt["fields"]["merchant"].get("value")),
                                {key: value.get("value") for key, value in fields.items()}, fields))
    model = []
    paths = sorted(RESPONSES.glob("*.json"))
    for path in paths:
        actual = json.loads(path.read_text())["actual"]
        model.extend((path.name, normalized(actual["merchant"]), line)
                     for line in actual["lines"] if line["kind"] == "purchase")
    checked_pairs = [(a, b) for a, b in cross_receipt_pairs(checked)
                     if normalized(a[2]["description"]) == normalized(b[2]["description"])]
    code_pairs = [(a, b) for a, b in cross_receipt_pairs(model)
                  if a[1] == b[1] and a[2]["sku"] and a[2]["sku"] == b[2]["sku"]]
    return {
        "receipts": len(references),
        "held_out_receipts": 0,
        "checked_purchases": len(checked),
        "merchant_count": len({row[1] for row in checked}),
        "checked_exact_description_pairs": len(checked_pairs),
        "checked_same_merchant_description_pairs": sum(a[1] == b[1] for a, b in checked_pairs),
        "checked_field_coverage": {
            key: sum(row[3][key]["state"] == "printed_verified" for row in checked)
            for key in ["description", "amount", "sku", "quantity", "unit", "unitPrice"]
        },
        "model_purchases": len(model),
        "model_field_presence": {
            key: sum(row[2].get(key) is not None for row in model)
            for key in ["sku", "quantity", "unit", "unitPrice"]
        },
        "model_same_merchant_code_pairs": len(code_pairs),
        "model_code_pairs_with_matching_descriptions": sum(
            normalized(a[2]["description"]) == normalized(b[2]["description"]) for a, b in code_pairs),
        "model_code_pairs_with_both_quantities": sum(
            all(row[2]["quantity"] is not None for row in pair) for pair in code_pairs),
        "model_code_pairs_with_both_unit_prices": sum(
            all(row[2]["unitPrice"] is not None for row in pair) for pair in code_pairs),
        "input_sha256": [hashlib.sha256(path.read_bytes()).hexdigest() for path in [REFERENCE] + paths],
    }


if __name__ == "__main__":
    print(json.dumps(audit(), indent=2))
