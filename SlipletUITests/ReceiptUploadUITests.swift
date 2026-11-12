import XCTest

@MainActor final class ReceiptUploadUITests: XCTestCase {
    func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists {
                if ["sendReceiptAI", "reviewUpload", "readingMethodContinue", "adjustPhotoContinue"].contains(element.identifier), element.isHittable { return }
                if element.isHittable && element.frame.midY < app.frame.maxY - 75 && element.frame.midY > app.frame.minY + 120 { return }
                if element.frame.midY < app.frame.minY + 120 { app.swipeDown(); continue }
            }
            app.swipeUp()
        }
    }
    func testPreviewRedactionConsentAndFictionalSend() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--p805-upload-fixture"]
        app.launch()
        let start = app.buttons["uploadFixture"]; XCTAssertTrue(start.waitForExistence(timeout: 20)); start.tap()
        app.buttons["adjustPhotoContinue"].tap()
        let local = app.buttons["readLocal"]; XCTAssertTrue(local.waitForExistence(timeout: 5))
        app.buttons["previewAI"].tap(); app.buttons["readingMethodContinue"].tap()
        let review = app.buttons["reviewUpload"]; XCTAssertTrue(review.waitForExistence(timeout: 10))
        XCTAssertTrue(app.images["uploadImage"].waitForExistence(timeout: 5))
        try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/sliplet-p805-editor.png"))
        let draw = app.buttons["drawCovers"]; draw.tap()
        let image = app.images["uploadImage"]
        image.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.2)).press(forDuration: 0.1, thenDragTo: image.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.32)))
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.isEnabled); undo.tap(); XCTAssertFalse(undo.isEnabled)
        image.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.2)).press(forDuration: 0.1, thenDragTo: image.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.32)))
        review.tap()
        XCTAssertTrue(app.buttons["finalUploadPreview"].waitForExistence(timeout: 5))
        app.buttons["finalUploadPreview"].tap()
        app.buttons["Done"].tap()
        let send = app.buttons["sendReceiptAI"]; reveal(send, in: app); XCTAssertFalse(send.isEnabled)
        let consent = app.switches["uploadConsent"]; reveal(consent, in: app)
        consent.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        reveal(send, in: app); XCTAssertTrue(send.isEnabled)
        let edit = app.buttons["Edit hidden areas"]; reveal(edit, in: app); edit.tap()
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
        app.buttons["adjustPhotoContinue"].tap()
        XCTAssertTrue(app.buttons["previewAI"].waitForExistence(timeout: 5)); app.buttons["previewAI"].tap(); app.buttons["readingMethodContinue"].tap()
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
        app.buttons["adjustPhotoContinue"].tap()
        let ai = app.buttons["previewAI"]; XCTAssertTrue(ai.waitForExistence(timeout: 5)); reveal(ai, in: app); ai.tap(); app.buttons["readingMethodContinue"].tap()
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

extension ReceiptUploadUITests {
    private func sendAuditFixture(_ scenario: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--p805-upload-fixture", scenario, "--t05-light"]
        app.launch()
        for id in ["uploadFixture", "adjustPhotoContinue", "previewAI", "readingMethodContinue", "reviewUpload"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.waitForExistence(timeout: 20))
            button.tap()
        }
        let consent = app.switches["uploadConsent"]
        reveal(consent, in: app)
        consent.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let send = app.buttons["sendReceiptAI"]
        reveal(send, in: app)
        send.tap()
        return app
    }

    func testDiscountsAppearAtTheirConfirmedScope() {
        let app = sendAuditFixture("--linked-discounts-fixture")
        let paper = app.scrollViews["paperReview"]
        XCTAssertTrue(paper.waitForExistence(timeout: 10))
        func line(_ text: String) -> XCUIElement {
            paper.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-' AND label CONTAINS %@", text)).firstMatch
        }
        let item = line("FICTIONAL APPLES")
        let linked = line("-0.20")
        let basket = line("-0.10")
        let unclear = line("-0.05")
        let subtotal = paper.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Subtotal'")).firstMatch
        XCTAssertTrue(linked.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(linked.frame.midY, item.frame.midY)
        XCTAssertLessThan(linked.frame.midY, unclear.frame.midY)
        XCTAssertLessThan(unclear.frame.midY, subtotal.frame.midY)
        XCTAssertGreaterThan(basket.frame.midY, subtotal.frame.midY)
        linked.tap()
        XCTAssertTrue(app.buttons["discountScope"].waitForExistence(timeout: 5))
    }

    func testCleanReviewWithoutEditingFields() {
        let app = sendAuditFixture("--p901-clean-read")
        XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["paperReview"].exists)
        XCTAssertTrue(app.switches["sourceCheck"].isHittable)
        XCTAssertFalse(app.buttons["finishSave"].isEnabled)
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "Clean read before review"; before.lifetime = .keepAlways; add(before)
        app.buttons["original"].tap()
        app.buttons["sourceDone"].tap()
        let checked = app.switches["sourceCheck"]
        reveal(checked, in: app)
        checked.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["finishSave"].isEnabled)
        app.buttons["finishSave"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
    }

    func testLongPaperKeepsPositionDuringOriginalComparison() {
        let app = sendAuditFixture("--p902-long-read")
        let paper = app.scrollViews["paperReview"]
        XCTAssertTrue(paper.waitForExistence(timeout: 10))
        paper.swipeUp()
        let edgeShot = XCTAttachment(screenshot: app.screenshot())
        edgeShot.name = "Long paper review bottom edge"; edgeShot.lifetime = .keepAlways; add(edgeShot)
        let row = paper.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-'"))
            .allElementsBoundByIndex.first { $0.isHittable && $0.frame.midY > app.frame.midY }
        guard let row else { return XCTFail("Expected a visible purchase after scrolling") }
        let id = row.identifier
        let y = row.frame.midY
        app.buttons["original"].tap()
        app.buttons["sourceDone"].tap()
        let returned = paper.buttons[id]
        XCTAssertTrue(returned.isHittable)
        XCTAssertEqual(returned.frame.midY, y, accuracy: 3)
        returned.tap()
        for (identifier, label) in [("focusedUnit", "Unit"), ("focusedUnitPrice", "Unit price")] {
            let field = app.textFields[identifier]
            reveal(field, in: app)
            XCTAssertEqual(field.label, label)
            field.tap()
            let done = app.buttons["focusedKeyboardDone"]
            XCTAssertTrue(done.isHittable)
            done.tap()
            XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        }
        let quantity = app.textFields["focusedQuantity"]
        reveal(quantity, in: app)
        quantity.tap(); quantity.typeText("2")
        app.buttons["cancelFocusedCorrection"].tap()
        XCTAssertEqual(returned.frame.midY, y, accuracy: 3)
        XCTAssertFalse(returned.label.contains("Quantity 2"))
        returned.tap()
        reveal(quantity, in: app)
        quantity.tap(); quantity.typeText("3")
        app.buttons["applyFocusedCorrection"].tap()
        XCTAssertTrue(returned.label.contains("Quantity 3"))
        XCTAssertEqual(returned.frame.midY, y, accuracy: 3)
        XCTAssertEqual(paper.buttons.matching(NSPredicate(format: "label CONTAINS 'Quantity 3'")).count, 1)
        let check = app.switches["sourceCheck"]
        XCTAssertTrue(check.isHittable)
        check.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        app.buttons["finishSave"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        let reader = app.scrollViews["detailScreen"]
        let total = reader.descendants(matching: .any)["receiptPaperTotal"]
        for _ in 0..<14 {
            if total.isHittable && total.frame.maxY < app.buttons["edit"].frame.minY { break }
            reader.swipeUp()
        }
        XCTAssertTrue(total.isHittable)
        XCTAssertLessThan(total.frame.maxY, app.buttons["edit"].frame.minY)
    }

    func testSavedDetailLineCancelAndSaveDraft() {
        let app = XCUIApplication()
        continueAfterFailure = false
        app.launchArguments = ["--t05-synthetic-preview", "split", "--t05-light"]
        app.launch()
        let reader = app.scrollViews["detailScreen"]
        let row = reader.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        let id = row.identifier
        let original = row.label
        row.tap()
        app.buttons["editSavedLine"].tap()
        let quantity = app.textFields["focusedQuantity"]
        reveal(quantity, in: app)
        quantity.tap(); quantity.typeText("7")
        app.buttons["cancelFocusedCorrection"].tap()
        XCTAssertEqual(reader.buttons[id].label, original)
        reader.buttons[id].tap()
        app.buttons["editSavedLine"].tap()
        reveal(quantity, in: app)
        quantity.tap(); quantity.typeText("7")
        let save = app.buttons["applyFocusedCorrection"]
        XCTAssertEqual(save.label, "Save draft")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
        XCTAssertNotEqual(reader.buttons[id].label, original)
        XCTAssertTrue(app.staticTexts["Needs review"].exists)
        let tax = reader.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-' AND label BEGINSWITH 'Tax'")).firstMatch
        reveal(tax, in: app); tax.tap()
        let name = app.textFields["focusedLineName"]
        reveal(name, in: app)
        XCTAssertEqual(name.value as? String, "FICTIONAL TAX")
        XCTAssertFalse(app.textFields["focusedQuantity"].exists)
        app.buttons["applyFocusedCorrection"].tap()
        app.buttons["edit"].tap()
        XCTAssertFalse(app.buttons["finishSave"].isEnabled)
    }

    func testPaperAmountMismatchCanBeSavedAsDraft() {
        let app = sendAuditFixture("--p901-clean-read")
        let paper = app.scrollViews["paperReview"]
        let row = paper.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paperLine-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let amount = app.textFields["focusedLineAmount"]
        reveal(amount, in: app)
        amount.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "2.00")
        XCTAssertEqual(amount.value as? String, "2.00")
        app.buttons["applyFocusedCorrection"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["paperReviewIssue"].waitForExistence(timeout: 5))
        XCTAssertTrue(paper.exists)
        XCTAssertFalse(app.buttons["finishSave"].isEnabled)
        app.buttons["saveDraft"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
    }

    func testOfflineRecoveryPreviewsAgainBeforeSending() {
        let app = sendAuditFixture("--p904-offline")
        XCTAssertTrue(app.buttons["recoverLocal"].waitForExistence(timeout: 10))
        app.buttons["recoverPreview"].tap()
        let review = app.buttons["reviewUpload"]
        XCTAssertTrue(review.waitForExistence(timeout: 10))
        review.tap()
        let send = app.buttons["sendReceiptAI"]
        reveal(send, in: app)
        XCTAssertFalse(send.isEnabled)
    }

    func testFailedReadKeepsOriginalForManualEntry() {
        let app = sendAuditFixture("--p901-failed-read")
        let manual = app.buttons["manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 10))
        let failure = XCTAttachment(screenshot: app.screenshot())
        failure.name = "Read recovery"; failure.lifetime = .keepAlways; add(failure)
        app.buttons["original"].tap()
        app.buttons["sourceDone"].tap()
        manual.tap()
        XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 10))
    }
}

extension ReceiptUploadUITests {
    func testPhotoAdjustmentBackNavigationAndLocalReading() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--p805-upload-fixture", "--t05-light"]
        app.launch()
        XCTAssertTrue(app.buttons["uploadFixture"].waitForExistence(timeout: 20)); app.buttons["uploadFixture"].tap()
        let rotate = app.buttons["rotateImportPhoto"]
        XCTAssertTrue(rotate.waitForExistence(timeout: 10)); rotate.tap()
        app.buttons["adjustPhotoContinue"].tap()
        XCTAssertTrue(app.buttons["previewAI"].waitForExistence(timeout: 5))
        app.buttons["back"].tap()
        XCTAssertTrue(rotate.waitForExistence(timeout: 5))
        app.buttons["resetImportPhoto"].tap()
        app.buttons["adjustPhotoContinue"].tap()
        app.buttons["readLocal"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Import reading choices"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["readingMethodContinue"].tap()
        XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["sendReceiptAI"].exists)
    }
}


extension ReceiptUploadUITests {
    func testExplicitCropWithInsetCornersAndApply() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--p805-upload-fixture", "--t05-light"]
        app.launch()
        XCTAssertTrue(app.buttons["uploadFixture"].waitForExistence(timeout: 20)); app.buttons["uploadFixture"].tap()
        XCTAssertTrue(app.buttons["cropImportPhoto"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Check photo"].exists)
        XCTAssertTrue(app.staticTexts["Photo tips"].exists)
        app.buttons["cropImportPhoto"].tap()
        app.buttons["back"].tap()
        XCTAssertTrue(app.staticTexts["Check photo"].waitForExistence(timeout: 5))
        app.buttons["cropImportPhoto"].tap()
        let corner = app.descendants(matching: .any)["importHandle-0-4"]
        XCTAssertTrue(corner.waitForExistence(timeout: 5))
        XCTAssertTrue(corner.isHittable)
        XCTAssertGreaterThan(corner.frame.minX, 20)
        XCTAssertLessThan(corner.frame.maxX, app.frame.width - 20)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Inset white crop corners"; shot.lifetime = .keepAlways; add(shot)
        let start = corner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -45, dy: -30)))
        app.buttons["adjustPhotoContinue"].tap()
        XCTAssertTrue(app.staticTexts["Check photo"].waitForExistence(timeout: 5))
        XCTAssertFalse(corner.exists)
        app.buttons["adjustPhotoContinue"].tap()
        XCTAssertTrue(app.buttons["readLocal"].waitForExistence(timeout: 5))
    }
    func testReadingStatusVisibleAndCanStop() {
        let app = sendAuditFixture("--import-loading-fixture")
        XCTAssertTrue(app.buttons["cancelImport"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Reading receipt"].exists)
        XCTAssertTrue(app.staticTexts["Gemini is reading your photo"].exists)
        XCTAssertFalse(app.buttons["Details"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Reading status"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["cancelImport"].tap()
        XCTAssertTrue(app.buttons["recoverLocal"].waitForExistence(timeout: 10))
    }
}

extension ReceiptUploadUITests {
    func testStepsFitAndToolsKeepTheirAlignment() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet", "--p805-upload-fixture", "--t05-light"]
        app.launch()
        XCTAssertTrue(app.buttons["uploadFixture"].waitForExistence(timeout: 20)); app.buttons["uploadFixture"].tap()
        let photoNext = app.buttons["adjustPhotoContinue"]
        XCTAssertTrue(photoNext.waitForExistence(timeout: 10))
        let photoTip = app.staticTexts["Check that the receipt is sharp, upright and complete. Your original stays unchanged."]
        XCTAssertTrue(photoTip.isHittable)
        XCTAssertLessThan(photoTip.frame.maxY, photoNext.frame.minY)
        photoNext.tap()
        let explanation = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "On-device uses Apple Vision offline.")).firstMatch
        XCTAssertTrue(explanation.waitForExistence(timeout: 5))
        XCTAssertLessThan(explanation.frame.maxY, app.buttons["readingMethodContinue"].frame.minY)
        app.buttons["previewAI"].tap(); app.buttons["readingMethodContinue"].tap()
        let draw = app.buttons["drawCovers"], undo = app.buttons["Undo"], delete = app.buttons["Delete selected cover"]
        XCTAssertTrue(draw.waitForExistence(timeout: 5))
        let initial = draw.frame
        for tool in [undo, delete] {
            XCTAssertEqual(tool.frame.width, initial.width, accuracy: 1)
            XCTAssertEqual(tool.frame.height, initial.height, accuracy: 1)
            XCTAssertEqual(tool.frame.midY, initial.midY, accuracy: 1)
        }
        draw.tap()
        XCTAssertEqual(draw.frame.width, initial.width, accuracy: 1)
        XCTAssertEqual(draw.frame.midY, initial.midY, accuracy: 1)
        let tip = app.staticTexts["Drag over sensitive details. Use two fingers to move the photo. Keep items and prices visible."]
        XCTAssertTrue(tip.isHittable)
        XCTAssertLessThan(tip.frame.maxY, app.buttons["reviewUpload"].frame.minY)
        let tools = XCTAttachment(screenshot: app.screenshot()); tools.name = "Aligned drawing tools"; tools.lifetime = .keepAlways; add(tools)
        app.buttons["reviewUpload"].tap()
        let consent = app.switches["uploadConsent"]
        XCTAssertTrue(consent.waitForExistence(timeout: 5)); XCTAssertTrue(consent.isHittable)
        let edit = app.buttons["Edit hidden areas"]
        XCTAssertTrue(edit.isHittable)
        XCTAssertLessThan(edit.frame.maxY, app.buttons["sendReceiptAI"].frame.minY)
        let confirmation = XCTAttachment(screenshot: app.screenshot()); confirmation.name = "Single page upload confirmation"; confirmation.lifetime = .keepAlways; add(confirmation)
    }
}
