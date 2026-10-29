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
        let field = app.secureTextFields["geminiAPIKey"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("FICTIONAL_UI_TEST_KEY_NOT_REAL\n")
        app.swipeUp()
        let ack = app.switches["aiTestAcknowledgement"]; reveal(ack, in: app); ack.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(ack.value as? String, "1")
        let verify = app.buttons["verifyAIConnection"]; reveal(verify, in: app)
        XCTAssertTrue(verify.isEnabled); verify.tap()
        let privacy = app.switches["aiPrivacyConfirmation"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 10)); reveal(privacy, in: app)
        let enable = app.switches["enableAIRecognition"]
        XCTAssertFalse(enable.isEnabled); privacy.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap(); reveal(enable, in: app)
        XCTAssertTrue(enable.isEnabled); enable.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(enable.value as? String, "1")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Fictional AI Settings"; shot.lifetime = .keepAlways; add(shot)
        try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/sliplet-p804-settings.png"))
        let disconnect = app.buttons["disconnectAI"]; reveal(disconnect, in: app); disconnect.tap()
        app.buttons["Remove key from this device"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
    }
}
