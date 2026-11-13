import XCTest

@MainActor final class ReceiptAISettingsUITests: XCTestCase {
    func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists, element.isHittable, element.frame.midY < app.frame.maxY - 90, element.frame.midY > app.frame.minY + 120 { return }
            if element.exists && element.frame.midY < app.frame.minY + 120 { app.swipeDown() } else { app.swipeUp() }
        }
    }
    func testFictionalConnectionConsentAndDisconnect() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--p804-ai-settings-fixture"]
        app.launch()
        let settings = app.buttons["walletSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20)); settings.tap()
        let ai = app.buttons["aiRecognitionSettings"]
        XCTAssertTrue(ai.waitForExistence(timeout: 5)); ai.tap()
        let connect = app.buttons["connectGemini"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        let field = app.secureTextFields["geminiAPIKey"]
        XCTAssertFalse(field.exists)
        connect.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let verify = app.buttons["verifyAIConnection"]
        XCTAssertFalse(verify.isEnabled)
        field.tap(); field.typeText("FICTIONAL_UI_TEST_KEY_NOT_REAL\n")
        reveal(verify, in: app); verify.tap()

        let turnOn = app.buttons["turnOnAIRecognition"]
        XCTAssertTrue(turnOn.waitForExistence(timeout: 10))
        let management = app.buttons["manageAIConnection"].firstMatch
        XCTAssertTrue(management.exists)
        XCTAssertFalse(app.buttons["disconnectAI"].exists)
        turnOn.tap()
        let agree = app.buttons["agreeAndEnableAI"]
        XCTAssertTrue(agree.waitForExistence(timeout: 5)); agree.tap()
        let enable = app.switches["enableAIRecognition"]
        XCTAssertTrue(enable.waitForExistence(timeout: 5))
        XCTAssertEqual(enable.value as? String, "1")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Fictional AI Settings"; shot.lifetime = .keepAlways; add(shot)

        management.tap()
        let model = app.buttons["aiModelName"]
        XCTAssertTrue(model.waitForExistence(timeout: 5))
        reveal(model, in: app); model.tap()
        app.buttons["Gemini 3.6 Flash"].firstMatch.tap()
        XCTAssertTrue(verify.waitForExistence(timeout: 5))
        XCTAssertFalse(enable.exists); XCTAssertFalse(field.exists)
        verify.tap()
        XCTAssertTrue(turnOn.waitForExistence(timeout: 10)); turnOn.tap()
        XCTAssertTrue(enable.waitForExistence(timeout: 5))
        XCTAssertFalse(agree.exists)

        management.tap()
        let disconnect = app.buttons["disconnectAI"]; reveal(disconnect, in: app); disconnect.tap()
        app.buttons["Remove key from this device"].firstMatch.tap()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
    }
}
