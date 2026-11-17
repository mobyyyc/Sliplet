"use strict";

const stores = ["NOFRILLS", "COSTCO", "T&T", "lululemon"];
const productSets = [
    [["APPLES", 499], ["MILK", 579], ["BREAD", 349]],
    [["STRIP LOIN", 2799], ["YOGURT", 1299], ["COFFEE", 1899]],
    [["TOFU", 399], ["RICE", 1899], ["GREEN TEA", 799]],
    [["TRAINING SHIRT", 5800], ["SOCKS", 1800], ["SHOPPER", 0]]
];
const money = cents => "CAD " + (cents / 100).toFixed(2);
const shortDate = value => value
    ? new Intl.DateTimeFormat("en-CA", { month: "short", day: "numeric", timeZone: "UTC" }).format(new Date(value))
    : "Date unavailable";
const monthName = key => key === "unknown" ? "Date unavailable"
    : new Intl.DateTimeFormat("en-CA", { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(key + "-15T12:00:00Z"));
const escapeHTML = value => String(value).replace(/[&<>"']/g, char => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
}[char]));

function makeReceipts(count) {
    return Array.from({ length: count }, (_, index) => {
        const monthOffset = Math.floor(index / 10);
        const date = new Date(Date.UTC(2026, 10 - monthOffset, 27 - index % 10 * 2, 12));
        const lines = productSets[index % stores.length].map(([name, price], item) => ({
            name, amount: price + (price ? (index % 7) * 17 + item * 3 : 0)
        }));
        const subtotal = lines.reduce((sum, line) => sum + line.amount, 0);
        const missingDate = count > 50 && index === count - 3;
        return Object.freeze({
            id: "receipt-" + index, merchant: stores[index % stores.length],
            date: missingDate ? null : date.toISOString(),
            month: missingDate ? "unknown" : date.toISOString().slice(0, 7),
            lines, subtotal, tax: 0, total: subtotal,
            starred: index % 11 === 0, archived: false,
            code: "SL" + String(10000 + index)
        });
    });
}

class ReceiptStudy {
    constructor(id) {
        this.root = document.getElementById(id);
        this.variant = id;
        this.view = "wallet";
        this.collection = "All receipts";
        this.query = "";
        this.largeText = false;
        this.reducedMotion = false;
        this.rows = [];
        this.positions = [];
        this.renderRange = "";
        this.anchorID = null;
        this.revision = 0;
        this.metrics = { layoutMs: [], paintMs: [], maxReceiptNodes: 0, scrollEvents: 0 };
        this.root.innerHTML = `
            <div class="status"><span>9:41</span><div class="island" aria-hidden="true"></div><span class="status-right">◒ ▰</span></div>
            <div class="app-header">
                <div class="nav-line"><h3>Receipts</h3><div class="nav-actions">
                    <button class="icon-button glass search-action" aria-label="Search receipts"><span class="symbol search"></span></button>
                    <button class="icon-button glass overview-action" aria-label="Purchase overview"><span class="symbol chart"></span></button>
                    <button class="icon-button glass view-toggle" aria-label="Switch to List"><span class="view-glyph" aria-hidden="true">☷</span></button>
                </div></div>
                <div class="browse-line">
                    <select class="collection" aria-label="Receipt collection"><option>All receipts</option><option>Starred</option><option>Archive</option></select>
                    <button class="month-jump" aria-label="Jump to month">November 2026 ⌄</button>
                </div>
                <div class="search-box" hidden><input aria-label="Search merchant, item or code" placeholder="Merchant, item or code"><button aria-label="Close search">×</button></div>
            </div>
            <div class="workspace"><div class="scroller" tabindex="0" aria-label="Receipts"><div class="scroll-content"></div></div></div>
            <div class="pocket-back" aria-hidden="true"></div>
            <div class="pocket-front" aria-hidden="true"><strong>Wallet</strong><p class="pocket-count"></p><span class="pocket-month"></span></div>
            <div class="bottom-chrome"><button class="import-button" aria-label="Import receipt">+</button><div class="home-indicator" aria-hidden="true"></div></div>`;
        this.scroller = this.root.querySelector(".scroller");
        this.content = this.root.querySelector(".scroll-content");
        this.scroller.addEventListener("scroll", () => {
            this.metrics.scrollEvents += 1;
            if (this.scrollFrame) return;
            this.scrollFrame = requestAnimationFrame(() => {
                this.scrollFrame = null;
                this.paint();
            });
        }, { passive: true });
        this.root.querySelector(".view-toggle").addEventListener("click", () => this.setView(this.view === "wallet" ? "list" : "wallet"));
        this.root.querySelector(".collection").addEventListener("change", event => {
            this.collection = event.target.value;
            this.rebuild(null);
        });
        this.root.querySelector(".month-jump").addEventListener("click", () => this.showMonths());
        this.root.querySelector(".search-action").addEventListener("click", () => this.setSearch(true));
        this.root.querySelector(".search-box button").addEventListener("click", () => this.setSearch(false));
        this.root.querySelector(".search-box input").addEventListener("input", event => {
            this.query = event.target.value.trim().toLocaleLowerCase();
            this.rebuild(null);
        });
        this.root.querySelector(".import-button").addEventListener("click", () => this.showImport());
        this.root.querySelector(".overview-action").addEventListener("click", () => this.showOverview());
        this.content.addEventListener("click", event => {
            const button = event.target.closest("[data-receipt]");
            if (button) this.openReceipt(button.dataset.receipt);
        });
    }

    setData(count) {
        this.metrics = { layoutMs: [], paintMs: [], maxReceiptNodes: 0, scrollEvents: 0 };
        this.receipts = makeReceipts(count);
        this.byID = new Map(this.receipts.map(receipt => [receipt.id, receipt]));
        this.archives = this.receipts.slice(0, Math.max(1, Math.floor(count / 20))).map(receipt =>
            Object.freeze({ ...receipt, id: "archived-" + receipt.id, archived: true }));
        this.archives.forEach(receipt => this.byID.set(receipt.id, receipt));
        this.closeLayer();
        this.rebuild(null);
    }

    filteredReceipts() {
        const source = this.collection === "Archive" ? this.archives : this.receipts;
        return source.filter(receipt => {
            if (this.collection === "Starred" && !receipt.starred) return false;
            if (!this.query) return true;
            return [receipt.merchant, receipt.code, ...receipt.lines.map(line => line.name)]
                .some(value => value.toLocaleLowerCase().includes(this.query));
        });
    }

    setView(view) {
        if (view === this.view) return;
        const anchor = this.anchorID;
        this.view = view;
        this.root.classList.toggle("list-mode", view === "list");
        this.root.querySelector(".view-toggle").setAttribute("aria-label", view === "wallet" ? "Switch to List" : "Switch to Wallet");
        this.root.querySelector(".view-glyph").textContent = view === "wallet" ? "☷" : "▱";
        this.rebuild(anchor);
    }

    rebuild(anchor) {
        const start = performance.now();
        const receipts = this.filteredReceipts();
        const ascending = this.view === "wallet";
        receipts.sort((a, b) => {
            if (!a.date) return b.date ? 1 : a.id.localeCompare(b.id);
            if (!b.date) return -1;
            return ascending ? a.date.localeCompare(b.date) : b.date.localeCompare(a.date);
        });
        const groups = new Map();
        for (const receipt of receipts) {
            if (!groups.has(receipt.month)) groups.set(receipt.month, []);
            groups.get(receipt.month).push(receipt);
        }
        this.groups = groups;
        const newestDatedID = receipts.findLast(receipt => receipt.date)?.id;
        this.rows = [];
        this.positions = [];
        this.monthOffsets = new Map();
        let y = 0;
        for (const [key, members] of groups) {
            this.monthOffsets.set(key, y);
            if (this.view === "list" || this.variant === "sections" || this.largeText) {
                this.positions.push(y);
                this.rows.push({ type: "month", key, count: members.length, y, height: 52 });
                y += 52;
            }
            members.forEach((receipt, index) => {
                const last = index === members.length - 1;
                const height = this.view === "list" ? (this.largeText ? 114 : 90)
                    : this.largeText ? 230 : ((this.variant === "sections" && last) || receipt.id === newestDatedID ? 222 : 110);
                this.positions.push(y);
                this.rows.push({ type: "receipt", receipt, y, height });
                y += height;
            });
        }
        this.totalHeight = y + (this.view === "wallet" ? 80 : 24);
        this.content.style.height = Math.max(this.scroller.clientHeight, this.totalHeight) + "px";
        this.root.querySelector(".pocket-count").textContent = receipts.length + " receipts";
        this.root.querySelector(".pocket-front strong").textContent =
            this.collection === "All receipts" ? "Wallet" : this.collection;
        this.root.querySelector(".scroller").setAttribute("aria-label", this.collection + ", " + receipts.length + " receipts");
        this.revision += 1;
        const target = anchor && this.rows.find(row => row.type === "receipt" && row.receipt.id === anchor);
        const lastDated = this.rows.findLast(row => row.type === "receipt" && row.receipt.date);
        const latestPosition = lastDated
            ? lastDated.y + lastDated.height + 80 - this.scroller.clientHeight : this.totalHeight;
        this.scroller.scrollTop = target ? target.y : this.view === "wallet" ? Math.max(0, latestPosition) : 0;
        this.paint();
        this.metrics.layoutMs.push(performance.now() - start);
    }

    lowerBound(y) {
        let low = 0;
        let high = this.positions.length;
        while (low < high) {
            const mid = (low + high) >>> 1;
            if (this.positions[mid] < y) low = mid + 1;
            else high = mid;
        }
        return Math.max(0, low - 1);
    }

    paint() {
        const start = performance.now();
        const top = this.scroller.scrollTop;
        const first = this.lowerBound(Math.max(0, top - 230));
        const last = Math.min(this.rows.length, this.lowerBound(top + this.scroller.clientHeight + 240) + 2);
        const key = this.revision + ":" + first + ":" + last;
        const visible = this.rows.slice(first, last);
        const anchor = this.rows.slice(this.lowerBound(top), last).find(row =>
            row.type === "receipt" && row.y + Math.min(row.height, 90) > top + 1);
        if (anchor) this.updateContext(anchor.receipt);
        if (key !== this.renderRange) {
            this.renderRange = key;
            this.content.innerHTML = visible.length
                ? visible.map((row, index) => this.renderRow(row, first + index)).join("")
                : '<div class="empty"><strong>No receipts here</strong>Try another collection or search.</div>';
            this.metrics.maxReceiptNodes = Math.max(this.metrics.maxReceiptNodes,
                this.content.querySelectorAll("[data-receipt]").length);
        }
        this.metrics.paintMs.push(performance.now() - start);
    }

    updateContext(receipt) {
        this.anchorID = receipt.id;
        this.root.querySelector(".month-jump").textContent = monthName(receipt.month) + " ⌄";
        this.root.querySelector(".pocket-month").textContent = this.view === "wallet"
            ? (receipt.month === "unknown" ? "Undated" : monthName(receipt.month).split(" ")[0]) : "";
    }

    renderRow(row, index) {
        if (row.type === "month") {
            return `<div class="month-slot" style="top:${row.y}px;height:${row.height}px"><strong>${monthName(row.key)}</strong><span>${row.count} receipts</span></div>`;
        }
        const receipt = row.receipt;
        const check = receipt.archived ? "Archived" : receipt.starred ? "★" : "✓";
        if (this.view === "list") {
            return `<div class="receipt-slot" style="top:${row.y}px"><button class="list-card" data-receipt="${receipt.id}" aria-label="${receipt.merchant}, ${shortDate(receipt.date)}, ${money(receipt.total)}">
                <span><strong>${receipt.merchant}</strong><small>${shortDate(receipt.date)} · ${receipt.lines.length} items ${receipt.archived ? "· Archived" : ""}</small></span>
                <span class="list-price">${money(receipt.total)}<span aria-hidden="true">›</span></span>
            </button></div>`;
        }
        const tilt = this.largeText || this.reducedMotion ? 0 : (index % 3 - 1) * .45;
        return `<div class="receipt-slot" style="top:${row.y}px;z-index:${index + 1}"><button class="receipt-card" data-receipt="${receipt.id}" style="transform:rotate(${tilt}deg)" aria-label="${receipt.merchant}, ${shortDate(receipt.date)}, ${money(receipt.total)}">
            <span class="card-top"><strong>${receipt.merchant}</strong><span class="review-mark" aria-hidden="true">${check}</span></span>
            <span class="card-meta"><span>${shortDate(receipt.date)}</span><b>${money(receipt.total)}</b></span>
            <span class="card-excerpt">${receipt.lines.slice(0, 3).map(line => `<span class="excerpt-row"><span>${line.name}</span><span>${(line.amount / 100).toFixed(2)}</span></span>`).join("")}</span>
        </button></div>`;
    }

    setSearch(open) {
        const anchor = this.anchorID;
        const box = this.root.querySelector(".search-box");
        box.hidden = !open;
        this.root.classList.toggle("searching", open);
        if (open) {
            this.setView("list");
            box.querySelector("input").focus();
        } else {
            this.query = "";
            box.querySelector("input").value = "";
            this.rebuild(anchor);
        }
        this.paint();
    }

    layer(html, label) {
        const opener = document.activeElement;
        this.closeLayer();
        this.layerOpener = opener;
        const layer = document.createElement("div");
        layer.className = "dialog-layer";
        layer.setAttribute("role", "dialog");
        layer.setAttribute("aria-modal", "true");
        layer.setAttribute("aria-label", label);
        layer.innerHTML = html;
        this.root.append(layer);
        this.root.querySelector(".app-header").setAttribute("inert", "");
        this.root.querySelector(".workspace").setAttribute("inert", "");
        this.root.querySelector(".bottom-chrome").setAttribute("inert", "");
        layer.addEventListener("click", event => {
            if (event.target === layer || event.target.closest("[data-close]")) this.closeLayer();
        });
        const focus = layer.querySelector("button,select,input");
        if (focus) focus.focus();
        return layer;
    }

    closeLayer() {
        const active = this.root.querySelector(".dialog-layer,.detail-layer");
        if (active) active.remove();
        this.root.querySelectorAll("[inert]").forEach(element => element.removeAttribute("inert"));
        if (active && this.layerOpener?.isConnected) this.layerOpener.focus({ preventScroll: true });
    }

    showMonths() {
        const keys = [...this.groups.keys()].filter(key => key !== "unknown");
        const years = [...new Set(keys.map(key => key.slice(0, 4)))].sort().reverse();
        const current = this.byID.get(this.anchorID);
        const year = current?.month?.slice(0, 4);
        const chosen = years.includes(year) ? year : years[0];
        const layer = this.layer(`<div class="dialog">
            <div class="dialog-heading"><h4>Jump to month</h4><button class="text-button" data-close>Done</button></div>
            <label class="year-picker">Year<select aria-label="Year">${years.map(value => `<option ${value === chosen ? "selected" : ""}>${value}</option>`).join("")}</select></label>
            <div class="month-grid"></div>
            ${this.groups.has("unknown") ? '<button class="text-button" data-month="unknown">Date unavailable</button>' : ""}
        </div>`, "Jump to month");
        const renderMonths = selectedYear => {
            layer.querySelector(".month-grid").innerHTML = keys.filter(key => key.startsWith(selectedYear)).map(key => `
                <button data-month="${key}">${monthName(key).split(" ")[0]}<small>${this.groups.get(key).length} receipts</small></button>`).join("");
        };
        renderMonths(chosen);
        layer.querySelector("select").addEventListener("change", event => renderMonths(event.target.value));
        layer.addEventListener("click", event => {
            const button = event.target.closest("[data-month]");
            if (!button) return;
            const offset = this.monthOffsets.get(button.dataset.month);
            this.closeLayer();
            this.scroller.scrollTop = offset;
            this.paint();
            const selected = this.groups.get(button.dataset.month)?.[0];
            if (selected) this.updateContext(selected);
        });
    }

    openReceipt(id) {
        const receipt = this.byID.get(id);
        if (!receipt) return;
        this.detailOrigin = { id, scroll: this.scroller.scrollTop, view: this.view };
        const layer = this.layer("", "Receipt");
        layer.className = "detail-layer";
        layer.innerHTML = `<div class="detail-nav"><button data-close aria-label="Back to receipts">‹ Back</button><strong>Receipt</strong></div>
            <div class="detail-scroll"><div class="full-paper"><h4>${receipt.merchant}</h4><p>${shortDate(receipt.date)} · CAD</p>
                ${receipt.lines.map(line => `<div class="receipt-line"><span>${line.name}</span><span>${(line.amount / 100).toFixed(2)}</span></div>`).join("")}
                <div class="receipt-line paper-total"><span>Total</span><span>${(receipt.total / 100).toFixed(2)}</span></div>
            </div></div>`;
        layer.querySelector("[data-close]").focus();
    }

    showOverview() {
        const receipts = this.filteredReceipts();
        const dated = [...this.groups.keys()].filter(key => key !== "unknown").sort().reverse();
        const current = this.byID.get(this.anchorID)?.month;
        const month = dated.includes(current) ? current : dated[0];
        const members = receipts.filter(receipt => receipt.month === month);
        const total = members.reduce((sum, receipt) => sum + receipt.total, 0);
        const merchants = new Map();
        members.forEach(receipt => merchants.set(receipt.merchant, (merchants.get(receipt.merchant) || 0) + receipt.total));
        this.layer(`<div class="dialog"><div class="dialog-heading"><h4>Purchase overview</h4><button class="text-button" data-close>Done</button></div>
            <p>${month ? monthName(month) : "No dated receipts"}</p><div class="overview-amount">${money(total)}</div>
            <p>${members.length} receipts</p>
            ${[...merchants].sort((a, b) => b[1] - a[1]).map(([name, amount]) => `<div class="overview-merchant"><span>${name}</span><strong>${money(amount)}</strong></div>`).join("")}
            <p>Illustrative overview. Accounting rules are a P14-04 design decision.</p>
        </div>`, "Purchase overview");
    }

    showImport() {
        const layer = this.layer(`<div class="dialog"><div class="dialog-heading"><h4>Import a receipt</h4><button class="text-button" data-close>Done</button></div>
            <div class="import-options"><button>Take a photo</button><button>Photo library</button><button>Files</button></div>
            <p>Import continues through the existing capture and review flow in Sliplet.</p></div>`, "Import a receipt");
        layer.querySelectorAll(".import-options button").forEach(button =>
            button.addEventListener("click", () => this.closeLayer()));
    }
}

const studies = [new ReceiptStudy("sections"), new ReceiptStudy("continuous")];
const countControl = document.getElementById("receipt-count");
countControl.addEventListener("change", () => studies.forEach(study => study.setData(Number(countControl.value))));
document.getElementById("appearance").addEventListener("change", event =>
    studies.forEach(study => study.root.classList.toggle("dark", event.target.value === "dark")));
document.getElementById("large-text").addEventListener("change", event => studies.forEach(study => {
    const anchor = study.anchorID;
    study.largeText = event.target.checked;
    study.root.classList.toggle("large-text", study.largeText);
    study.rebuild(anchor);
}));
document.getElementById("reduce-motion").addEventListener("change", event => studies.forEach(study => {
    study.reducedMotion = event.target.checked;
    study.rebuild(study.anchorID);
}));
document.addEventListener("keydown", event => {
    if (event.key === "Escape") studies.forEach(study => study.closeLayer());
});
studies.forEach(study => study.setData(50));
window.SlipletPhase14 = { studies, makeReceipts, money };
