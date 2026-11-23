import XCTest

@MainActor final class ReceiptBrowsingUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ mode: String = "search-large", flags: [String] = ["--t05-light"]) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--t05-synthetic-preview", mode] + flags
        app.launch(); XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 90))
        XCTAssertTrue(app.staticTexts[mode == "search-large" ? "500 receipts" : "3 receipts"].waitForExistence(timeout: 90))
        return app
    }
    private func capture(_ app: XCUIApplication, _ title: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = "P14-03-" + title; a.lifetime = .keepAlways; add(a)
    }
    private func search(_ value: String, app: XCUIApplication) {
        let field = app.searchFields.firstMatch; field.tap()
        let current = field.value as? String ?? ""
        if !current.isEmpty && current != "Merchant, item or code" { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)) }
        field.typeText(value + "\n")
    }
    private func results(_ app: XCUIApplication) -> XCUIElementQuery { app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'searchMatch-'")) }
    private func receipts(_ app: XCUIApplication) -> XCUIElementQuery { app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'searchReceipt-'")) }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable && element.frame.minY > 140 && element.frame.maxY < app.frame.height - 100 { return }
            let above = element.exists && element.frame.minY < 140
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.3 : 0.7)).press(forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.7 : 0.3)))
        }
        XCTAssertTrue(element.isHittable)
    }
    func testCleanFiltersCancelApplyAndSearchHistoryReturn() {
        let app = launch()
        XCTAssertFalse(app.staticTexts["Active only"].exists)
        XCTAssertFalse(app.buttons["searchMerchantFilter"].exists)
        capture(app, "clean-list")
        app.buttons["searchFilters"].tap()
        app.buttons["searchMerchantFilter"].tap(); app.buttons["FICTIONAL GROVE"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["searchResultCount"].label, "500 receipts")
        app.buttons["searchFilters"].tap()
        app.buttons["searchMerchantFilter"].tap(); app.buttons["FICTIONAL GROVE"].tap()
        app.buttons["searchMonthFilter"].tap(); app.buttons["September 2026"].tap()
        app.buttons["applySearchFilters"].tap()
        XCTAssertTrue(app.buttons["Remove filter: FICTIONAL GROVE"].waitForExistence(timeout: 5))
        search("milk", app: app)
        XCTAssertEqual(app.staticTexts["searchResultCount"].label, "167 receipts")
        capture(app, "filtered-item-search")
        for _ in 0..<2 { app.swipeUp() }
        guard let visible = results(app).allElementsBoundByIndex.first(where: { $0.isHittable && $0.frame.minY > 160 && $0.frame.maxY < 650 }) else {
            return XCTFail("Expected an exposed item result")
        }
        let identifier = visible.identifier
        let target = app.buttons[identifier]
        let before = target.frame
        target.tap(); XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["searchOriginal"].exists)
        XCTAssertFalse(app.staticTexts["Current receipt match"].exists)
        capture(app, "compact-search-context")
        app.buttons["searchPurchaseHistory"].tap()
        XCTAssertTrue(app.navigationBars["Purchase history"].waitForExistence(timeout: 10))
        app.buttons["closePurchaseHistory"].tap()
        app.buttons["back"].tap()
        let restored = app.buttons[identifier]
        XCTAssertTrue(restored.waitForExistence(timeout: 10)); XCTAssertTrue(restored.isHittable)
        XCTAssertEqual(restored.frame.minY, before.minY, accuracy: 12)
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "milk")
        app.terminate()
    }
    func testWalletListFollowsBrowsedPurchaseAndCollectionsAreDirect() {
        let app = XCUIApplication(); app.launchArguments = ["--t05-synthetic-preview", "wallet-months", "--t05-light"]
        app.launchEnvironment["SLIPLET_PREVIEW_COUNT"] = "50"; app.launch()
        XCTAssertTrue(app.staticTexts["50 saved"].waitForExistence(timeout: 90))
        app.buttons["allReceipts"].tap()
        XCTAssertTrue(app.buttons["receiptCollections"].waitForExistence(timeout: 10))
        for _ in 0..<3 { app.swipeUp() }
        let candidates = receipts(app).allElementsBoundByIndex.filter { $0.isHittable && $0.frame.minY > 160 && $0.frame.maxY < 650 }
        guard let target = candidates.first else { return XCTFail("Expected a visible receipt") }
        let iso = target.label.range(of: "[0-9]{4}-[0-9]{2}-[0-9]{2}", options: .regularExpression).map { String(target.label[$0]) }
        let identifier = target.identifier
        target.tap(); XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10)); app.buttons["back"].tap()
        app.buttons["walletTab"].tap()
        let papers = app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "receipt-[0-9]+"))
        XCTAssertTrue(papers.firstMatch.waitForExistence(timeout: 10))
        if let iso { XCTAssertTrue(papers.allElementsBoundByIndex.contains { $0.isHittable && $0.label.contains(iso) }) }
        capture(app, "wallet-from-list")
        app.buttons["allReceipts"].tap()
        XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 10))
        app.buttons["receiptCollections"].tap(); app.buttons["collection-Archive"].tap()
        XCTAssertEqual(app.staticTexts["searchResultCount"].label, "0 receipts")
        XCTAssertFalse(app.buttons["walletSettings"].exists)
        capture(app, "direct-archive")
        app.buttons["receiptCollections"].tap(); app.buttons["collection-All receipts"].tap()
        XCTAssertEqual(app.staticTexts["searchResultCount"].label, "50 receipts")
        app.terminate()
    }
    func testDateEditMovesMonthAndReturnsToTheSamePaper() {
        let app = XCUIApplication(); app.launchArguments = ["--t05-synthetic-preview", "many", "--t05-light"]
        app.launch(); XCTAssertTrue(app.staticTexts["30 saved"].waitForExistence(timeout: 60))
        let paper = app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "receipt-[0-9]+"))
            .allElementsBoundByIndex.first { $0.isHittable && $0.frame.minY > 160 && $0.frame.minY < 400 }
        guard let paper else { return XCTFail("Expected a readable wallet paper") }
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        let edit = app.buttons["edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: edit)
        waitForExpectations(timeout: 10)
        edit.tap()
        let date = app.buttons["dateField"]
        XCTAssertTrue(date.waitForExistence(timeout: 10))
        if !date.isHittable { app.swipeDown() }
        date.tap()
        let previous = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'previous month'")).firstMatch
        XCTAssertTrue(previous.waitForExistence(timeout: 5)); previous.tap()
        let day = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'September' AND label CONTAINS '15'")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5)); day.tap()
        app.buttons["confirmReceiptDate"].tap(); app.buttons["saveDraft"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10)); app.buttons["back"].tap()
        let updated = app.buttons.matching(NSPredicate(format: "identifier MATCHES %@ AND label CONTAINS '2026-09-15'", "receipt-[0-9]+" )).firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 10)); XCTAssertTrue(updated.isHittable)
        let position = updated.frame.minY
        updated.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10)); app.buttons["back"].tap()
        XCTAssertEqual(updated.frame.minY, position, accuracy: 3)
        app.buttons["walletMonths"].tap()
        XCTAssertTrue(app.buttons["walletMonth-2026-09"].exists)
        capture(app, "edited-date-month-index"); app.terminate()
    }
    func testLargeTextDarkSearchAndFiltersRemainReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "search", "--t05-dark", "--t05-large-text",
                               "--t05-reduce-motion", "--t05-opaque", "--t05-contrast"]
        app.launch()
        let searchButton = app.buttons["receiptSearch"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 30))
        searchButton.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
        search("creme", app: app)
        let filters = app.buttons["searchFilters"]
        XCTAssertTrue(filters.isHittable)
        XCTAssertEqual(filters.label, "Filters")
        try app.performAccessibilityAudit(for: [.hitRegion])
        let merchant = app.buttons["searchMerchantFilter"]
        let origin = app.coordinate(withNormalizedOffset: .zero)
        // SwiftUI's toolbar can report its smaller capsule as the AX frame.
        // Exercise the system's extended vertical hit zone directly.
        for verticalOffset in [-21.0, 21.0] {
            origin.withOffset(CGVector(dx: filters.frame.midX - app.frame.minX,
                                       dy: filters.frame.midY - app.frame.minY + verticalOffset)).tap()
            XCTAssertTrue(merchant.waitForExistence(timeout: 8))
            app.buttons["Cancel"].tap()
            XCTAssertTrue(merchant.waitForNonExistence(timeout: 8))
        }
        filters.tap()
        XCTAssertTrue(merchant.waitForExistence(timeout: 10))
        capture(app, "large-text-dark-filters")
        merchant.tap()
        app.buttons["FICTIONAL GROVE"].tap()
        app.buttons["applySearchFilters"].tap()
        let storeFilter = app.buttons["Remove filter: FICTIONAL GROVE"]
        XCTAssertTrue(storeFilter.waitForExistence(timeout: 10))
        let first = results(app).firstMatch
        reveal(first, app: app)
        capture(app, "large-text-dark-search")
        first.tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        let original = app.buttons["searchOriginal"]
        reveal(original, app: app)
        original.tap()
        let done = app.buttons["sourceDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 10))
        app.buttons["back"].tap()
        let query = app.searchFields.firstMatch
        XCTAssertTrue(query.waitForExistence(timeout: 10))
        XCTAssertEqual(query.value as? String, "creme")
        XCTAssertTrue(storeFilter.exists)
        app.terminate()
    }
}
