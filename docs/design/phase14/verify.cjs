/* Interaction checks for the local fictional design prototypes.
   PLAYWRIGHT_MODULE and CHROME_EXECUTABLE point to existing review tools. */
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || "playwright");
const base = __dirname;
const output = path.join(base, "evidence");
fs.mkdirSync(output, { recursive: true });
const checks = [];
const measurements = [];
const check = (description, value) => {
    assert.ok(value, description);
    checks.push(description);
};

(async () => {
    const browser = await chromium.launch({
        executablePath: process.env.CHROME_EXECUTABLE || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        headless: true
    });
    try {
        const page = await browser.newPage({ viewport: { width: 1100, height: 1190 }, deviceScaleFactor: 1 });
        const runtimeErrors = [];
        page.on("pageerror", error => runtimeErrors.push(error.message));
        await page.goto("file://" + path.join(base, "index.html"));
        const phone = variant => page.locator("#" + variant);
        const state = (variant, field) => page.evaluate(({ variant, field }) => {
            const study = SlipletPhase14.studies.find(study => study.variant === variant);
            return study[field];
        }, { variant, field });
        const screenshot = file => page.locator(".studies").screenshot({
            path: path.join(output, file), animations: "disabled"
        });

        for (const count of [5, 50, 200, 1000]) {
            await page.locator("#receipt-count").selectOption(String(count));
            const fixtures = await page.evaluate(() => SlipletPhase14.studies.every(study =>
                study.receipts.every(receipt => receipt.lines.reduce((sum, line) => sum + line.amount, 0)
                    === receipt.total && Number.isSafeInteger(receipt.total))));
            check(count + " fictional receipts have exact line totals", fixtures);

            for (const variant of ["sections", "continuous"]) {
                const root = phone(variant);
                await root.getByRole("button", { name: "Wallet", exact: true }).click();
                const rows = await state(variant, "rows");
                check(variant + ": all " + count + " receipts have an individual entry",
                    rows.filter(row => row.type === "receipt").length === count);
                const datedMonths = [...new Set(rows.filter(row => row.type === "receipt" && row.receipt.date)
                    .map(row => row.receipt.month))].sort();
                const oldest = datedMonths[0];
                await root.getByRole("button", { name: "Jump to month", exact: true }).click();
                await root.getByRole("combobox", { name: "Year", exact: true }).selectOption(oldest.slice(0, 4));
                await root.locator('[data-month="' + oldest + '"]').click();

                const jump = await page.evaluate(({ variant, oldest }) => {
                    const study = SlipletPhase14.studies.find(study => study.variant === variant);
                    return {
                        actual: study.scroller.scrollTop, expected: study.monthOffsets.get(oldest),
                        max: study.scroller.scrollHeight - study.scroller.clientHeight
                    };
                }, { variant, oldest });
                check(variant + ": oldest month is reached directly at " + count + " receipts",
                    Math.abs(jump.actual - Math.min(jump.expected, jump.max)) < 2);

                const oldestReceipt = rows.find(row => row.type === "receipt" && row.receipt.month === oldest);
                await page.evaluate(({ variant, id }) => {
                    const study = SlipletPhase14.studies.find(study => study.variant === variant);
                    study.scroller.scrollTop = Math.max(0, study.rows.find(row =>
                        row.type === "receipt" && row.receipt.id === id).y - 18);
                    study.paint();
                }, { variant, id: oldestReceipt.receipt.id });
                const scrollBefore = await root.locator(".scroller").evaluate(element => element.scrollTop);
                await root.locator('[data-receipt="' + oldestReceipt.receipt.id + '"]').click({ position: { x: 65, y: 22 } });
                check(variant + ": an old receipt opens from browsing", await root.locator(".full-paper").count() === 1);
                await root.getByRole("button", { name: "Back to receipts", exact: true }).click();
                check(variant + ": return preserves the old receipt position",
                    Math.abs(await root.locator(".scroller").evaluate(element => element.scrollTop) - scrollBefore) < 2);

                const anchorBefore = await state(variant, "anchorID");
                await root.getByRole("button", { name: "List", exact: true }).click();
                const anchorVisible = await page.evaluate(({ variant, id }) => {
                    const study = SlipletPhase14.studies.find(study => study.variant === variant);
                    const row = study.rows.find(row => row.type === "receipt" && row.receipt.id === id);
                    return row && row.y + row.height > study.scroller.scrollTop &&
                        row.y < study.scroller.scrollTop + study.scroller.clientHeight;
                }, { variant, id: anchorBefore });
                check(variant + ": Wallet to List keeps the same purchase visible", anchorVisible);
                await root.getByRole("button", { name: "Wallet", exact: true }).click();

                if (count >= 200) {
                    await root.getByRole("button", { name: "Jump to month", exact: true }).click();
                    await root.getByRole("button", { name: "Date unavailable", exact: true }).click();
                    const undatedVisible = await page.evaluate(variant => {
                        const study = SlipletPhase14.studies.find(study => study.variant === variant);
                        const row = study.rows.find(row => row.type === "receipt" && row.receipt.date === null);
                        return row && row.y + row.height > study.scroller.scrollTop &&
                            row.y < study.scroller.scrollTop + study.scroller.clientHeight;
                    }, variant);
                    check(variant + ": the undated receipt is directly reachable", undatedVisible);
                }

                await root.getByRole("button", { name: "Search receipts", exact: true }).click();
                await root.getByRole("textbox", { name: "Search merchant, item or code" }).fill("RICE");
                const matching = await state(variant, "rows");
                check(variant + ": item search finds matching purchases across months",
                    matching.some(row => row.type === "receipt") &&
                    matching.filter(row => row.type === "receipt").every(row =>
                        row.receipt.lines.some(line => line.name === "RICE")));
                await root.getByRole("button", { name: "Close search", exact: true }).click();
                await root.getByRole("combobox", { name: "Receipt collection", exact: true }).selectOption("Starred");
                check(variant + ": Starred is a first-level collection",
                    (await state(variant, "rows")).filter(row => row.type === "receipt").every(row => row.receipt.starred));
                await root.getByRole("combobox", { name: "Receipt collection", exact: true }).selectOption("Archive");
                check(variant + ": Archive is a first-level collection",
                    (await state(variant, "rows")).filter(row => row.type === "receipt").length > 0);
                await root.getByRole("combobox", { name: "Receipt collection", exact: true }).selectOption("All receipts");

                const timing = await page.evaluate(variant => {
                    const study = SlipletPhase14.studies.find(study => study.variant === variant);
                    for (let index = 0; index < 100; index++) {
                        study.scroller.scrollTop = index / 99 * (study.scroller.scrollHeight - study.scroller.clientHeight);
                        study.paint();
                    }
                    const percentile = values => [...values].sort((a, b) => a - b)[Math.floor(values.length * .95)];
                    return {
                        maxMountedReceipts: study.metrics.maxReceiptNodes,
                        paintP95Ms: percentile(study.metrics.paintMs),
                        layoutP95Ms: percentile(study.metrics.layoutMs)
                    };
                }, variant);
                check(variant + ": mounted receipt count stays bounded at " + count, timing.maxMountedReceipts <= 16);
                measurements.push({ count, variant, ...timing });
            }
        }

        await page.locator("#receipt-count").selectOption("5");
        for (const variant of ["sections", "continuous"]) {
            const root = phone(variant);
            await root.getByRole("button", { name: "Wallet", exact: true }).click();
        }
        await screenshot("five-receipts-light.png");

        await page.locator("#receipt-count").selectOption("50");
        for (const variant of ["sections", "continuous"]) {
            await page.evaluate(variant => {
                const study = SlipletPhase14.studies.find(study => study.variant === variant);
                const secondMonth = [...study.groups.keys()].sort()[1];
                study.scroller.scrollTop = study.monthOffsets.get(secondMonth) - 240;
                study.paint();
            }, variant);
        }
        await screenshot("month-boundary-light.png");

        await page.locator("#receipt-count").selectOption("200");
        for (const variant of ["sections", "continuous"]) {
            await phone(variant).getByRole("button", { name: "List", exact: true }).click();
        }
        await screenshot("two-hundred-receipts-list.png");
        await page.locator("#appearance").selectOption("dark");
        for (const variant of ["sections", "continuous"]) {
            await phone(variant).getByRole("button", { name: "Wallet", exact: true }).click();
        }
        await screenshot("two-hundred-receipts-dark.png");

        await page.locator("#large-text").check();
        await page.locator("#reduce-motion").check();
        for (const variant of ["sections", "continuous"]) {
            await phone(variant).getByRole("button", { name: "List", exact: true }).click();
            check(variant + ": large text retains individual receipt entries",
                (await state(variant, "rows")).filter(row => row.type === "receipt").length === 200);
        }
        await screenshot("large-text-dark-list.png");
        await page.setViewportSize({ width: 390, height: 900 });
        check("Review page fits a narrow screen without horizontal overflow",
            await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        await page.setViewportSize({ width: 1100, height: 1190 });
        await page.locator("#large-text").uncheck();
        await page.locator("#reduce-motion").uncheck();
        await page.locator("#appearance").selectOption("light");
        await page.locator("#receipt-count").selectOption("50");
        for (const variant of ["sections", "continuous"]) {
            const root = phone(variant);
            await root.getByRole("button", { name: "Wallet", exact: true }).click();
            await root.getByRole("button", { name: "Purchase overview", exact: true }).click();
            check(variant + ": the overview entry is reachable", await root.locator(".overview-amount").count() === 1);
            await page.keyboard.press("Escape");
            await root.getByRole("button", { name: "Import receipt", exact: true }).click();
            check(variant + ": import choices remain in the primary action", await root.locator(".import-options button").count() === 3);
            await page.keyboard.press("Escape");
        }
        check("No JavaScript runtime errors", runtimeErrors.length === 0);
        const report = {
            scope: "Local fictional HTML design prototypes. Browser timings are not native iOS frame or interaction timings.",
            checks, measurements, runtimeErrors
        };
        fs.writeFileSync(path.join(output, "browser-checks.json"), JSON.stringify(report, null, 2) + "\n");
        console.log(JSON.stringify({ passed: checks.length, measurements }, null, 2));
    } finally {
        await browser.close();
    }
})().catch(error => { console.error(error); process.exitCode = 1; });
