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
    func testSearchKeepsNativeToolbarAndReturnsToMatchingReceipt() {
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
}
