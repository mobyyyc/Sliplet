import XCTest

/// Uses the isolated, encrypted fictional store across only the currently shipped navigation.
@MainActor final class ReceiptWalletOrganizationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testTenReceipts() throws { try exerciseScale(10) }
    func testFiftyReceipts() throws { try exerciseScale(50) }
    func testTwoHundredReceipts() throws { try exerciseScale(200, olderDate: "2025-12-19") }
    func testThousandReceipts() throws { try exerciseScale(1000, olderDate: "2025-12-19") }

    private func exerciseScale(_ count: Int, olderDate: String? = nil) throws {
        let app = XCUIApplication()
        let appearance = count >= 200 ? "--t05-dark" : "--t05-light"
        app.launchArguments = ["--t05-synthetic-preview", "empty", appearance]
        app.launch()
        XCTAssertTrue(app.staticTexts["A place for your receipts"].waitForExistence(timeout: 60))
        app.terminate()

        app.launchArguments = ["--t05-synthetic-preview", "wallet-months", appearance]
        app.launchEnvironment["SLIPLET_PREVIEW_COUNT"] = String(count)
        app.launch()
        let saved = app.staticTexts["\(count.formatted()) saved"]
        XCTAssertTrue(saved.waitForExistence(timeout: 150))
        app.terminate()

        // Reopen the persisted fictional wallet so setup work and stale view anchors
        // from the previous scale cannot influence the cold-load sample.
        app.launchArguments = ["--t05-synthetic-preview", "resume", appearance]
        let launchStart = ProcessInfo.processInfo.systemUptime
        app.launch()
        XCTAssertTrue(saved.waitForExistence(timeout: 30))
        let launchReady = ProcessInfo.processInfo.systemUptime - launchStart
        let pocket = app.otherElements["walletPocket"]
        XCTAssertTrue(pocket.exists)
        let mountedBefore = papers(app).count
        XCTAssertGreaterThan(mountedBefore, 0)
        XCTAssertLessThanOrEqual(mountedBefore, 36)

        let scrollStart = ProcessInfo.processInfo.systemUptime
        app.coordinate(withNormalizedOffset: .init(dx: 0.49, dy: 0.32))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .init(dx: 0.49, dy: 0.64)))
        let mountedAfter = papers(app).count
        let dragAndSnapshot = ProcessInfo.processInfo.systemUptime - scrollStart
        XCTAssertGreaterThan(mountedAfter, 0)
        XCTAssertLessThanOrEqual(mountedAfter, 36)

        let preview = try XCTUnwrap(papers(app).allElementsBoundByIndex.last {
            $0.isHittable && $0.frame.minY >= 135 && $0.frame.minY + 38 < pocket.frame.minY
        })
        let previewY = preview.frame.minY
        let detailStart = ProcessInfo.processInfo.systemUptime
        preview.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.10)).tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 12))
        app.buttons["back"].tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 12))
        let walletRoundTrip = ProcessInfo.processInfo.systemUptime - detailStart
        XCTAssertEqual(preview.frame.minY, previewY, accuracy: 4)

        let overviewButton = app.buttons["walletPurchaseOverview"]
        XCTAssertGreaterThanOrEqual(overviewButton.frame.height, 44)
        let overviewStart = ProcessInfo.processInfo.systemUptime
        overviewButton.tap()
        let total = app.buttons["purchaseOverviewTotal-CAD"]
        XCTAssertTrue(total.waitForExistence(timeout: 15))
        let overviewOpen = ProcessInfo.processInfo.systemUptime - overviewStart
        XCTAssertTrue(total.label.contains("32.30"), total.label)
        XCTAssertTrue(total.label.contains("10 receipts"), total.label)
        total.tap()
        let drillDown = app.scrollViews["purchaseOverviewReceiptList"]
        XCTAssertTrue(drillDown.waitForExistence(timeout: 12))
        let row = drillDown.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "purchaseOverviewReceipt-")).firstMatch
        XCTAssertTrue(row.isHittable)
        let rowID = row.identifier
        row.tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 12))
        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons[rowID].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons[rowID].isHittable)
        app.navigationBars["Receipts"].buttons.firstMatch.tap()
        app.buttons["closePurchaseOverview"].tap()
        XCTAssertTrue(overviewButton.waitForExistence(timeout: 12))

        app.buttons["receiptSearch"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 12))
        let commonQuery = "organic milk"
        let searchStart = ProcessInfo.processInfo.systemUptime
        field.typeText(commonQuery + "\n")
        let resultCount = app.staticTexts["searchResultCount"]
        let expected = ["\(count) receipts", "\(count.formatted()) receipts"]
        let result = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label IN %@", expected), object: resultCount)
        wait(for: [result], timeout: 12)
        let searchReady = ProcessInfo.processInfo.systemUptime - searchStart
        if let olderDate {
            field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: commonQuery.count) + olderDate + "\n")
            let dated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "1 receipt"), object: resultCount)
            wait(for: [dated], timeout: 12)
        }

        let match = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "searchMatch-")).firstMatch
        XCTAssertTrue(match.isHittable)
        match.tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 12))
        if let olderDate {
            XCTAssertTrue(app.scrollViews["detailScreen"].staticTexts.matching(NSPredicate(format: "label CONTAINS %@", olderDate)).firstMatch.exists)
        }
        app.buttons["back"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 12))
        XCTAssertEqual(field.value as? String, olderDate ?? commonQuery)
        app.navigationBars["Search"].buttons.firstMatch.tap()
        XCTAssertTrue(overviewButton.waitForExistence(timeout: 12))

        let samples: [String: Double] = [
            "receiptCount": Double(count), "coldLaunchReadySeconds": launchReady,
            "mountedPapersBeforeDrag": Double(mountedBefore),
            "mountedPapersAfterDrag": Double(mountedAfter), "dragAndSnapshotSeconds": dragAndSnapshot,
            "walletRoundTripSeconds": walletRoundTrip, "overviewOpenSeconds": overviewOpen,
            "searchReadySeconds": searchReady
        ]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: samples, options: [.prettyPrinted, .sortedKeys]),
                                       uniformTypeIdentifier: "public.json")
        attachment.name = "P14-06-scale-\(count)"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }

    func testLongReceiptFromOverviewKeepsItsTotalClearOfTheActions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "long-wallet", "--t05-light", "--search-long-paper"]
        app.launch()
        XCTAssertTrue(app.staticTexts["3 saved"].waitForExistence(timeout: 60))
        app.buttons["walletPurchaseOverview"].tap()
        let total = app.buttons["purchaseOverviewTotal-CAD"]
        XCTAssertTrue(total.waitForExistence(timeout: 12))
        total.tap()
        let row = app.scrollViews["purchaseOverviewReceiptList"].buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "purchaseOverviewReceipt-", "382.54")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 12))
        let rowID = row.identifier
        row.tap()
        let edit = app.buttons["edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 12))
        let footer = app.descendants(matching: .any)["receiptPaperTotal"]
        for _ in 0..<12 {
            if footer.isHittable && footer.frame.maxY < edit.frame.minY - 12 { break }
            app.scrollViews["detailScreen"].swipeUp(velocity: .fast)
        }
        XCTAssertTrue(footer.isHittable)
        XCTAssertLessThan(footer.frame.maxY, edit.frame.minY - 12)
        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons[rowID].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons[rowID].isHittable)
    }

    private func papers(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "receipt-[0-9]+"))
    }
}
