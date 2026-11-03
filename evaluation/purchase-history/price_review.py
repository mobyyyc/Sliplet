"""Prepare one offline price-reference review from the accepted pair inventory."""
import base64
import html
import json
import re
import sys
from decimal import Decimal
from pathlib import Path
import review

OUT = review.ROOT / "private-receipts/evaluation/p10-04-review"
EXPORT = review.ROOT / "sliplet-p1004-checked.json"


def build():
    data = review.proposal()
    accepted = json.loads((review.ROOT / "sliplet-p1002-checked.json").read_text())
    assert accepted["complete"] and accepted["inputHashes"] == data["inputHashes"]
    case = next(c for c in data["cases"] if c["id"] == "pair-2")
    OUT.mkdir(parents=True, exist_ok=True)
    cards = []
    for index, side in enumerate(case["sides"]):
        encoded = base64.b64encode((review.ROOT / side["image"]).read_bytes()).decode()
        cards.append(f'<section data-index="{index}"><h2>Receipt {side["slot"]+1}</h2>'
                     f'<p>{html.escape(side["line"]["description"])}<br>Model-read code · {html.escape(side["line"]["sku"])}</p>'
                     f'<img alt="Full original receipt" src="data:image/png;base64,{encoded}">'
                     '<label>Printed line amount <input data-key="amount" inputmode="decimal"></label>'
                     '<label>Quantity you can confirm <input data-key="quantity" inputmode="decimal"></label>'
                     '<label>Printed unit price, if shown <input data-key="unitPrice" inputmode="decimal"></label>'
                     '<label>Unit <select data-key="unit"><option value="">Unknown</option><option>each</option><option>kg</option><option>g</option><option>lb</option><option>oz</option><option>L</option><option>mL</option></select></label>'
                     '<label><input data-key="checked" type="checkbox"> I checked this row against the photo</label></section>')
    binding = json.dumps({"schemaVersion": 1, "reviewID": "sliplet-p1004", "inputHashes": data["inputHashes"],
                          "acceptedPairHash": review.digest(review.ROOT / "sliplet-p1002-checked.json"), "pairID": case["id"]})
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'">
<title>Sliplet · Unit price check</title><style>body{font:17px system-ui;max-width:1100px;margin:auto;padding:24px;background:#f5f5f7;color:#171717}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:24px}section{background:white;padding:20px;border-radius:22px}img{width:100%}
label{display:block;margin:18px 0}input,select,textarea,button{font:inherit;padding:10px;border:1px solid #aaa;border-radius:10px}
textarea{display:block;width:90%;min-height:70px}button{background:#171717;color:white;margin:20px 0}@media(max-width:650px){.pair{grid-template-columns:1fr}}</style>
<h1>Unit price check</h1><p>This is the pair you identified as different quantities at the same unit price.
Enter the exact values from each row so we can verify that Sliplet produces the same conclusion.
Leave uncertain or absent numbers blank. Enter a unit price only if it is printed; do not calculate it from the total.</p>
<p>This page is offline. Export your work before closing it.</p><div class="pair">''' + "".join(cards) + '''</div>
<label>Tax basis for both item rows <select id="tax"><option value="">Unknown</option><option value="beforeTax">Before separately added tax</option><option value="taxIncluded">Tax included in the row price</option></select></label>
<label>Are separately printed discounts or coupons associated with either item? <select id="discount"><option value="">Unknown</option><option value="yes">Yes</option><option value="no">No</option></select></label>
<label>Notes, including anything not printed or uncertain<textarea id="notes"></textarea></label>
<button id="export">Export checked work</button><p id="status" role="status"></p><script>
const binding=BINDING;
document.querySelector('#export').onclick=()=>{
const rows=[...document.querySelectorAll('section')].map(section=>{
const row={index:Number(section.dataset.index)};
for(const f of section.querySelectorAll('[data-key]'))row[f.dataset.key]=f.type==='checkbox'?f.checked:f.value.trim();
return row;});
const data={...binding,complete:rows.every(r=>r.checked),rows,taxBasis:document.querySelector('#tax').value,discount:document.querySelector('#discount').value,notes:document.querySelector('#notes').value};
const url=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)],{type:'application/json'}));
const a=document.createElement('a');a.href=url;a.download='sliplet-p1004-checked.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
document.querySelector('#status').textContent='Save sliplet-p1004-checked.json in the main Sliplet project folder.';};
</script></html>'''.replace("BINDING",binding)
    (OUT / "index.html").write_text(page)
    (OUT / "index.html").chmod(0o600)
    print("Prepared one private unit-price pair.")


def validate():
    data = json.loads(EXPORT.read_text())
    inventory = review.proposal()
    assert data["schemaVersion"] == 1 and data["reviewID"] == "sliplet-p1004"
    assert data["inputHashes"] == inventory["inputHashes"]
    assert data["acceptedPairHash"] == review.digest(review.ROOT / "sliplet-p1002-checked.json")
    assert data["pairID"] == "pair-2" and data["complete"] is True
    assert len(data["rows"]) == 2 and [r["index"] for r in data["rows"]] == [0, 1]
    assert data["taxBasis"] == "beforeTax" and data["discount"] == "no"
    rows = []
    for row in data["rows"]:
        assert row["checked"] is True and row["unit"] == "each"
        for key in ["amount", "quantity", "unitPrice"]:
            assert re.fullmatch(r"[0-9]+(?:\.[0-9]{1,9})?", row[key])
        amount, quantity, price = [Decimal(row[k]) for k in ["amount", "quantity", "unitPrice"]]
        assert amount > 0 and quantity > 0 and price > 0
        assert amount * 100 == (amount * 100).to_integral_value()
        assert price * 100 == (price * 100).to_integral_value()
        scale = max(0, -quantity.as_tuple().exponent)
        coefficient = int(quantity * 10**scale)
        assert scale <= 9 and max(int(amount * 100), int(price * 100), coefficient) <= 2**63-1
        # The owner's note explicitly identifies the single-quantity row's price
        # as its line amount, rather than a separately printed unit-price field.
        calculated = quantity == 1
        rows.append({"amount": int(amount * 100), "quantityCoefficient": coefficient,
                     "quantityScale": scale, "printedPrice": None if calculated else int(price * 100),
                     "basis": "calculated" if calculated else "printed"})
    assert sorted(Decimal(r["quantity"]) for r in data["rows"]) == [Decimal(1), Decimal(2)]
    OUT.mkdir(parents=True, exist_ok=True)
    accepted = OUT / "accepted-export.json"
    if accepted.exists():
        assert accepted.read_bytes() == EXPORT.read_bytes()
    else:
        accepted.write_bytes(EXPORT.read_bytes()); accepted.chmod(0o600)
    native = Path("/tmp/sliplet-p1004-native.json")
    native.write_text(json.dumps({"rows": rows, "exportHash": review.digest(EXPORT)}))
    native.chmod(0o600)
    print("Two checked rows validated. Native comparison input prepared using the visible CAD default.")


if __name__ == "__main__":
    if "--validate" in sys.argv:
        validate()
    else:
        build()
