import XCTest

@MainActor final class ReceiptUploadUITests: XCTestCase {
    func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable && element.frame.midY < app.frame.maxY - 75 && element.frame.midY > app.frame.minY + 120 { return }
            app.swipeUp()
        }
    }
    func testPreviewRedactionConsentAndFictionalSend() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--p805-upload-fixture"]
        app.launch()
        let start = app.buttons["uploadFixture"]; XCTAssertTrue(start.waitForExistence(timeout: 20)); start.tap()
        let local = app.buttons["readLocal"]; XCTAssertTrue(local.waitForExistence(timeout: 5))
        app.buttons["previewAI"].tap()
        let review = app.buttons["reviewUpload"]; XCTAssertTrue(review.waitForExistence(timeout: 10))
        XCTAssertTrue(app.images["uploadImage"].waitForExistence(timeout: 5))
        try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/sliplet-p805-editor.png"))
        let draw = app.buttons["drawCovers"]; draw.tap()
        let image = app.images["uploadImage"]
        image.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.2)).press(forDuration: 0.1, thenDragTo: image.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.32)))
        review.tap()
        let send = app.buttons["sendReceiptAI"]; reveal(send, in: app); XCTAssertFalse(send.isEnabled)
        let consent = app.switches["uploadConsent"]; reveal(consent, in: app)
        consent.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        reveal(send, in: app); XCTAssertTrue(send.isEnabled)
        let edit = app.buttons["Edit covers"]; reveal(edit, in: app); edit.tap()
        review.tap(); reveal(send, in: app); XCTAssertFalse(send.isEnabled)
        reveal(consent, in: app); consent.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        reveal(send, in: app)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Fictional upload consent"; shot.lifetime = .keepAlways; add(shot)
        try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/sliplet-p805-preview.png"))
        send.tap()
        XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["finishSave"].isEnabled)
    }
    func testLightPreviewSurvivesOriginalSheet() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--p805-upload-fixture", "--t05-light"]
        app.launch()
        XCTAssertTrue(app.buttons["uploadFixture"].waitForExistence(timeout: 20)); app.buttons["uploadFixture"].tap()
        XCTAssertTrue(app.buttons["previewAI"].waitForExistence(timeout: 5)); app.buttons["previewAI"].tap()
        XCTAssertTrue(app.images["uploadImage"].waitForExistence(timeout: 10))
        app.buttons["original"].tap()
        XCTAssertTrue(app.buttons["sourceDone"].waitForExistence(timeout: 5)); app.buttons["sourceDone"].tap()
        XCTAssertTrue(app.images["uploadImage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["reviewUpload"].isEnabled)
        try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/sliplet-p806-light.png"))
    }
    func testAccessibilityTextKeepsBottomControlsWithinScreen() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--p805-upload-fixture", "--t05-large-text"]
        app.launch()
        XCTAssertTrue(app.buttons["uploadFixture"].waitForExistence(timeout: 20)); app.buttons["uploadFixture"].tap()
        let ai = app.buttons["previewAI"]; XCTAssertTrue(ai.waitForExistence(timeout: 5)); reveal(ai, in: app); ai.tap()
        let review = app.buttons["reviewUpload"]; XCTAssertTrue(review.waitForExistence(timeout: 10))
        let draw = app.buttons["drawCovers"]
        XCTAssertTrue(draw.isHittable); XCTAssertTrue(review.isHittable)
        for button in [draw, review] {
            XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
        }
        XCTAssertLessThanOrEqual(draw.frame.maxY, review.frame.minY)
        try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/sliplet-p806-large.png"))
    }

}
