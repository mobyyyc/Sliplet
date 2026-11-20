import XCTest

@MainActor final class ReceiptPurchaseOverviewUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testWalletAndListOpenMonthlyTotalsAndReceiptReturnsToSameMerchant() {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--t05-light", "--today-wallet"]
        app.launch()
        let entry = app.buttons["walletSection-today"]
        XCTAssertTrue(entry.waitForExistence(timeout: 60))
        entry.tap()

        let total = app.descendants(matching: .any)["purchaseOverviewTotal-CAD"].firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 10))
        XCTAssertTrue(total.label.contains("CAD"))
        capture(app, "purchase-overview-light")
        total.tap()
        let receipt = receiptRows(app).firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 10))
        app.navigationBars["Receipts"].buttons.firstMatch.tap()

        let merchant = app.descendants(matching: .any)["purchaseOverviewMerchant-CAD-SYNTHETIC CORNER"].firstMatch
        XCTAssertTrue(merchant.waitForExistence(timeout: 10))
        merchant.tap()
        XCTAssertTrue(receipt.waitForExistence(timeout: 10))
        receipt.tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["original"].exists)
        app.buttons["back"].tap()

        XCTAssertTrue(app.navigationBars["SYNTHETIC CORNER"].waitForExistence(timeout: 10))
        XCTAssertTrue(receipt.waitForExistence(timeout: 10))
        app.navigationBars["SYNTHETIC CORNER"].buttons.firstMatch.tap()
        XCTAssertTrue(total.waitForExistence(timeout: 10))
        app.buttons["closePurchaseOverview"].tap()

        app.buttons["walletSettings"].tap()
        app.buttons["receiptDisplayMode"].tap()
        app.buttons["List"].tap()
        app.buttons["Done"].tap()
        let listEntry = app.buttons["listOverview-today"]
        XCTAssertTrue(listEntry.waitForExistence(timeout: 10))
        listEntry.tap()
        XCTAssertTrue(total.waitForExistence(timeout: 10))

        let month = app.buttons["purchaseOverviewMonth"]
        month.tap()
        let earlierMonth = app.buttons.matching(NSPredicate(
            format: "label == %@ AND identifier != %@", "October 2026", "listOverview-2026-10")).firstMatch
        XCTAssertTrue(earlierMonth.waitForExistence(timeout: 5))
        earlierMonth.tap()
        XCTAssertEqual(month.value as? String, "October 2026")
    }

    func testDrillDownRestoresAScrolledReceiptInDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "many", "--t05-dark"]
        app.launch()
        XCTAssertTrue(app.staticTexts["30 saved"].waitForExistence(timeout: 60))
        let entry = app.buttons["walletPurchaseOverview"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()

        let total = app.buttons["purchaseOverviewTotal-CAD"]
        XCTAssertTrue(total.waitForExistence(timeout: 10))
        total.tap()
        let rows = receiptRows(app)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 3, "Only the receipts included in the total should appear at first")
        XCTAssertTrue(app.staticTexts["purchaseOverviewDrillMonth"].exists)
        let copies = app.buttons["purchaseOverviewCopies"]
        XCTAssertTrue(copies.isHittable)
        copies.tap()
        app.scrollViews["purchaseOverviewReceiptList"].swipeUp()
        guard let target = rows.allElementsBoundByIndex.first(where: {
            $0.label.contains("Duplicate copy") && $0.isHittable && $0.frame.minY > 140 && $0.frame.maxY < 650
        }) else { return XCTFail("Expected a visible duplicate below the initial scroll position") }
        let targetID = target.identifier
        capture(app, "purchase-overview-drilldown-dark")
        target.tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        app.buttons["back"].tap()
        let restored = app.buttons[targetID]
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        XCTAssertTrue(restored.isHittable)
    }

    func testUndatedReceiptsRemainReachableAtTheLargestTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--t05-light", "--t05-large-text", "--t05-reduce-motion", "--p1405-undated"]
        app.launch()
        let entry = app.buttons["walletPurchaseOverview"]
        XCTAssertTrue(entry.waitForExistence(timeout: 60))
        XCTAssertGreaterThanOrEqual(entry.frame.height, 44)
        entry.tap()
        XCTAssertTrue(app.navigationBars["Date unavailable"].waitForExistence(timeout: 10))
        let receipt = receiptRows(app).firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 10))
        XCTAssertTrue(receipt.isHittable)
        XCTAssertGreaterThan(receipt.frame.height, 150, "The sheet must inherit accessibility-size receipt text")
        capture(app, "undated-large-text")
        app.navigationBars["Date unavailable"].buttons.firstMatch.tap()
        let month = app.buttons["purchaseOverviewMonth"]
        XCTAssertTrue(month.waitForExistence(timeout: 10))
        XCTAssertTrue(month.isHittable)
        XCTAssertGreaterThan(month.frame.height, 72, "The selected month should wrap onto its own line")
        capture(app, "overview-large-text")
        let undated = app.buttons["purchaseOverviewUndated"]
        for _ in 0..<4 where !undated.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(undated.isHittable)
        XCTAssertFalse(app.buttons["purchaseOverviewTotal-CAD"].exists)
    }

    private func receiptRows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "purchaseOverviewReceipt-"))
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
