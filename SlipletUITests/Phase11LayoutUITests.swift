import XCTest

@MainActor final class Phase11LayoutUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Run at both standard and system accessibility sizes; screenshots verify visual wrapping.
    func testModelIdentityRemainsReadable() {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--p804-ai-settings-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["walletSettings"].waitForExistence(timeout: 30))
        app.buttons["walletSettings"].tap()
        let ai = app.buttons["aiRecognitionSettings"]
        for _ in 0..<12 {
            if ai.exists && ai.isHittable && ai.frame.midY < app.frame.height - 90 { break }
            app.swipeUp()
        }
        XCTAssertTrue(ai.isHittable); ai.tap()
        let model = app.staticTexts["aiModelName"]
        XCTAssertTrue(model.waitForExistence(timeout: 10))
        XCTAssertTrue(model.label.contains("Gemini 3.6 Flash"))
        XCTAssertTrue(model.isHittable)
        XCTAssertGreaterThanOrEqual(model.frame.minX, app.frame.minX + 16)
        XCTAssertLessThanOrEqual(model.frame.maxX, app.frame.maxX - 16)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Readable AI model identity"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }
}
