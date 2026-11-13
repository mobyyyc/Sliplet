import XCTest

/// Read-only screen inventory using disposable fictional stores, never the owner's wallet.
@MainActor final class Phase11AuditUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func capture(_ app: XCUIApplication, _ title: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = title; shot.lifetime = .keepAlways; add(shot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = title + "-tree"; tree.lifetime = .keepAlways; add(tree)
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable && element.frame.midY < app.frame.height - 120 { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
    }
    func testScreenInventory() {
        for (mode, anchor) in [("empty", "import"), ("wallet", "receipt-0"), ("long", "edit"), ("review", "saveDraft"), ("source", "sourceDone"), ("search-large", "walletTab")] {
            let app = XCUIApplication()
            app.launchArguments = ["--t05-synthetic-preview", mode, "--t05-light"]
            app.launch()
            XCTAssertTrue(app.buttons[anchor].waitForExistence(timeout: 35), mode)
            capture(app, "P11-light-" + mode)
            if mode == "long" || mode == "review" || mode == "search-large" {
                app.swipeUp(); app.swipeUp()
                capture(app, "P11-light-" + mode + "-scrolled")
            }
            app.terminate()
        }
    }
    func testSettingsAndSplitInventory() {
        for large in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["--t05-synthetic-preview", "split", "--p804-ai-settings-fixture", "--p205-backup-fixture"] + (large ? ["--t05-large-text", "--t05-reduce-motion"] : ["--t05-light"])
            app.launch()
            XCTAssertTrue(app.buttons["splitOpen"].waitForExistence(timeout: 35))
            app.buttons["splitOpen"].tap()
            XCTAssertTrue(app.buttons["splitDone"].waitForExistence(timeout: 10))
            let variant = large ? "large-dark" : "light"
            capture(app, "P11-" + variant + "-split")
            reveal(app.buttons["splitAddPerson"], in: app)
            capture(app, "P11-" + variant + "-split-add-person")
            XCTAssertFalse(app.buttons["splitAddPerson"].isEnabled)
            app.buttons["splitDone"].tap()
            app.buttons["back"].tap()
            XCTAssertTrue(app.buttons["walletSettings"].waitForExistence(timeout: 10))
            app.buttons["walletSettings"].tap()
            capture(app, "P11-" + variant + "-settings")
            reveal(app.buttons["aiRecognitionSettings"], in: app)
            app.buttons["aiRecognitionSettings"].tap()
            XCTAssertTrue(app.navigationBars["AI recognition"].waitForExistence(timeout: 10))
            capture(app, "P11-" + variant + "-ai-settings")
            app.swipeUp()
            capture(app, "P11-" + variant + "-ai-settings-scrolled")
            app.terminate()
        }
    }
    func testHistoryAndPriceHierarchy() {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "purchase-history", "--t05-light", "--p1004-price-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["receipt-0"].waitForExistence(timeout: 30))
        app.buttons["receipt-0"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        let row = app.scrollViews["detailScreen"].buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        XCTAssertTrue(app.buttons["openPurchaseHistory"].waitForExistence(timeout: 10))
        capture(app, "P11-row-details")
        app.buttons["openPurchaseHistory"].tap()
        let match = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'purchaseHistoryEntry-'")).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 10))
        capture(app, "P11-product-history")
        let compare = app.buttons["compareUnitPrices"].firstMatch
        reveal(compare, in: app); compare.tap()
        XCTAssertTrue(app.navigationBars["Compare unit prices"].waitForExistence(timeout: 10))
        let confirm = app.buttons["confirmComparisonPair"]
        XCTAssertTrue(confirm.exists)
        XCTAssertFalse(app.staticTexts["unitPriceResult"].exists)
        confirm.tap()
        capture(app, "P11-price-top")
        reveal(app.descendants(matching: .any)["priceTaxBasis"].firstMatch, in: app)
        capture(app, "P11-price-bottom")
        app.terminate()
    }
    func testUtilityInventory() {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--t05-light", "--p205-backup-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["walletSettings"].waitForExistence(timeout: 30))
        app.buttons["walletSettings"].tap()
        reveal(app.buttons["exportBackup"], in: app); app.buttons["exportBackup"].tap()
        XCTAssertTrue(app.secureTextFields["backupPassword"].waitForExistence(timeout: 10))
        capture(app, "P11-backup-export")
        app.secureTextFields["backupPassword"].tap(); app.secureTextFields["backupPassword"].typeText("fictional-password")
        app.secureTextFields["backupPasswordConfirmation"].tap(); app.secureTextFields["backupPasswordConfirmation"].typeText("different-password")
        capture(app, "P11-backup-mismatch-keyboard")
        XCTAssertFalse(app.buttons["chooseBackupDestination"].isEnabled)
        app.buttons["closeBackup"].tap()
        reveal(app.buttons["restoreBackup"], in: app); app.buttons["restoreBackup"].tap()
        XCTAssertTrue(app.buttons["chooseBackupFile"].waitForExistence(timeout: 10))
        capture(app, "P11-backup-restore")
        app.terminate()
        app.launchArguments = ["--t05-synthetic-preview", "correction-normal", "--t05-light"]
        app.launch()
        XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 30))
        let check = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'reviewCheck-line-'")).firstMatch
        reveal(check, in: app); check.tap()
        reveal(app.buttons["focusedReread"], in: app); app.buttons["focusedReread"].tap()
        XCTAssertTrue(app.buttons["rereadSelectArea"].waitForExistence(timeout: 10))
        capture(app, "P11-reread-top")
        app.swipeUp()
        capture(app, "P11-reread-bottom")
        app.terminate()
    }

}
