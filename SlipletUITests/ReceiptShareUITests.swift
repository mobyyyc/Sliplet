import XCTest

@MainActor final class ReceiptShareUITests: XCTestCase {
    private func openPhotoSave() -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["--t05-synthetic-preview", "long", "--discount-layout-fixture"]
        app.launch()
        let share = app.buttons["openReceiptShare"]
        XCTAssertTrue(share.waitForExistence(timeout: 20)); share.tap()
        XCTAssertTrue(app.images["receiptShareImage"].waitForExistence(timeout: 10))
        let save = app.buttons["saveReceiptToPhotos"]
        XCTAssertTrue(save.isHittable)
        let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertFalse(permission.exists)
        save.tap()
        XCTAssertTrue(permission.waitForExistence(timeout: 10))
        return (app, permission)
    }

    func testSaveToPhotosPromptsOnFirstSaveAndSavesPreview() {
        continueAfterFailure = false
        let (app, permission) = openPhotoSave()
        let allow = permission.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Allow")).firstMatch
        XCTAssertTrue(allow.exists, permission.debugDescription)
        allow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["receiptSavedToPhotos"].firstMatch.waitForExistence(timeout: 12))
        XCTAssertTrue(app.images["receiptShareImage"].exists)
    }

    func testDeniedPhotosAccessKeepsShareAvailable() {
        continueAfterFailure = false
        let (app, permission) = openPhotoSave()
        let deny = permission.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Don")).firstMatch
        XCTAssertTrue(deny.exists, permission.debugDescription)
        deny.tap()
        let alert = app.alerts["Allow saving to Photos"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.buttons["Open Settings"].exists)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["shareReceiptImage"].isHittable)
        XCTAssertFalse(app.descendants(matching: .any)["receiptSavedToPhotos"].firstMatch.exists)
    }

    func testPreviewAndSystemShareSheet() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "long", "--discount-layout-fixture"]
        app.launch()
        let share = app.buttons["openReceiptShare"]
        XCTAssertTrue(share.waitForExistence(timeout: 20)); share.tap()
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

    func testLongPreviewFitsScrollsAndSavesToFiles() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "long", "--long-share-fixture", "--t05-light", "--t05-reduce-motion"]
        app.launch()
        let share = app.buttons["openReceiptShare"]
        XCTAssertTrue(share.waitForExistence(timeout: 20)); share.tap()
        let preview = app.images["receiptShareImage"]
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        let fullWidth = preview.frame.width
        app.buttons["Fit"].tap()
        XCTAssertLessThan(preview.frame.width, fullWidth / 2)
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "Long receipt fitted to screen"; overview.lifetime = .keepAlways; add(overview)

        app.buttons["Full width"].tap()
        XCTAssertEqual(preview.frame.width, fullWidth, accuracy: 5)
        let start = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.87))
        let end = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.14))
        for _ in 0..<18 {
            if (preview.value as? String)?.contains("position 100 percent") == true { break }
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        let footer = XCTAttachment(screenshot: app.screenshot())
        footer.name = "Long receipt total and signature"; footer.lifetime = .keepAlways; add(footer)
        XCTAssertTrue((preview.value as? String)?.contains("position 100 percent") == true,
                      "End position: \(preview.value ?? "unknown")")

        app.buttons["shareReceiptImage"].tap()
        let files = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        let more = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "View More")).firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10) || files.exists)
        if !files.isHittable && more.isHittable { more.tap() }
        for _ in 0..<4 where !files.isHittable { app.swipeUp() }
        let activities = XCTAttachment(screenshot: app.screenshot())
        activities.name = "Native share actions"; activities.lifetime = .keepAlways; add(activities)
        XCTAssertTrue(files.isHittable)
        files.tap()
        let save = app.buttons["DOCPicker.actionButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        let onDevice = app.staticTexts["On My iPhone"]
        if !onDevice.exists {
            let browse = app.buttons["Browse"].firstMatch
            if browse.isHittable { browse.tap() }
            XCTAssertTrue(onDevice.waitForExistence(timeout: 10))
            onDevice.tap()
        }
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.exists)
        filename.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        if let value = filename.value as? String {
            filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        filename.typeText("Sliplet-P1303-" + String(UUID().uuidString.prefix(8)))
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
    }

}
