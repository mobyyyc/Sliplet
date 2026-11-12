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

    private func assertMatchStatus(_ label: String, app: XCUIApplication) {
        let status = app.staticTexts[label]
        for _ in 0..<8 {
            if status.exists && status.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(status.waitForExistence(timeout: 5))
    }

    private func firstMatch(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'purchaseHistoryEntry-'")).firstMatch
    }

    func testSavedRowConfirmOriginalUndoAndReturnPosition() {
        let app = launch(["--t05-light"])
        app.buttons["receipt-0"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        let row = app.scrollViews["detailScreen"].buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let y = row.frame.minY
        row.tap()
        XCTAssertTrue(app.buttons["editSavedLine"].exists)
        XCTAssertFalse(app.textFields["focusedQuantity"].exists)
        let overview = XCTAttachment(screenshot: app.screenshot()); overview.name = "P1106-line-overview"; overview.lifetime = .keepAlways; add(overview)
        app.buttons["openPurchaseHistory"].tap()
        let entry = firstMatch(app)
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        let timeline = XCTAttachment(screenshot: app.screenshot()); timeline.name = "P1106-history"; timeline.lifetime = .keepAlways; add(timeline)
        entry.tap()
        let original = app.buttons["historySecondOriginal"]
        reveal(original, app: app); original.tap()
        XCTAssertTrue(app.images["purchaseOriginalRaster"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        let confirm = app.buttons["confirmPurchaseLink"]
        reveal(confirm, app: app)
        confirm.tap()
        assertMatchStatus("Same product confirmed", app: app)
        let undo = app.buttons["undoPurchaseLink"]
        reveal(undo, app: app); undo.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 10))
        let reject = app.buttons["rejectPurchaseLink"]
        app.swipeDown()
        reveal(reject, app: app); reject.tap()
        assertMatchStatus("Marked as different products", app: app)
        reveal(app.buttons["undoPurchaseLink"], app: app); app.buttons["undoPurchaseLink"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(firstMatch(app).waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["applyFocusedCorrection"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.frame.minY, y, accuracy: 3)
        app.terminate()
    }

    func testVerifiedUnitPriceCanBeSavedAndCleared() {
        let app = launch(["--t05-light", "--p1004-price-fixture"])
        app.buttons["receipt-0"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        let row = app.scrollViews["detailScreen"].buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        app.buttons["openPurchaseHistory"].tap()
        firstMatch(app).tap()
        let pack = app.buttons["purchasePack"]
        reveal(pack, app: app); pack.tap(); app.buttons["Same"].tap()
        let confirm = app.buttons["confirmPurchaseLink"]
        reveal(confirm, app: app); confirm.tap()
        let prices = app.buttons["compareUnitPrices"]
        reveal(prices, app: app); prices.tap()
        let tax = app.buttons["priceTaxBasis"]
        reveal(tax, app: app); tax.tap(); app.buttons["Before tax"].tap()
        let checked = app.switches["priceEvidenceChecked"]
        reveal(checked, app: app)
        checked.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let result = app.staticTexts["unitPriceResult"]
        reveal(result, app: app)
        XCTAssertEqual(result.label, "Same unit price")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Unit price comparison"; screenshot.lifetime = .keepAlways; add(screenshot)
        let save = app.buttons["savePriceEvidence"]
        reveal(save, app: app); save.tap()
        let editVerification = app.buttons["editPriceEvidence"]
        XCTAssertTrue(editVerification.waitForExistence(timeout: 10))
        let saved = app.staticTexts["savedUnitPriceResult"]
        for _ in 0..<8 {
            if saved.exists && saved.isHittable { break }
            app.swipeDown()
        }
        XCTAssertEqual(saved.label, "Same unit price")
        XCTAssertFalse(app.buttons["priceTaxBasis"].exists)
        editVerification.tap()
        XCTAssertTrue(app.buttons["cancelPriceEvidenceEdit"].waitForExistence(timeout: 5))
        app.buttons["cancelPriceEvidenceEdit"].tap()
        let clear = app.buttons["clearPriceEvidence"]
        reveal(clear, app: app); clear.tap()
        XCTAssertTrue(clear.waitForNonExistence(timeout: 10))
        XCTAssertFalse(result.exists)
        XCTAssertFalse(saved.exists)
        app.terminate()
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
        XCTAssertTrue(firstMatch(app).waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription])
        firstMatch(app).tap()
        let receipt = app.buttons["historySecondReceipt"]
        reveal(receipt, app: app); receipt.tap()
        XCTAssertTrue(app.staticTexts["receiptPaperMerchant"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["closePurchaseHistory"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        app.buttons["back"].tap()
        XCTAssertEqual(query.value as? String, "TEST ITEM")
        app.terminate()
    }
}
