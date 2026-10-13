import XCTest

@MainActor final class ReceiptPhase3UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ mode: String = "one", light: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", mode] + (light ? ["--t05-light"] : []) + extra
        app.launch(); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "p3-fictional-" + name
        image.lifetime = .keepAlways; add(image)
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<18 {
            if element.exists && element.isHittable && element.frame.midY > 135 && element.frame.midY < app.frame.maxY - 150 { return }
            let form = app.collectionViews["reviewScreen"]
            if element.exists && element.frame.midY < 135 { form.swipeDown() } else { form.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }
    func testReverseSwipeClosesRevealedActionBeforeOppositeAction() {
        let app = launch(); let card = app.buttons["receipt-0"]
        XCTAssertTrue(card.waitForExistence(timeout: 30)); let center = card.frame.midX
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.14)).press(forDuration: 0.05, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.14)))
        let action = app.buttons["swipeAction-receipt-0"]
        XCTAssertTrue(action.waitForExistence(timeout: 5)); XCTAssertEqual(action.label, "Archive")
        capture(app, "left-action")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.14)).press(forDuration: 0.05, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.14)))
        XCTAssertTrue(action.waitForNonExistence(timeout: 5), "Reversing the current gesture closes; it must not expose Star")
        XCTAssertEqual(card.frame.midX, center, accuracy: 2)
        capture(app, "reverse-centered")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.14)).press(forDuration: 0.05, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.14)))
        XCTAssertTrue(action.waitForExistence(timeout: 5)); XCTAssertEqual(action.label, "Star")
        app.terminate()
    }
    func testOpeningUnchangedEditPreservesReviewAndCancelsWithoutDiscard() {
        let app = launch("review", extra: ["--t05-reduce-motion"])
        XCTAssertTrue(app.buttons["finishSave"].waitForExistence(timeout: 30))
        // XCTest retains noninteractive metadata for mounted, accessibility-hidden SwiftUI text.
        // Check interaction; physical VoiceOver navigation is a separate acceptance step.
        XCTAssertFalse(app.staticTexts["receiptPaperMerchant"].isHittable, "The retained reader must not receive interaction beneath the edit form")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'receipt-'")).count, 0)
        let check = app.switches["sourceCheck"]; reveal(check, app: app)
        capture(app, "existing-reviewed-edit")
        XCTAssertEqual(check.value as? String, "1", "Entering edit alone must preserve the saved source confirmation")
        XCTAssertTrue(app.buttons["finishSave"].isEnabled)
        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Discard changes"].exists)
        app.terminate()
    }
    func testRealEditRequiresFreshConfirmationAndDiscardButNoExtraOriginalVisit() {
        let app = launch("review", extra: ["--t05-reduce-motion"])
        XCTAssertTrue(app.buttons["finishSave"].waitForExistence(timeout: 30))
        let date = app.buttons["dateField"]; reveal(date, app: app); date.tap()
        XCTAssertTrue(app.buttons["confirmReceiptDate"].waitForExistence(timeout: 5)); app.buttons["confirmReceiptDate"].tap()
        XCTAssertTrue(app.buttons["confirmReceiptDate"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["finishSave"].isEnabled)
        let merchant = app.textFields["merchantField"]; reveal(merchant, app: app)
        merchant.tap(); merchant.typeText(" UPDATED")
        if app.buttons["keyboardDone"].exists { app.buttons["keyboardDone"].tap() }
        let check = app.switches["sourceCheck"]; reveal(check, app: app)
        XCTAssertEqual(check.value as? String, "0"); XCTAssertTrue(check.isEnabled)
        XCTAssertFalse(app.buttons["finishSave"].isEnabled)
        capture(app, "edited-needs-reconfirmation")
        app.buttons["back"].tap(); XCTAssertTrue(app.buttons["Discard changes"].waitForExistence(timeout: 5))
        app.buttons["Discard changes"].tap(); XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 5))
        app.terminate()
    }
    func testRevealedActionClosesEvenWhenOppositeSwipeIsDisabled() {
        let app = launch(); XCTAssertTrue(app.buttons["receipt-0"].waitForExistence(timeout: 30))
        app.buttons["walletSettings"].tap(); app.buttons["rightSwipeSetting"].tap(); app.buttons["None"].tap(); app.buttons["Done"].tap()
        let card = app.buttons["receipt-0"], action = app.buttons["swipeAction-receipt-0"]
        let center = card.frame.midX
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.14)).press(forDuration: 0.05, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.14)))
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.14)).press(forDuration: 0.05, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.14)))
        XCTAssertTrue(action.waitForNonExistence(timeout: 5)); XCTAssertEqual(card.frame.midX, center, accuracy: 2)
        app.terminate()
    }
    func testLargeDarkReviewActionsFitAndStorageCopyMatchesBackups() {
        let app = launch("review", light: false, extra: ["--t05-large-text", "--t05-reduce-motion", "--t05-opaque", "--t05-contrast"])
        let save = app.buttons["saveDraft"], finish = app.buttons["finishSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 30)); XCTAssertTrue(save.isHittable); XCTAssertTrue(finish.isHittable)
        for action in [save, finish] {
            XCTAssertGreaterThanOrEqual(action.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(action.frame.maxX, app.frame.maxX)
            XCTAssertGreaterThanOrEqual(action.frame.height, 44)
        }
        let footer = app.staticTexts["reviewStorageFooter"]; reveal(footer, app: app)
        XCTAssertTrue(footer.label.contains("encrypted backup")); XCTAssertFalse(footer.label.contains("no export"))
        capture(app, "large-dark-adaptive-actions")
        app.terminate()
    }

    func testUnchangedFinishReturnsDirectlyToReviewedReceipt() {
        let app = launch("review", extra: ["--t05-reduce-motion"])
        XCTAssertTrue(app.buttons["finishSave"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["finishSave"].isEnabled); app.buttons["finishSave"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["Discard changes"].exists)
        capture(app, "unchanged-finish-retains-receipt"); app.terminate()
    }

    func testEditingAndCancelRetainLongReaderScrollPosition() {
        let app = launch("long", extra: ["--t05-reduce-motion"])
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 30))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["edit"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        let total = app.descendants(matching: .any)["receiptPaperTotal"]
        for _ in 0..<10 {
            if total.exists && total.isHittable && total.frame.maxY < app.buttons["edit"].frame.minY - 12 { break }
            app.scrollViews["detailScreen"].swipeUp()
        }
        XCTAssertTrue(total.isHittable); let y = total.frame.minY
        capture(app, "reader-before-edit")
        app.buttons["edit"].tap(); XCTAssertTrue(app.buttons["finishSave"].waitForExistence(timeout: 5))
        app.buttons["back"].tap(); XCTAssertTrue(app.buttons["finishSave"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(total.isHittable); XCTAssertEqual(total.frame.minY, y, accuracy: 4)
        capture(app, "reader-after-edit-cancel"); app.terminate()
    }

    func testNativeScreenStructuralAccessibilityWithoutWaivers() throws {
        for mode in ["wallet", "detail", "review", "source", "library"] {
            let app = launch(mode)
            let target = mode == "wallet" ? "receipt-0" : mode == "detail" ? "edit" : mode == "review" ? "saveDraft" : mode == "source" ? "sourceDone" : "walletTab"
            XCTAssertTrue(app.buttons[target].waitForExistence(timeout: 30))
            try app.performAccessibilityAudit(for: [.elementDetection, .hitRegion, .sufficientElementDescription]) { issue in
                print("P3_FICTIONAL_STRUCTURE " + mode + " " + issue.detailedDescription + " element=" + (issue.element?.debugDescription ?? "none"))
                return false
            }
            capture(app, "structural-" + mode)
            app.terminate()
        }
    }

}
