import XCTest

@MainActor final class ReceiptRereadUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            let exists = element.exists
            if exists && element.isHittable {
                if element.identifier == "rereadRun" { return }
                if element.frame.midY > app.frame.minY + 130 && element.frame.midY < app.frame.maxY - 100 { return }
            }
            let towardTop = exists && element.frame.midY < app.frame.minY + 130
            let focused = app.collectionViews["focusedCorrectionForm"]
            let surface = !app.buttons["rereadCancel"].exists && focused.isHittable ? focused : app
            let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: towardTop ? 0.32 : 0.68))
            let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: towardTop ? 0.68 : 0.32))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "P405-unreachable-control"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(element.isHittable)
    }
    private func openSuggestions(_ app: XCUIApplication) {
        let suggestions = app.buttons["reviewSuggestions"]
        XCTAssertTrue(suggestions.waitForExistence(timeout: 5))
        suggestions.tap()
    }

    func testUnassignedRowRequiresLineBeforeRereadAndCancelDiscardsNewLine() {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "correction-difficult", "--t05-light", "--t05-reduce-motion"]
        app.launch(); XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 30))
        let blocker = app.buttons["reviewBlocker"]
        let suggestions = app.buttons["reviewSuggestions"]
        if blocker.exists && suggestions.exists { XCTAssertLessThan(blocker.frame.minY, suggestions.frame.minY) }
        openSuggestions(app)
        let check = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Check unassigned amounts'")).firstMatch
        reveal(check, in: app); check.tap()
        let reread = app.buttons["focusedReread"]; reveal(reread, in: app)
        XCTAssertFalse(reread.isEnabled)
        let addPurchase = app.buttons["focusedAddPurchase"]
        app.swipeDown(); reveal(addPurchase, in: app); addPurchase.tap()
        reveal(reread, in: app); XCTAssertTrue(reread.isEnabled); reread.tap()
        XCTAssertTrue(app.buttons["rereadRun"].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "P505-unassigned-line-reread"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(app.staticTexts["Line amount"].exists)
        let target = app.descendants(matching: .any)["rereadField"].firstMatch
        let raster = app.images["rereadRaster"]
        XCTAssertTrue(raster.waitForExistence(timeout: 5))
        XCTAssertTrue(target.isHittable)
        XCTAssertLessThan(target.frame.minY, raster.frame.minY)
        app.buttons["rereadCancel"].tap(); app.buttons["cancelFocusedCorrection"].tap()
        reveal(check, in: app); check.tap(); reveal(reread, in: app)
        XCTAssertFalse(reread.isEnabled, "Outer Cancel must discard the selected new line")
        app.buttons["cancelFocusedCorrection"].tap(); XCTAssertFalse(app.buttons["finishSave"].isEnabled)
    }
    func testMissingSignedSubtotalOpensHighlightedFocusedEditorInDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "correction-summaries", "--t05-dark", "--t05-reduce-motion"]
        app.launch(); XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 30))
        openSuggestions(app)
        let check = app.buttons["reviewCheck-subtotal"]; reveal(check, in: app); check.tap()
        XCTAssertTrue(app.buttons["focusedReread"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No position is available for this check. Compare the full original."].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "P505-signed-summary-focused"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["focusedReread"].tap()
        XCTAssertTrue(app.buttons["rereadRun"].waitForExistence(timeout: 10)); XCTAssertTrue(app.staticTexts["Subtotal"].exists)
        app.buttons["rereadCancel"].tap(); app.buttons["cancelFocusedCorrection"].tap()
        XCTAssertFalse(app.buttons["finishSave"].isEnabled)
    }
    func testRegionReadingNestedCancelAndExplicitApply() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "correction-reread-unresolved-total", "--t05-light", "--t05-reduce-motion"]
        app.launch(); XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 30))
        openSuggestions(app)
        let check = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'reviewCheck-line-' ")).firstMatch
        reveal(check, in: app); check.tap()
        let reread = app.buttons["focusedReread"]; reveal(reread, in: app); reread.tap()
        XCTAssertTrue(app.buttons["rereadRun"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["rereadUse"].isEnabled)
        app.buttons["rereadCancel"].tap()
        XCTAssertTrue(app.buttons["cancelFocusedCorrection"].waitForExistence(timeout: 5))
        reveal(reread, in: app); reread.tap()
        let run = app.buttons["rereadRun"]; reveal(run, in: app); run.tap()
        let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'rereadChoice-' AND identifier CONTAINS ':4:amount'")).firstMatch
        reveal(choice, in: app); choice.tap(); XCTAssertTrue(app.buttons["rereadUse"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "P405-fictional-reading-choice"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["rereadUse"].tap()
        XCTAssertTrue(app.buttons["cancelFocusedCorrection"].waitForExistence(timeout: 5))
        let amount = app.textFields["focusedLineAmount"]; reveal(amount, in: app)
        XCTAssertEqual(amount.value as? String, "1.00")
        app.buttons["cancelFocusedCorrection"].tap()
        reveal(check, in: app); check.tap(); reveal(amount, in: app)
        XCTAssertNotEqual(amount.value as? String, "1.00", "Outer Cancel must discard the inner reread choice")
        app.swipeDown(); reveal(reread, in: app); reread.tap(); reveal(run, in: app); run.tap()
        reveal(choice, in: app); choice.tap(); XCTAssertTrue(app.buttons["rereadUse"].isEnabled); app.buttons["rereadUse"].tap()
        XCTAssertTrue(app.buttons["applyFocusedCorrection"].waitForExistence(timeout: 5)); app.buttons["applyFocusedCorrection"].tap()
        XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["finishSave"].isEnabled, "A line reread must leave the separate missing total unresolved")
        XCTAssertTrue(app.buttons["reviewBlocker"].label.contains("printed total"))
    }
    func testDrawRegionInDarkModeAndCancel() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "correction-normal", "--t05-dark", "--t05-reduce-motion"]
        app.launch(); XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 30))
        openSuggestions(app)
        let check = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'reviewCheck-line-' ")).firstMatch
        reveal(check, in: app); check.tap()
        let reread = app.buttons["focusedReread"]; reveal(reread, in: app); reread.tap()
        XCTAssertTrue(app.buttons["rereadZoomReset"].waitForExistence(timeout: 10))
        app.buttons["rereadZoomReset"].tap()
        app.buttons["rereadSelectArea"].tap()
        let raster = app.images["rereadRaster"]
        XCTAssertTrue(raster.waitForExistence(timeout: 5))
        raster.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.02))
            .press(forDuration: 0.1, thenDragTo: raster.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.98)))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "P405-fictional-dark-selection"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["rereadSelectArea"].tap()
        let run = app.buttons["rereadRun"]; reveal(run, in: app); run.tap()
        let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'rereadChoice-' AND identifier CONTAINS ':4:amount'")).firstMatch
        reveal(choice, in: app)
        XCTAssertFalse(app.buttons["rereadUse"].isEnabled)
        app.buttons["rereadCancel"].tap()
        XCTAssertTrue(app.buttons["cancelFocusedCorrection"].waitForExistence(timeout: 5))
        app.buttons["cancelFocusedCorrection"].tap()
        XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["finishSave"].isEnabled)
    }

}
