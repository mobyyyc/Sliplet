import XCTest

@MainActor final class ReceiptShareUITests: XCTestCase {
    func testPreviewAndSystemShareSheet() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "long", "--discount-layout-fixture"]
        app.launch()
        let options = app.buttons["receiptOptions"]
        XCTAssertTrue(options.waitForExistence(timeout: 20)); options.tap()
        app.buttons["openReceiptShare"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Share receipt"].waitForExistence(timeout: 10))
        let preview = app.images["receiptShareImage"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertEqual(preview.label, "Receipt image preview")
        let zoom = app.buttons["receiptShareZoomIn"]
        XCTAssertTrue(zoom.isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Receipt image preview in Dark Mode"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["shareReceiptImage"].tap()
        XCTAssertTrue(app.buttons["Copy"].firstMatch.waitForExistence(timeout: 10) ||
                      app.cells["Copy"].firstMatch.exists ||
                      app.buttons["Save to Files"].firstMatch.exists)
    }
}
