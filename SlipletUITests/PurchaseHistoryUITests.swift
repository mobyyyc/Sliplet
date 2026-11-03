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
        app.buttons["openPurchaseHistory"].tap()
        let entry = firstMatch(app)
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        let original = app.buttons["historySecondOriginal"]
        reveal(original, app: app); original.tap()
        XCTAssertTrue(app.images["purchaseOriginalRaster"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        let confirm = app.buttons["confirmPurchaseLink"]
        reveal(confirm, app: app)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Same product confirmed"].waitForExistence(timeout: 10))
        let undo = app.buttons["undoPurchaseLink"]
        reveal(undo, app: app); undo.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 10))
        let reject = app.buttons["rejectPurchaseLink"]
        reveal(reject, app: app); reject.tap()
        XCTAssertTrue(app.staticTexts["Marked as different products"].waitForExistence(timeout: 10))
        reveal(app.buttons["undoPurchaseLink"], app: app); app.buttons["undoPurchaseLink"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(firstMatch(app).waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["applyFocusedCorrection"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.frame.minY, y, accuracy: 3)
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
