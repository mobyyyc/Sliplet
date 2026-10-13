import XCTest
import Vision

/// Every launch explicitly selects the isolated fictional preview store. Never open normal receipts/Photos.
@MainActor final class ReceiptSearchUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ mode: String = "search", flags: [String] = ["--t05-light"]) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--t05-synthetic-preview", mode] + flags
        app.launch(); XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 60)); reveal(app.staticTexts["searchResultCount"], app: app); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "T07-" + name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func search(_ query: String, app: XCUIApplication) {
        let field = app.searchFields.firstMatch; XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap()
        if let text = field.value as? String, !text.isEmpty, text != "Merchant, item or SKU" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
        }
        field.typeText(query + "\n")
        reveal(app.staticTexts["searchResultCount"], app: app)
    }
    private func matches(_ app: XCUIApplication) -> XCUIElementQuery { app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'searchMatch-'")) }
    private func receipts(_ app: XCUIApplication) -> XCUIElementQuery { app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'searchReceipt-'")) }
    private func returnToResults(_ app: XCUIApplication) {
        app.buttons["back"].tap(); XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10)); reveal(app.staticTexts["searchResultCount"], app: app)
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<14 {
            if element.exists && element.isHittable && element.frame.midY > 130 && element.frame.midY < app.frame.height - 140 { return }
            let above = element.exists && element.frame.midY < 130
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.3 : 0.7)).press(forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.7 : 0.3)))
        }
        if !element.isHittable {
            capture(app, "fictional-unreachable-control")
            let tree = XCTAttachment(string: app.debugDescription); tree.name = "T07-fictional-unreachable-tree"; tree.lifetime = .keepAlways; add(tree)
        }
        XCTAssertTrue(element.isHittable)
    }
    func testHistoryDetailScrollsMatchContextWithLongPaper() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "long-wallet", "--t05-light"]
        app.launch()
        XCTAssertTrue(app.buttons["allReceipts"].waitForExistence(timeout: 30))
        app.buttons["allReceipts"].tap()
        search("milk", app: app)
        let first = matches(app).firstMatch
        reveal(first, app: app); first.tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        let original = app.buttons["searchOriginal"]
        XCTAssertTrue(original.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["walletHeading"].exists, "Search detail must not mount the home wallet")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'receipt-'" )).count, 0)
        let status = app.images["receiptReviewedMark"]
        XCTAssertGreaterThan(status.frame.minY, original.frame.maxY, "The match context must not cover the status")
        capture(app, "history-detail-top")
        let originalY = original.frame.minY
        let footer = app.descendants(matching: .any)["receiptPaperTotal"]
        reveal(footer, app: app)
        XCTAssertTrue(footer.isHittable, "The whole long receipt must remain scrollable")
        XCTAssertTrue(!original.isHittable || original.frame.minY < originalY - 100,
                      "Match context must scroll away with the receipt instead of staying over it")
        capture(app, "history-detail-bottom")
        reveal(original, app: app)
        XCTAssertGreaterThan(status.frame.minY, original.frame.maxY)
        original.tap(); XCTAssertTrue(app.buttons["sourceDone"].waitForExistence(timeout: 10))
        app.buttons["sourceDone"].tap()
        returnToResults(app)
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "milk", "Returning preserves the search")
        // Receipt-level results use the same reading view even without a match context.
        let receipt = receipts(app).firstMatch; reveal(receipt, app: app); receipt.tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["searchOriginal"].exists)
        XCTAssertFalse(app.staticTexts["walletHeading"].exists)
        reveal(app.descendants(matching: .any)["receiptPaperTotal"], app: app)
        returnToResults(app); app.terminate()
    }
    func testFictionalImageImportReviewSplitShareSearchAndEvidence() throws {
        let app = XCUIApplication(); app.launchArguments = ["--t05-synthetic-preview", "search-import", "--t05-light"]
        app.launch(); XCTAssertTrue(app.buttons["searchDemoImport"].waitForExistence(timeout: 30)); app.buttons["searchDemoImport"].tap()
        XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 30)); XCTAssertFalse(app.buttons["finishSave"].isEnabled)
        let merchant = app.textFields["merchantField"]; reveal(merchant, app: app); merchant.tap(); merchant.typeText("SYNTHETIC CORNER")
        if app.buttons["keyboardDone"].exists { app.buttons["keyboardDone"].tap() }
        app.buttons["original"].tap(); XCTAssertTrue(app.buttons["sourceDone"].waitForExistence(timeout: 10)); app.buttons["sourceDone"].tap()
        let check = app.switches["sourceCheck"]; reveal(check, app: app); check.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        if !app.buttons["finishSave"].isEnabled {
            capture(app, "fictional-import-finish-gate")
            let tree = XCTAttachment(string: app.debugDescription); tree.name = "T07-fictional-import-review-tree"; tree.lifetime = .keepAlways; add(tree)
        }
        XCTAssertTrue(app.buttons["finishSave"].isEnabled); app.buttons["finishSave"].tap()
        XCTAssertTrue(app.buttons["splitOpen"].waitForExistence(timeout: 10)); app.buttons["splitOpen"].tap()
        let name = app.textFields["splitName"]; reveal(name, app: app); name.tap(); name.typeText("Fictional Alex")
        let add = app.buttons["splitAddPerson"]; reveal(add, app: app); add.tap()
        if app.buttons["Dismiss keyboard"].exists { app.buttons["Dismiss keyboard"].tap() }
        let item = app.buttons["splitItem-0"]; reveal(item, app: app); item.tap()
        let owner = app.buttons["splitOwner-Fictional Alex"]; reveal(owner, app: app); owner.tap(); app.buttons["splitEditorBack"].tap()
        XCTAssertTrue(app.buttons["splitFinalize"].isEnabled); app.buttons["splitFinalize"].tap()
        let copy = app.buttons["splitCopy"]; reveal(copy, app: app); copy.tap()
        XCTAssertTrue(app.staticTexts["splitCopied"].waitForExistence(timeout: 10)); XCTAssertTrue(app.staticTexts["splitExactTotal"].label.contains("12.34"))
        let share = app.buttons["splitShare"]; reveal(share, app: app); share.tap(); capture(app, "fictional-import-native-share")
        let systemCopy = app.cells.matching(NSPredicate(format: "label == 'Copy'")).firstMatch
        XCTAssertTrue(systemCopy.waitForExistence(timeout: 10)); systemCopy.tap(); app.buttons["splitDone"].tap()
        app.buttons["back"].tap(); XCTAssertTrue(app.buttons["allReceipts"].waitForExistence(timeout: 10)); app.buttons["allReceipts"].tap()
        search("item", app: app); XCTAssertEqual(app.staticTexts["searchResultCount"].label, "1 receipt")
        let match = matches(app).firstMatch; reveal(match, app: app); match.tap()
        XCTAssertTrue(app.buttons["searchOriginal"].waitForExistence(timeout: 10)); app.buttons["searchOriginal"].tap()
        XCTAssertTrue(app.buttons["sourceDone"].waitForExistence(timeout: 10)); capture(app, "fictional-import-search-original")
        app.buttons["sourceDone"].tap(); app.terminate()
        app.launchArguments = ["--t05-synthetic-preview", "resume", "--t05-light"]; app.launch()
        XCTAssertTrue(app.buttons["allReceipts"].waitForExistence(timeout: 30)); app.buttons["allReceipts"].tap(); search("item", app: app)
        XCTAssertEqual(app.staticTexts["searchResultCount"].label, "1 receipt"); reveal(matches(app).firstMatch, app: app); matches(app).firstMatch.tap()
        XCTAssertTrue(app.buttons["splitOpen"].waitForExistence(timeout: 10)); app.buttons["splitOpen"].tap()
        reveal(app.buttons["splitCopy"], app: app); XCTAssertTrue(app.buttons["splitCopy"].exists); capture(app, "fictional-import-restarted-split"); app.terminate()
    }
    func testNativeCurrentRawSKUUnparsedAndRemovedEvidenceNavigation() throws {
        let app = launch(); XCTAssertEqual(app.staticTexts["searchResultCount"].label, "3 receipts")
        search("mlk", app: app); XCTAssertTrue(matches(app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(matches(app).firstMatch.label.contains("Original description")); capture(app, "original-description-results")
        reveal(matches(app).firstMatch, app: app); matches(app).firstMatch.tap(); let original = app.buttons["searchOriginal"]
        XCTAssertTrue(original.waitForExistence(timeout: 10)); reveal(original, app: app); original.tap()
        XCTAssertTrue(app.buttons["sourceDone"].waitForExistence(timeout: 10)); capture(app, "linked-original-evidence")
        app.buttons["sourceDone"].tap(); returnToResults(app)
        for (query, label) in [("milk", "Current purchase description"), ("old 123456", "Original SKU"), ("fennel", "not linked to a current purchase"), ("removed apples", "removed from current receipt")] {
            search(query, app: app); let match = matches(app).firstMatch
            reveal(match, app: app); XCTAssertTrue(match.waitForExistence(timeout: 10)); XCTAssertTrue(match.label.contains(label), match.label)
            if query == "removed apples" || query == "fennel" {
                XCTAssertFalse(match.label.contains("CAD")); capture(app, query == "fennel" ? "unparsed-source-result" : "removed-original-result")
                match.tap(); XCTAssertTrue(app.buttons["searchOriginal"].waitForExistence(timeout: 10))
                XCTAssertFalse(app.staticTexts["CAD 0.99"].exists)
                returnToResults(app)
            }
        }
        app.terminate(); app.launchArguments = ["--t05-synthetic-preview", "resume", "--t05-light"]; app.launch()
        XCTAssertTrue(app.buttons["allReceipts"].waitForExistence(timeout: 30)); app.buttons["allReceipts"].tap()
        search("milk", app: app); XCTAssertEqual(app.staticTexts["searchResultCount"].label, "3 receipts"); app.terminate()
    }
    func testNativeEditArchiveIncludeRestoreDeleteAndRelaunch() throws {
        let app = launch(); search("milk", app: app); reveal(matches(app).firstMatch, app: app); matches(app).firstMatch.tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10)); app.buttons["edit"].tap()
        let name = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'lineName-' AND value == 'Organic milk'")).firstMatch
        reveal(name, app: app); name.tap(); name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Organic milk".count) + "Fictional coffee")
        if app.buttons["keyboardDone"].exists { app.buttons["keyboardDone"].tap() }
        app.buttons["saveDraft"].tap(); XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10)); returnToResults(app)
        search("coffee", app: app); XCTAssertEqual(app.staticTexts["searchResultCount"].label, "1 receipt")
        reveal(matches(app).firstMatch, app: app); matches(app).firstMatch.tap(); XCTAssertTrue(app.buttons["receiptOptions"].waitForExistence(timeout: 10))
        app.buttons["receiptOptions"].tap(); app.buttons["Archive receipt"].tap()
        XCTAssertTrue(app.staticTexts["searchResultCount"].waitForExistence(timeout: 10)); XCTAssertEqual(app.staticTexts["searchResultCount"].label, "0 receipts")
        let include = app.switches["searchIncludeArchived"]; reveal(include, app: app); include.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(app.staticTexts["searchResultCount"].label, "1 receipt"); capture(app, "included-archive")
        reveal(matches(app).firstMatch, app: app); matches(app).firstMatch.tap(); app.buttons["receiptOptions"].tap(); app.buttons["Unarchive receipt"].tap()
        XCTAssertTrue(app.staticTexts["searchResultCount"].waitForExistence(timeout: 10)); reveal(matches(app).firstMatch, app: app); matches(app).firstMatch.tap()
        app.buttons["receiptOptions"].tap(); app.buttons["delete"].tap(); app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["edit"].exists); app.buttons["receiptOptions"].tap(); app.buttons["delete"].tap(); app.buttons["Delete receipt and original"].tap()
        XCTAssertTrue(app.staticTexts["searchResultCount"].waitForExistence(timeout: 10)); XCTAssertEqual(app.staticTexts["searchResultCount"].label, "0 receipts")
        app.terminate(); app.launchArguments = ["--t05-synthetic-preview", "resume", "--t05-light"]; app.launch()
        XCTAssertTrue(app.buttons["allReceipts"].waitForExistence(timeout: 30)); app.buttons["allReceipts"].tap()
        search("coffee", app: app); XCTAssertEqual(app.staticTexts["searchResultCount"].label, "0 receipts"); app.terminate()
    }
    func testNativeFiveHundredBrowseFiltersUnicodeAndSource() throws {
        let app = launch("search-large"); XCTAssertEqual(app.staticTexts["searchResultCount"].label, "500 receipts")
        capture(app, "500-history")
        for _ in 0..<4 { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(receipts(app).firstMatch.exists); capture(app, "500-scrolled-history")
        for _ in 0..<4 { app.swipeDown(velocity: .fast) }
        search("苹果", app: app); XCTAssertEqual(app.staticTexts["searchResultCount"].label, "500 receipts"); capture(app, "500-unicode-results")
        let store = app.buttons["searchMerchantFilter"]; reveal(store, app: app); store.tap(); app.buttons["FICTIONAL GROVE"].tap()
        XCTAssertEqual(app.staticTexts["searchResultCount"].label, "167 receipts")
        let month = app.buttons["searchMonthFilter"]; reveal(month, app: app); month.tap(); app.buttons["September 2026"].tap()
        XCTAssertEqual(app.staticTexts["searchResultCount"].label, "167 receipts"); capture(app, "500-filtered-results")
        let match = matches(app).firstMatch; reveal(match, app: app); match.tap()
        XCTAssertTrue(app.buttons["searchOriginal"].waitForExistence(timeout: 10)); app.buttons["searchOriginal"].tap()
        XCTAssertTrue(app.buttons["sourceDone"].waitForExistence(timeout: 10)); app.buttons["sourceDone"].tap(); returnToResults(app)
        app.terminate()
    }
    func testLargeTextReducedMotionDarkSearchAndStructuralAccessibility() throws {
        let app = launch(flags: ["--t05-large-text", "--t05-reduce-motion", "--t05-opaque", "--t05-contrast"])
        search("creme", app: app); XCTAssertEqual(app.staticTexts["searchResultCount"].label, "3 receipts")
        let match = matches(app).firstMatch; reveal(match, app: app); capture(app, "large-dark-search")
        XCTAssertGreaterThanOrEqual(match.frame.height, 44); match.tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        let original = app.buttons["searchOriginal"]; reveal(original, app: app); XCTAssertGreaterThanOrEqual(original.frame.height, 44)
        let status = app.images["receiptReviewedMark"]
        XCTAssertTrue(status.exists)
        let merchant = app.descendants(matching: .any)["detailScreen"].staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'FICTIONAL '")).firstMatch
        XCTAssertTrue(merchant.exists)
        XCTAssertTrue(status.isHittable)
        XCTAssertGreaterThanOrEqual(status.frame.minY, original.frame.maxY + 8,
                                   "The match context must clear the approved corner checkmark")
        XCTAssertGreaterThanOrEqual(status.frame.minY, merchant.frame.minY - 2)
        XCTAssertLessThanOrEqual(status.frame.maxY, merchant.frame.maxY + 2,
                                "The reviewed mark belongs inside the receipt header")
        XCTAssertEqual(status.label, "Reviewed and saved")
        XCTAssertFalse(app.staticTexts["Reviewed"].exists)
        capture(app, "large-dark-match-context")
        app.buttons["searchMatchDetails"].tap(); XCTAssertTrue(app.navigationBars["Match details"].waitForExistence(timeout: 10))
        capture(app, "large-dark-full-match-details"); app.buttons["Done"].tap(); original.tap(); XCTAssertTrue(app.buttons["sourceDone"].waitForExistence(timeout: 10)); app.buttons["sourceDone"].tap()
        returnToResults(app); app.terminate()
        let regular = launch(); search("milk", app: regular)
        try regular.performAccessibilityAudit(for: [.elementDetection, .hitRegion, .sufficientElementDescription]) { issue in
            print("P3_FICTIONAL_AX " + issue.detailedDescription + " element=" + (issue.element?.debugDescription ?? "none"))
            return false
        }
        capture(regular, "search-structure-audit"); regular.terminate()
    }
}
