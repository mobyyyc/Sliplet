import XCTest

@MainActor final class PurchaseHistoryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ flags: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "purchase-history"] + flags
        app.launch()
        XCTAssertTrue(app.buttons["receipt-0"].waitForExistence(timeout: 30))
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

    func testAutomaticHistoryOpensHighlightedReceiptAndReturnsToSameLine() {
        let app = launch(["--t05-light", "--history-long-receipt"])
        app.buttons["receipt-0"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        let row = app.scrollViews["detailScreen"].buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let y = row.frame.minY
        row.tap()
        XCTAssertTrue(app.buttons["editSavedLine"].exists)
        XCTAssertFalse(app.textFields["focusedQuantity"].exists)
        let overview = XCTAttachment(screenshot: app.screenshot()); overview.name = "P1106-line-overview"; overview.lifetime = .keepAlways; add(overview)
        app.buttons["openPurchaseHistory"].tap()
        let entry = entries(app).element(boundBy: 1)
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Item code 123456"].exists)
        let timeline = XCTAttachment(screenshot: app.screenshot()); timeline.name = "P1106-history"; timeline.lifetime = .keepAlways; add(timeline)
        entry.tap()
        let highlighted = app.descendants(matching: .any)["historyHighlightedPurchase"]
        XCTAssertTrue(highlighted.waitForExistence(timeout: 10))
        XCTAssertTrue(highlighted.isHittable)
        XCTAssertFalse(app.buttons["confirmPurchaseLink"].exists)
        XCTAssertLessThan(highlighted.frame.midY, app.frame.maxY - 60)
        let receipt = XCTAttachment(screenshot: app.screenshot())
        receipt.name = "Highlighted receipt"; receipt.lifetime = .keepAlways; add(receipt)
        app.buttons["historyReceiptOriginal"].tap()
        XCTAssertTrue(app.images["purchaseOriginalRaster"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(highlighted.waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(entries(app).firstMatch.waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["applyFocusedCorrection"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.frame.minY, y, accuracy: 3)
        app.terminate()
    }

    func testLineDetailsShowPriceAndAvailableUnitInformation() {
        let app = launch(["--t05-light", "--p1004-price-fixture"])
        app.buttons["receipt-0"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        let row = app.scrollViews["detailScreen"].buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.staticTexts["savedLinePrice"].exists)
        XCTAssertTrue(app.staticTexts["Unit price"].exists)
        XCTAssertTrue(app.staticTexts["Quantity"].exists)
        XCTAssertFalse(app.staticTexts["Line amount"].exists)
        XCTAssertTrue(app.buttons["editSavedLine"].exists)
    }

    func testRecordedUnitPricesAndSavedComparisonAppearInHistory() {
        let app = launch(["--t05-light", "--p1004-price-fixture"])
        app.buttons["receipt-0"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        let row = app.scrollViews["detailScreen"].buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        app.buttons["openPurchaseHistory"].tap()
        XCTAssertTrue(entries(app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(entries(app).firstMatch.label.contains("Line total"))
        XCTAssertTrue(entries(app).firstMatch.label.contains("6.17"))
        let compare = app.buttons["compareUnitPrices"].firstMatch
        reveal(compare, app: app); compare.tap()
        XCTAssertFalse(app.staticTexts["unitPriceResult"].exists)
        app.buttons["confirmComparisonPair"].tap()
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
        let saved = app.buttons["historySavedComparison"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10))
        XCTAssertTrue(saved.label.contains("Same unit price"))
    }

    func testSearchHistoryRetainsQueryAndSupportsLargeText() throws {
        let app = launch(["--t05-large-text", "--t05-reduce-motion"])
        app.buttons["allReceipts"].tap()
        let query = app.searchFields.firstMatch
        XCTAssertTrue(query.waitForExistence(timeout: 10))
        query.tap(); query.typeText("TEST ITEM\n")
        let match = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'searchMatch-'")).firstMatch
        reveal(match, app: app); match.tap()
        let history = app.buttons["searchPurchaseHistory"]
        reveal(history, app: app); history.tap()
        XCTAssertTrue(entries(app).firstMatch.waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription])
        entries(app).firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["historyHighlightedPurchase"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["closePurchaseHistory"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        app.buttons["back"].tap()
        XCTAssertEqual(query.value as? String, "TEST ITEM")
        app.terminate()
    }
}
