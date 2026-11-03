"""Build an offline three-pair review, or validate its human export. No network."""
import base64
import hashlib
import html
import itertools
import json
import sys
from pathlib import Path
from audit import ROOT, RESPONSES, REFERENCE, normalized

OUT = ROOT / "private-receipts/evaluation/p10-02-review"
EXPORT = ROOT / "sliplet-p1002-checked.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def proposal():
    rows = []
    hashes = {"reference": digest(REFERENCE)}
    for path in sorted(RESPONSES.glob("*.json")):
        slot = int(path.stem.split("-")[1])
        actual = json.loads(path.read_text())["actual"]
        photo = ROOT / f"private-receipts/evaluation/p8-01-redaction-review/receipt-{slot+1}-local.png"
        hashes[path.name] = digest(path)
        hashes[f"photo-{slot}"] = digest(photo)
        rows.extend({"slot": slot, "merchant": actual["merchant"], "line": line,
                     "image": str(photo.relative_to(ROOT))}
                    for line in actual["lines"] if line["kind"] == "purchase")
    pairs = []
    for a, b in itertools.combinations(rows, 2):
        if (a["slot"] != b["slot"] and normalized(a["merchant"]) == normalized(b["merchant"])
                and a["line"]["sku"] and a["line"]["sku"] == b["line"]["sku"]):
            pairs.append({"id": f"pair-{len(pairs)+1}", "sides": [a, b]})
    return {"schemaVersion": 1, "reviewID": "sliplet-p1002", "inputHashes": hashes, "cases": pairs}


def validate():
    expected = proposal()
    data = json.loads(EXPORT.read_text())
    assert data["reviewID"] == expected["reviewID"]
    assert data["schemaVersion"] == 1 and data["inputHashes"] == expected["inputHashes"]
    assert [c["id"] for c in data["cases"]] == [c["id"] for c in expected["cases"]]
    assert data["complete"] is True
    for case in data["cases"]:
        assert case["decision"] in ["same", "different", "uncertain"]
        assert case["pack"] in ["same", "different", "unknown"]
        assert case["code"] in ["both", "different", "unreadable"]
        assert case["checked"] is True and isinstance(case["notes"], str)
    print(json.dumps({"cases": len(data["cases"]), "complete": True,
                      "same": sum(c["decision"] == "same" for c in data["cases"]),
                      "different": sum(c["decision"] == "different" for c in data["cases"]),
                      "uncertain": sum(c["decision"] == "uncertain" for c in data["cases"])}))


def build():
    data = proposal()
    assert len(data["cases"]) == 3
    OUT.mkdir(parents=True, exist_ok=True)
    sections = []
    for case in data["cases"]:
        sides = []
        for side in case["sides"]:
            image = base64.b64encode((ROOT / side["image"]).read_bytes()).decode()
            line = side["line"]
            sides.append(f'<article><h3>Receipt {side["slot"]+1}</h3><p>{html.escape(side["merchant"])}</p>'
                         f'<p><strong>{html.escape(line["description"])}</strong><br>'
                         f'Model-read code · {html.escape(line["sku"])}</p>'
                         f'<a href="data:image/png;base64,{image}" target="_blank" rel="noopener">'
                         f'<img alt="Full original receipt {side["slot"]+1}" src="data:image/png;base64,{image}"></a></article>')
        sections.append(f'<section data-id="{case["id"]}"><h2>{case["id"].replace("-", " ").title()}</h2>'
                        f'<div class="pair">{"".join(sides)}</div>'
                        '<p>Compare the named row on both photos. Pinch or use browser zoom for small print.</p>'
                        '<label>Are these the same product? <select data-key="decision"><option value="">Choose</option>'
                        '<option value="same">Same product</option><option value="different">Different products</option>'
                        '<option value="uncertain">Uncertain</option></select></label>'
                        '<label>Pack size or product variant <select data-key="pack"><option value="">Choose</option>'
                        '<option value="same">Same, confirmed</option><option value="different">Different</option>'
                        '<option value="unknown">Not shown or uncertain</option></select></label>'
                        '<label>Is the displayed code printed on both rows? <select data-key="code"><option value="">Choose</option>'
                        '<option value="both">Yes, on both</option><option value="different">No, different or incorrect</option>'
                        '<option value="unreadable">Not printed or unreadable</option></select></label>'
                        '<label>Notes or corrected codes <textarea data-key="notes"></textarea></label>'
                        '<label><input data-key="checked" type="checkbox"> I checked both photos. Uncertain answers are allowed.</label></section>')
    binding = json.dumps({k: data[k] for k in ["schemaVersion", "reviewID", "inputHashes"]})
    page = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'">
<title>Sliplet · Repeat purchase check</title>
<style>body{font:17px system-ui;background:#f5f5f7;color:#171717;max-width:1120px;margin:auto;padding:28px}
section{background:white;padding:24px;border-radius:22px;margin:28px 0;box-shadow:0 8px 28px #0001}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:24px}article{min-width:0}img{width:100%;height:auto}
label{display:block;margin:18px 0}select,textarea,button{font:inherit;padding:12px;border:1px solid #aaa;border-radius:12px}
textarea{display:block;width:90%;min-height:60px}button{cursor:pointer;background:#171717;color:white;margin:10px 10px 10px 0}
@media(max-width:650px){.pair{grid-template-columns:1fr}body{padding:14px}}</style>
<h1>Repeat purchase check</h1><p>Three candidate pairs from your existing receipts. Check the product identity, pack size and printed code.
A matching description alone does not confirm matching products. Choose Uncertain when the photos do not establish it.</p>
<p>This page works offline. Export your answers before closing or refreshing it.</p>''' + "".join(sections) + '''
<button id="export">Export checked work</button><button id="progress">Export progress</button><p id="status" role="status"></p>
<script>
const binding = BINDING;
function save(requireComplete) {
 const cases = [...document.querySelectorAll('section')].map(section => {
  const item = {id:section.dataset.id};
  for(const field of section.querySelectorAll('[data-key]')) item[field.dataset.key] = field.type === 'checkbox' ? field.checked : field.value;
  return item;
 });
 const complete = cases.every(c => c.checked && c.decision && c.pack && c.code);
 if(requireComplete && !complete){document.querySelector('#status').textContent='Answer all three choices and check each pair, or export progress.';return;}
 const blob = new Blob([JSON.stringify({...binding,complete,cases},null,2)],{type:'application/json'});
 const url = URL.createObjectURL(blob), link = document.createElement('a');
 link.href=url;link.download='sliplet-p1002-checked.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 document.querySelector('#status').textContent='Save the export in the main Sliplet project folder.';
}
document.querySelector('#export').onclick=()=>save(true);
document.querySelector('#progress').onclick=()=>save(false);
</script></html>'''.replace("BINDING", binding)
    (OUT / "index.html").write_text(page)
    (OUT / "proposal.json").write_text(json.dumps(data, indent=2))
    for path in [OUT / "index.html", OUT / "proposal.json"]:
        path.chmod(0o600)
    print("Prepared 3 private review pairs.")


if __name__ == "__main__":
    if "--validate" in sys.argv:
        validate()
    else:
        build()
