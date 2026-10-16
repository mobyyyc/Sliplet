import XCTest

@MainActor final class ReceiptRereadUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable && element.frame.midY < app.frame.maxY-100 { return }
            app.swipeUp()
        }
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "P405-unreachable-control"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(element.isHittable)
    }
    func testRegionReadingNestedCancelAndExplicitApply() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "correction-normal", "--t05-light", "--t05-reduce-motion"]
        app.launch(); XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 30))
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
        XCTAssertFalse(app.buttons["finishSave"].isEnabled, "Rereading is not full receipt review")
    }
    func testDrawRegionInDarkModeAndCancel() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "correction-normal", "--t05-dark", "--t05-reduce-motion"]
        app.launch(); XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 30))
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
