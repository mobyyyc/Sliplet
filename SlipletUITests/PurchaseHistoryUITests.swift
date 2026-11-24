import XCTest

@MainActor final class PurchaseHistoryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ flags: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // The preview wallet can still display receipts from the preceding test while it reseeds.
        app.launchArguments = ["--t05-synthetic-preview", "empty"]
        app.launch()
        XCTAssertTrue(app.staticTexts["A place for your receipts"].waitForExistence(timeout: 30))
        app.terminate()

        app.launchArguments = ["--t05-synthetic-preview", "purchase-history"] + flags
        app.launch()
        XCTAssertTrue(app.staticTexts["3 saved"].waitForExistence(timeout: 30))
        return app
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable && element.frame.midY < app.frame.height - 100 { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func entries(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'purchaseHistoryEntry-'"))
    }

    private func comparisonChoices(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'historyComparePurchase-'"))
    }

    private func openCurrentReceipt(_ app: XCUIApplication) -> XCUIElement {
        let receipt = app.buttons.matching(NSPredicate(
            format: "identifier MATCHES %@ AND label CONTAINS %@", "receipt-[0-9]+", "2026-10-07")).firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 10))
        receipt.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        let line = app.scrollViews["detailScreen"].buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-'")).firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 10))
        return line
    }

    func testAutomaticHistoryOpensHighlightedReceiptAndReturnsToSameLine() {
        let app = launch(["--history-long-receipt"])
        let row = openCurrentReceipt(app)
        let y = row.frame.minY
        row.tap()
        XCTAssertTrue(app.buttons["editSavedLine"].exists)
        XCTAssertFalse(app.textFields["focusedQuantity"].exists)
        let overview = XCTAttachment(screenshot: app.screenshot()); overview.name = "P1106-line-overview"; overview.lifetime = .keepAlways; add(overview)
        app.buttons["openPurchaseHistory"].tap()
        let entry = entries(app).matching(NSPredicate(format: "label CONTAINS %@", "Oct 6, 2026")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Item code 123456"].exists)
        let timeline = XCTAttachment(screenshot: app.screenshot()); timeline.name = "P1106-history"; timeline.lifetime = .keepAlways; add(timeline)
        let entryID = entry.identifier
        let entryY = entry.frame.minY
        entry.tap()
        let highlighted = app.descendants(matching: .any)["historyHighlightedPurchase"]
        XCTAssertTrue(highlighted.waitForExistence(timeout: 10))
        XCTAssertTrue(highlighted.isHittable)
        XCTAssertFalse(app.buttons["confirmPurchaseLink"].exists)
        XCTAssertLessThan(highlighted.frame.midY, app.frame.maxY - 60)
        let receipt = XCTAttachment(screenshot: app.screenshot())
        receipt.name = "Highlighted receipt"; receipt.lifetime = .keepAlways; add(receipt)
        let share = app.buttons["historyOpenReceiptShare"]
        XCTAssertTrue(share.isHittable)
        share.tap()
        XCTAssertTrue(app.images["receiptShareImage"].waitForExistence(timeout: 10))
        app.buttons["Close"].tap()
        XCTAssertTrue(highlighted.waitForExistence(timeout: 5))
        app.buttons["historyReceiptOriginal"].tap()
        XCTAssertTrue(app.images["purchaseOriginalRaster"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(highlighted.waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        let returnedEntry = app.buttons[entryID]
        XCTAssertTrue(returnedEntry.waitForExistence(timeout: 10))
        XCTAssertTrue(returnedEntry.isHittable)
        XCTAssertEqual(returnedEntry.frame.minY, entryY, accuracy: 5)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["applyFocusedCorrection"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.frame.minY, y, accuracy: 3)
        app.terminate()
    }

    func testLineDetailsShowPriceAndAvailableUnitInformation() {
        let app = launch(["--t05-light", "--p1004-price-fixture"])
        let row = openCurrentReceipt(app)
        row.tap()
        XCTAssertTrue(app.staticTexts["savedLinePrice"].exists)
        XCTAssertTrue(app.staticTexts["Unit price"].exists)
        XCTAssertTrue(app.staticTexts["Quantity"].exists)
        XCTAssertFalse(app.staticTexts["Line amount"].exists)
        XCTAssertTrue(app.buttons["editSavedLine"].exists)
    }

    func testRecordedUnitPricesAndSavedComparisonAppearInHistory() {
        let app = launch(["--t05-light", "--p1004-price-fixture"])
        openCurrentReceipt(app).tap()
        app.buttons["openPurchaseHistory"].tap()
        let oldPurchases = entries(app)
        XCTAssertTrue(oldPurchases.element(boundBy: 1).waitForExistence(timeout: 10))
        XCTAssertEqual(oldPurchases.count, 2)
        for purchase in oldPurchases.allElementsBoundByIndex {
            XCTAssertTrue(purchase.isHittable)
            XCTAssertTrue(purchase.label.contains("Line total"))
            XCTAssertTrue(purchase.label.contains("6.17"))
        }
        let compare = app.buttons["compareUnitPrices"]
        XCTAssertEqual(app.buttons.matching(identifier: "compareUnitPrices").count, 1)
        XCTAssertFalse(comparisonChoices(app).firstMatch.exists)
        let history = XCTAttachment(screenshot: app.screenshot())
        history.name = "Compact purchase history"; history.lifetime = .keepAlways; add(history)
        let entry = oldPurchases.element(boundBy: 1)
        let date = "Oct 5, 2026"
        XCTAssertTrue(entry.label.contains(date))
        reveal(compare, app: app); compare.tap()
        let candidate = comparisonChoices(app).matching(NSPredicate(format: "label CONTAINS %@", date)).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 10))
        let picker = XCTAttachment(screenshot: app.screenshot())
        picker.name = "Compare prices picker"; picker.lifetime = .keepAlways; add(picker)
        candidate.tap()
        XCTAssertFalse(app.staticTexts["unitPriceResult"].exists)
        let firstOverview = app.descendants(matching: .any)["firstPriceOverview"].firstMatch
        let secondOverview = app.descendants(matching: .any)["secondPriceOverview"].firstMatch
        XCTAssertTrue(firstOverview.isHittable)
        XCTAssertTrue(secondOverview.isHittable)
        XCTAssertTrue(firstOverview.label.contains("6.17"))
        XCTAssertTrue(secondOverview.label.contains("6.17"))
        XCTAssertTrue(secondOverview.label.contains(date))
        XCTAssertEqual(firstOverview.frame.minY, secondOverview.frame.minY, accuracy: 5)
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "Unit price comparison overview"; overview.lifetime = .keepAlways; add(overview)
        let confirm = app.buttons["confirmComparisonPair"]
        reveal(confirm, app: app); confirm.tap()
        let details = app.buttons["firstPriceDetails"]
        reveal(details, app: app)
        let basis = app.descendants(matching: .any)["firstPriceBasis"].firstMatch
        XCTAssertFalse(basis.exists)
        details.tap()
        XCTAssertTrue(basis.waitForExistence(timeout: 5))
        details.tap()
        let tax = app.descendants(matching: .any)["priceTaxBasis"].firstMatch
        reveal(tax, app: app); tax.tap()
        app.buttons["Before tax"].firstMatch.tap()
        let checked = app.buttons["priceEvidenceChecked"]
        reveal(checked, app: app)
        checked.tap()
        XCTAssertEqual(checked.label, "Price details confirmed")
        let save = app.buttons["savePriceEvidence"]
        reveal(save, app: app)
        XCTAssertTrue(save.isEnabled); save.tap()
        XCTAssertTrue(app.staticTexts["savedUnitPriceResult"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(candidate.waitForExistence(timeout: 10))
        XCTAssertTrue(candidate.label.contains("Comparison saved"))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(entry.label.contains("Comparison saved"))
        XCTAssertFalse(oldPurchases.firstMatch.label.contains("Comparison saved"))
        compare.tap()
        XCTAssertTrue(candidate.waitForExistence(timeout: 10)); candidate.tap()
        let savedResult = app.staticTexts["savedUnitPriceResult"]
        XCTAssertTrue(savedResult.waitForExistence(timeout: 10))
        XCTAssertTrue(savedResult.label.contains("Same unit price"))
    }

    func testHistoryKeepsRecordedPricesSeparateWhenComparisonIsBlocked() {
        let app = launch(["--t05-dark", "--p1801-mixed-prices"])
        openCurrentReceipt(app).tap()
        app.buttons["openPurchaseHistory"].tap()
        let name = app.staticTexts["TEST ITEM ORGANIC WHOLE GRAIN BREAKFAST CEREAL FAMILY PACK"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Item code 123456"].exists)
        let byWeight = entries(app).matching(NSPredicate(format: "label CONTAINS %@", "CAD")).firstMatch
        let differentCurrency = entries(app).matching(NSPredicate(format: "label CONTAINS %@", "USD")).firstMatch
        XCTAssertTrue(byWeight.waitForExistence(timeout: 10))
        XCTAssertTrue(byWeight.label.contains("6.17 / kg"))
        XCTAssertTrue(differentCurrency.isHittable)
        XCTAssertFalse(differentCurrency.label.contains("Unit price"))
        let history = XCTAttachment(screenshot: app.screenshot())
        history.name = "Long item with mixed price evidence"; history.lifetime = .keepAlways; add(history)
        app.buttons["compareUnitPrices"].tap()
        let blocked = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'historyUnavailableComparison-'")).firstMatch
        XCTAssertTrue(blocked.waitForExistence(timeout: 10))
        XCTAssertTrue(blocked.label.localizedCaseInsensitiveContains("currency"))
        XCTAssertEqual(comparisonChoices(app).count, 1)
        comparisonChoices(app).firstMatch.tap()
        let confirm = app.buttons["confirmComparisonPair"]
        reveal(confirm, app: app); confirm.tap()
        let tax = app.descendants(matching: .any)["priceTaxBasis"].firstMatch
        reveal(tax, app: app); tax.tap()
        app.buttons["Before tax"].firstMatch.tap()
        let unavailable = app.staticTexts["priceUnavailable"]
        reveal(unavailable, app: app)
        XCTAssertTrue(unavailable.label.contains("Choose compatible units"))
        XCTAssertFalse(app.buttons["savePriceEvidence"].exists)
        XCTAssertFalse(app.staticTexts["unitPriceResult"].exists)
    }

    func testSearchHistoryRetainsQueryAndSupportsLargeText() throws {
        let app = launch(["--history-long-receipt", "--p1004-price-fixture", "--t05-large-text", "--t05-reduce-motion"])
        let search = app.buttons["receiptSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 30))
        search.tap()
        let query = app.searchFields.firstMatch
        XCTAssertTrue(query.waitForExistence(timeout: 10))
        query.typeText("TEST ITEM\n")
        let match = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'searchMatch-'")).firstMatch
        reveal(match, app: app); match.tap()
        let history = app.buttons["searchPurchaseHistory"]
        reveal(history, app: app); history.tap()
        XCTAssertTrue(app.navigationBars["Purchase history"].waitForExistence(timeout: 10))
        let compare = app.buttons["compareUnitPrices"]
        reveal(compare, app: app); compare.tap()
        let previousChoice = comparisonChoices(app).firstMatch
        reveal(previousChoice, app: app)
        let pickerShot = XCTAttachment(screenshot: app.screenshot())
        pickerShot.name = "Large text comparison picker"; pickerShot.lifetime = .keepAlways; add(pickerShot)
        previousChoice.tap()
        let priceBar = app.navigationBars["Compare unit prices"]
        XCTAssertTrue(priceBar.waitForExistence(timeout: 10))
        priceBar.buttons.firstMatch.tap()
        let pickerBar = app.navigationBars["Compare prices"]
        XCTAssertTrue(pickerBar.waitForExistence(timeout: 10))
        pickerBar.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Purchase history"].waitForExistence(timeout: 10))
        let previousPurchase = entries(app).firstMatch
        // An accessibility system size can place Other purchases below the initial viewport.
        reveal(previousPurchase, app: app)
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription])
        let historyShot = XCTAttachment(screenshot: app.screenshot())
        historyShot.name = "Large text purchase history"; historyShot.lifetime = .keepAlways; add(historyShot)
        previousPurchase.tap()
        let highlighted = app.descendants(matching: .any)["historyHighlightedPurchase"]
        XCTAssertTrue(highlighted.waitForExistence(timeout: 10))
        XCTAssertTrue(highlighted.isHittable)
        let receiptBar = app.navigationBars.containing(.button, identifier: "historyReceiptOriginal").firstMatch
        XCTAssertTrue(receiptBar.waitForExistence(timeout: 10))
        let back = try XCTUnwrap(receiptBar.buttons.allElementsBoundByIndex.first { $0.isHittable && $0.frame.midX < 100 })
        back.tap()
        let close = app.buttons["closePurchaseHistory"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        app.buttons["back"].tap()
        XCTAssertTrue(query.waitForExistence(timeout: 10))
        XCTAssertEqual(query.value as? String, "TEST ITEM")
        app.terminate()
    }
}
