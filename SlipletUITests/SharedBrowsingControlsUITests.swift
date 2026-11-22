import XCTest

@MainActor final class SharedBrowsingControlsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--t05-synthetic-preview", "many", dark ? "--t05-dark" : "--t05-light"]
        app.launch(); XCTAssertTrue(app.staticTexts["30 saved"].waitForExistence(timeout: 60)); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func testSharedToolbarFiltersResetAndDisplayChoice() {
        let app = launch()
        XCTAssertTrue(app.buttons["walletSettings"].isHittable)
        XCTAssertTrue(app.buttons["receiptSearch"].isHittable)
        XCTAssertLessThan(app.buttons["receiptSearch"].frame.midX, app.buttons["searchFilters"].frame.midX)
        XCTAssertLessThan(app.buttons["searchFilters"].frame.midX, app.buttons["walletSettings"].frame.midX)
        XCTAssertLessThan(app.staticTexts["browseTitle"].frame.midX, app.buttons["receiptSearch"].frame.minX)
        XCTAssertFalse(app.buttons["walletMonths"].exists); XCTAssertFalse(app.buttons["allReceipts"].exists)
        app.buttons["searchFilters"].tap()
        let maximum = app.textFields["filterMaximum"]
        if !maximum.isHittable { app.swipeUp() }
        maximum.tap(); maximum.typeText("0")
        app.buttons["applySearchFilters"].tap()
        XCTAssertTrue(app.staticTexts["No matching receipts"].waitForExistence(timeout: 10))
        capture(app, "shared-wallet-empty-filter")
        app.buttons["Clear filters"].tap(); XCTAssertTrue(app.staticTexts["30 saved"].waitForExistence(timeout: 10))
        app.buttons["walletSettings"].tap()
        app.buttons["receiptDisplayMode"].tap(); app.buttons["List"].tap(); app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'searchReceipt-' ")).firstMatch.waitForExistence(timeout: 10))
        for _ in 0..<10 {
            if app.staticTexts["searchResultCount"].exists { break }
            app.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(app.staticTexts["searchResultCount"].exists)
        XCTAssertEqual(app.staticTexts["searchResultCount"].label, "30 receipts")
        XCTAssertTrue(app.buttons["walletSettings"].isHittable); XCTAssertTrue(app.buttons["receiptSearch"].isHittable)
        XCTAssertFalse(app.buttons["walletTab"].exists)
        capture(app, "shared-list-toolbar"); app.terminate()
    }
    func testSearchKeepsToolbarAndReturnsToMatchingReceipt() {
        let app = launch(true)
        app.buttons["receiptSearch"].tap()
        let field = app.searchFields.firstMatch; XCTAssertTrue(field.waitForExistence(timeout: 10)); field.typeText("milk\n")
        XCTAssertTrue(app.buttons["walletSettings"].isHittable)
        XCTAssertTrue(app.buttons["searchFilters"].isHittable)
        capture(app, "shared-active-search")
        let match = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'searchMatch-' ")).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 10)); match.tap()
        XCTAssertTrue(app.buttons["back"].waitForExistence(timeout: 10)); app.buttons["back"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "milk")
        app.buttons["searchFilters"].tap(); XCTAssertTrue(app.buttons["filterDateMode"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.buttons["filterDateMode"].tap(); app.buttons["Date range"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["filterStartDate"].exists); XCTAssertTrue(app.descendants(matching: .any)["filterEndDate"].exists)
        capture(app, "shared-date-range-filter"); app.buttons["Cancel"].tap(); app.terminate()
    }
    func testEmptySearchIncludesEligibleArchivedReceiptAndRestoresItsResult() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "long-wallet", "--search-long-paper", "--t05-dark"]
        app.launch()
        let paper = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'receipt-' AND label CONTAINS 'SYNTHETIC CORNER'")).firstMatch
        XCTAssertTrue(paper.waitForExistence(timeout: 30))
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10)).tap()
        let options = app.buttons["receiptOptions"]
        XCTAssertTrue(options.waitForExistence(timeout: 10))
        options.tap()
        app.buttons["Archive receipt"].tap()
        XCTAssertTrue(app.staticTexts["2 saved"].waitForExistence(timeout: 12))

        app.buttons["receiptSearch"].tap()
        let query = app.searchFields.firstMatch
        XCTAssertTrue(query.waitForExistence(timeout: 10))
        query.typeText("no matching item\n")
        let count = app.staticTexts["searchResultCount"]
        XCTAssertTrue(app.staticTexts["No matches"].waitForExistence(timeout: 10))
        let include = app.buttons["includeArchivedSearchMatches"]
        XCTAssertFalse(include.exists)

        app.buttons["searchFilters"].tap()
        app.buttons["searchMerchantFilter"].tap()
        app.buttons["SYNTHETIC CORNER"].tap()
        app.buttons["applySearchFilters"].tap()
        let storeFilter = app.buttons["Remove filter: SYNTHETIC CORNER"]
        XCTAssertTrue(storeFilter.waitForExistence(timeout: 10))
        app.buttons["Clear text"].tap()
        query.tap()
        let term = "TEST GROCERY 30"
        query.typeText(term + "\n")
        XCTAssertTrue(include.waitForExistence(timeout: 10))
        XCTAssertTrue(include.isHittable)
        XCTAssertEqual(include.label, "Include archived")
        XCTAssertLessThan(include.frame.height, 80)
        XCTAssertEqual(count.label, "0 receipts")
        capture(app, "archive-search-shortcut")
        include.tap()
        let archiveFilter = app.buttons["Remove filter: Including archived"]
        XCTAssertTrue(archiveFilter.waitForExistence(timeout: 10))
        XCTAssertTrue(storeFilter.exists)
        XCTAssertEqual(query.value as? String, term)
        XCTAssertEqual(count.label, "1 receipt")
        XCTAssertFalse(include.exists)

        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'searchMatch-' AND label CONTAINS 'Archived'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let identifier = row.identifier
        let originalY = row.frame.minY
        row.tap()
        let original = app.buttons["original"]
        XCTAssertTrue(original.waitForExistence(timeout: 12))
        original.tap()
        XCTAssertTrue(app.descendants(matching: .any)["sourceRaster"].firstMatch.waitForExistence(timeout: 12))
        let done = app.buttons["sourceDone"]
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 10))
        app.buttons["back"].tap()
        let returned = app.buttons[identifier]
        XCTAssertTrue(returned.waitForExistence(timeout: 10))
        XCTAssertTrue(returned.isHittable)
        XCTAssertEqual(returned.frame.minY, originalY, accuracy: 12)
        XCTAssertEqual(query.value as? String, term)
        XCTAssertTrue(storeFilter.exists)
        XCTAssertTrue(archiveFilter.exists)
        capture(app, "archived-result-restored")

        archiveFilter.tap()
        XCTAssertTrue(include.waitForExistence(timeout: 10))
        XCTAssertEqual(query.value as? String, term)
        XCTAssertTrue(storeFilter.exists)
        XCTAssertFalse(archiveFilter.exists)
    }

    func testTodayIsVisibleInitiallyAndAfterSearchCancel() {
        checkRecentWallet(id: "today", title: "Today", arguments: ["--t05-light", "--today-wallet"])
    }

    func testLatestReplacesTodayWhenThereAreNoSameDayPurchases() {
        checkRecentWallet(id: "latest", title: "Latest", arguments: ["--t05-dark"])
    }

    private func checkRecentWallet(id: String, title: String, arguments: [String]) {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet"] + arguments
        app.launch(); XCTAssertTrue(app.staticTexts["3 saved"].waitForExistence(timeout: 60))
        let recent = app.buttons["walletSection-" + id]
        XCTAssertTrue(recent.waitForExistence(timeout: 15))
        XCTAssertTrue(recent.label.contains(title))
        XCTAssertFalse(app.buttons["walletSection-" + (id == "today" ? "latest" : "today")].exists)
        capture(app, id + "-wallet-initial")
        XCTAssertGreaterThan(recent.frame.minY, 110); XCTAssertLessThan(recent.frame.maxY, app.frame.height - 120)
        let newest = app.buttons["receipt-2"]; XCTAssertTrue(newest.isHittable)
        app.buttons["receiptSearch"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText(id == "latest" ? "synthetic" : "synthetic\n")
        let keyboard = app.keyboards.firstMatch
        if id == "latest" {
            XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5))
        }
        XCTAssertEqual(app.staticTexts["browseTitle"].label, "Wallet")
        app.buttons["close"].tap()
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertGreaterThan(recent.frame.minY, 110); XCTAssertLessThan(recent.frame.maxY, app.frame.height - 120)
        XCTAssertEqual(app.staticTexts["browseTitle"].label, "Wallet")
        let pocket = app.otherElements["walletPocket"]
        XCTAssertTrue(pocket.exists)
        XCTAssertTrue(newest.isHittable)
        XCTAssertLessThan(newest.frame.midY, pocket.frame.minY, "The newest receipt should be readable above the pocket")
        XCTAssertGreaterThan(newest.frame.maxY, pocket.frame.minY, "The newest receipt should still be tucked into the pocket")
        capture(app, id + "-wallet-after-search-cancel")
        guard id == "today" else { app.terminate(); return }
        app.buttons["walletSettings"].tap()
        XCTAssertTrue(app.buttons["receiptDisplayMode"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["paperAppearanceSetting"].isHittable)
        XCTAssertTrue(app.staticTexts["Display"].exists)
        for _ in 0..<6 {
            if app.buttons["walletInformationSetting"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["walletInformationSetting"].isHittable)
        capture(app, "settings-information-last"); app.buttons["Done"].tap(); app.terminate()
    }

}
