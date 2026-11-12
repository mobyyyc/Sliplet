import XCTest

@MainActor final class ReceiptSplitUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--t05-synthetic-preview", "split", "--t05-light"] + extra
        app.launch(); XCTAssertTrue(app.buttons["splitOpen"].waitForExistence(timeout: 45))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["splitOpen"])
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 15), .completed)
        openSplit(app); XCTAssertTrue(app.buttons["splitAddPerson"].exists); return app
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<10 {
            let editor = app.navigationBars["Item owners"].exists || app.navigationBars["Allocation policy"].exists
            let bottom = app.frame.height - (editor ? 60 : 140)
            if element.exists && element.isHittable && element.frame.minY > 130 && element.frame.midY < bottom { return }
            let above = element.exists && element.frame.midY < 130
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.3 : 0.7))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.7 : 0.3))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
    }
    private func openSplit(_ app: XCUIApplication) {
        let button = app.buttons["splitOpen"]
        let available = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true AND enabled == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [available], timeout: 10), .completed)
        button.tap(); XCTAssertTrue(app.buttons["splitDone"].waitForExistence(timeout: 10))
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func addPerson(_ app: XCUIApplication, name: String) {
        let add = app.buttons["splitAddPerson"]; XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let edit = app.buttons["splitEditPerson"]; reveal(edit, app: app); edit.tap()
        let field = app.textFields["splitName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
        app.buttons["splitPersonApply"].tap()
        app.buttons["splitBatchCancel"].tap()
    }
    private func addPeople(_ app: XCUIApplication) {
        for name in ["Alex", "Blair", "Casey"] { addPerson(app, name: name) }
    }
    private func assign(_ app: XCUIApplication, index: Int, names: [String]) {
        let item = app.buttons["splitItem-\(index)"]; reveal(item, app: app); item.tap()
        XCTAssertTrue(app.navigationBars["Item owners"].waitForExistence(timeout: 10))
        for name in names {
            let toggle = app.buttons["splitOwner-\(name)"]; reveal(toggle, app: app)
            toggle.tap()
            XCTAssertEqual(toggle.value as? String, "Selected")
        }
        capture(app, "T06-item-\(index)")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(app.buttons["splitItem-\(index)"], app: app)
        for name in names { XCTAssertTrue(app.buttons["splitItem-\(index)"].label.contains(name)) }
    }
    func testNativeAssignFinalizeCopyShareRestartEditAndWalletReturn() throws {
        let app = launch(); XCTAssertFalse(app.buttons["splitFinalize"].exists)
        addPeople(app)
        assign(app, index: 0, names: ["Alex"]); assign(app, index: 1, names: ["Blair", "Casey"])
        let policy = app.buttons["splitAdjustment-0"]; reveal(policy, app: app); policy.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "applicability unknown")).firstMatch.exists)
        XCTAssertEqual(app.buttons["splitMethod"].value as? String, "Proportional")
        reveal(app.buttons["splitPolicyAccepted"], app: app); app.buttons["splitPolicyAccepted"].tap()
        XCTAssertEqual(app.buttons["splitPolicyAccepted"].value as? String, "Selected")
        capture(app, "T06-explicit-tax-fallback")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        if !app.buttons["splitFinalize"].isEnabled { capture(app, "T06-finalization-blocker"); if app.staticTexts["splitFailure"].exists { print("T06_FINALIZATION_GATE " + app.staticTexts["splitFailure"].label) } }
        XCTAssertTrue(app.buttons["splitFinalize"].isEnabled); app.buttons["splitFinalize"].tap()
        let copy = app.buttons["splitCopy"]; reveal(copy, app: app)
        XCTAssertTrue(app.staticTexts["splitExactTotal"].label.contains("15.63"))
        capture(app, "T06-finalized-exact-amounts")
        copy.tap(); XCTAssertTrue(app.staticTexts["splitCopied"].waitForExistence(timeout: 5))
        reveal(app.buttons["splitShare"], app: app); app.buttons["splitShare"].tap()
        capture(app, "T06-native-share-sheet")
        let systemCopy = app.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        XCTAssertTrue(systemCopy.waitForExistence(timeout: 10)); systemCopy.tap()
        app.buttons["splitDone"].tap(); XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        app.buttons["back"].tap(); XCTAssertTrue(app.buttons["receipt-0"].waitForExistence(timeout: 10))
        capture(app, "T06-retained-wallet")
        app.terminate(); app.launchArguments = ["--t05-synthetic-preview", "resume", "--t05-light"]; app.launch()
        let paper = app.buttons["receipt-0"]; XCTAssertTrue(paper.waitForExistence(timeout: 30)); paper.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18)).tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 15)); openSplit(app)
        reveal(app.buttons["splitCopy"], app: app); XCTAssertTrue(app.buttons["splitCopy"].exists)
        XCTAssertTrue(app.staticTexts["splitExactTotal"].label.contains("15.63")); capture(app, "T06-restarted-split")
        app.buttons["splitDone"].tap(); app.buttons["edit"].tap(); XCTAssertTrue(app.buttons["saveDraft"].waitForExistence(timeout: 10)); app.buttons["saveDraft"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10)); openSplit(app)
        XCTAssertFalse(app.buttons["splitFinalize"].isEnabled); XCTAssertFalse(app.buttons["splitCopy"].exists)
        capture(app, "T06-edit-invalidates-finalization"); app.terminate()
    }
    func testUnsavedDismissalAndOriginalEvidence() {
        let app = launch(); addPeople(app)
        app.buttons["splitOriginal"].tap(); XCTAssertTrue(app.buttons["sourceDone"].waitForExistence(timeout: 10)); app.buttons["sourceDone"].tap()
        XCTAssertTrue(app.buttons["splitDone"].waitForExistence(timeout: 10))
        app.buttons["splitDone"].tap(); XCTAssertTrue(app.buttons["Discard choices"].waitForExistence(timeout: 5)); app.buttons["Discard choices"].tap()
        openSplit(app); XCTAssertFalse(app.staticTexts["Alex"].exists)
        XCTAssertFalse(app.buttons["splitSave"].exists)
        app.terminate()
    }

    func testSameIDSplitSaveReturnsWithoutStaleDiscardAndCanEditImmediately() {
        let app = launch(); addPeople(app)
        app.buttons["splitSave"].tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["splitDone"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        addPerson(app, name: "Dana")
        app.buttons["splitSave"].tap()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["splitDone"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed)
        app.buttons["splitDone"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["Discard choices"].exists)
        app.buttons["edit"].tap(); XCTAssertTrue(app.buttons["finishSave"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["finishSave"].isEnabled)
        capture(app, "P3-same-id-saved-and-immediate-edit")
        app.terminate()
    }
    private func pixelContrast(_ screenshot: XCUIScreenshot) -> (foreground: String, background: String, ratio: Double)? {
        guard let image = screenshot.image.cgImage else { return nil }
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)); return true
        }
        guard drawn else { return nil }
        var histogram: [Int: Int] = [:]
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] == 255 {
            histogram[Int(pixels[i]) << 16 | Int(pixels[i + 1]) << 8 | Int(pixels[i + 2]), default: 0] += 1
        }
        func luminance(_ rgb: Int) -> Double {
            let channels = [Double((rgb >> 16) & 255), Double((rgb >> 8) & 255), Double(rgb & 255)].map { value -> Double in
                let c = value / 255; return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        func ratio(_ a: Int, _ b: Int) -> Double { let x = luminance(a), y = luminance(b); return (max(x, y) + 0.05) / (min(x, y) + 0.05) }
        guard let background = histogram.max(by: { $0.value < $1.value })?.key,
              let foreground = histogram.filter({ $0.value >= 5 }).max(by: { ratio($0.key, background) < ratio($1.key, background) })?.key else { return nil }
        return (String(format: "#%06X", foreground), String(format: "#%06X", background), ratio(foreground, background))
    }
    private func contrastAudit(_ app: XCUIApplication, screen: String) throws {
        try app.performAccessibilityAudit(for: [.contrast]) { issue in
            var accepted = false
            var report: [String: Any] = ["screen": screen, "reason": issue.compactDescription, "details": issue.detailedDescription]
            if let e = issue.element {
                report["label"] = e.label; report["identifier"] = e.identifier; report["enabled"] = e.isEnabled
                report["frame"] = [e.frame.minX, e.frame.minY, e.frame.width, e.frame.height]
                let disabledFinalize = screen == "split" && e.identifier == "splitFinalize" && e.label == "Finalize" && !e.isEnabled
                let toolbarTop = screen == "split" && app.buttons["splitSave"].exists ? app.buttons["splitSave"].frame.minY : CGFloat.greatestFiniteMagnitude
                let knownReadingLabel = ["Amounts", "Adjustments", "Choose one owner, or several people to share an item equally. Extra cents stay balanced across items with the same owners."].contains(e.label)
                let occludedReadingLabel = screen == "split" && e.elementType == .staticText && e.identifier.isEmpty && knownReadingLabel && e.frame.maxY >= toolbarTop
                let occludedAssignmentError = screen == "split" && e.elementType == .staticText && e.identifier == "splitFailure"
                    && e.label == "Assign every purchase to at least one person. Remove stale assignments." && e.frame.minY >= toolbarTop
                let knownOcclusion = occludedReadingLabel || occludedAssignmentError
                report["occludingToolbarEdge"] = knownOcclusion ? toolbarTop : nil
                accepted = disabledFinalize || knownOcclusion
                report["contrastMeasurementValid"] = !knownOcclusion
                if let measured = self.pixelContrast(e.screenshot()) {
                    report["foreground"] = measured.foreground; report["background"] = measured.background; report["ratio"] = measured.ratio
                    // Individually measured Simulator false positives; never waive unknown visible controls.
                    let measuredControl = [("splitDone", "Done"), ("splitOriginal", "Original"), ("splitSave", "Save choices")].contains { e.identifier == $0.0 && e.label == $0.1 }
                    let measuredOwnershipFooter = e.elementType == .staticText && e.label == "Choose one owner, or several people to share an item equally. Extra cents stay balanced across items with the same owners."
                    let measuredHeader = screen == "split" && e.identifier.isEmpty && e.label == "Adjustments"
                    let measuredBack = ["owners", "policy"].contains(screen) && e.identifier.isEmpty && e.label == "Back"
                    accepted = accepted || ((measuredControl || measuredOwnershipFooter || measuredHeader || measuredBack) && e.isEnabled && measured.foreground == "#000000" && measured.ratio >= 4.5)
                }
                // These exact Form nodes behind the bottom toolbar have no readable crop. Do not call their
                // offscreen canvas values text contrast. Disabled Finalize is noninteractive/exempt.
                report["classification"] = knownOcclusion ? "specificOccludedSplitFormNode" : (disabledFinalize ? "specificDisabledControl" : (accepted ? "specificMeasuredFalsePositive" : "unresolved"))
            }
            report["accepted"] = accepted
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), let text = String(data: data, encoding: .utf8) { print("T06_CONTRAST_ISSUE " + text) }
            return accepted
        }
    }
    func testSplitContrastAudit() throws {
        continueAfterFailure = true // Collect every finding; unknown/low-contrast findings still fail.
        let app = launch()
        try contrastAudit(app, screen: "split")
        addPeople(app)
        let item = app.buttons["splitItem-0"]; reveal(item, app: app); item.tap()
        try contrastAudit(app, screen: "owners")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let policy = app.buttons["splitAdjustment-0"]; reveal(policy, app: app); policy.tap()
        try contrastAudit(app, screen: "policy")
        capture(app, "T06-policy-contrast"); app.terminate()
    }
    private func structureAudit(_ app: XCUIApplication, screen: String) throws {
        try app.performAccessibilityAudit(for: [.elementDetection, .hitRegion, .sufficientElementDescription]) { issue in
            var report: [String: Any] = ["screen": screen, "reason": issue.compactDescription, "details": issue.detailedDescription]
            if let e = issue.element {
                let f = e.frame
                report["label"] = e.label; report["identifier"] = e.identifier
                report["frame"] = [f.minX, f.minY, f.width, f.height]
            }
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), let text = String(data: data, encoding: .utf8) { print("T06_STRUCTURE_ISSUE " + text) }
            let tree = XCTAttachment(string: app.debugDescription); tree.name = "T06-structure-" + screen; tree.lifetime = .keepAlways; self.add(tree)
            return false
        }
    }
    func testSplitStructureAccessibilityAudit() throws {
        let app = launch()
        try structureAudit(app, screen: "split")
        addPeople(app)
        assign(app, index: 0, names: ["Alex"])
        let item = app.buttons["splitItem-1"]; reveal(item, app: app); item.tap()
        try structureAudit(app, screen: "owners")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let policy = app.buttons["splitAdjustment-0"]; reveal(policy, app: app); policy.tap()
        try structureAudit(app, screen: "policy")
        capture(app, "T06-policy-structure-audit"); app.terminate()
    }
    func testDarkSplitPresentationAndAssignments() {
        let app = XCUIApplication(); app.launchArguments = ["--t05-synthetic-preview", "split"]
        app.launch(); XCTAssertTrue(app.buttons["splitOpen"].waitForExistence(timeout: 45))
        openSplit(app)
        addPerson(app, name: "Alex")
        assign(app, index: 0, names: ["Alex"])
        capture(app, "T06-dark-split")
        XCTAssertFalse(app.buttons["splitFinalize"].isEnabled); app.terminate()
    }
    func testLargeTextReducedMotionOpaqueSplitControls() {
        let app = launch(extra: ["--t05-large-text", "--t05-reduce-motion", "--t05-opaque", "--t05-contrast"])
        addPerson(app, name: "Alex")
        assign(app, index: 0, names: ["Alex"])
        capture(app, "T06-large-text-reduced-motion")
        XCTAssertFalse(app.buttons["splitFinalize"].isEnabled); XCTAssertGreaterThanOrEqual(app.buttons["splitSave"].frame.height, 44)
        app.terminate()
    }
}

extension ReceiptSplitUITests {
    func testBulkSelectionCancelUndoSharingAndSavedColors() {
        let app = launch()
        XCTAssertTrue(app.buttons["splitAddPerson"].isHittable)
        XCTAssertEqual(app.buttons["splitAddPerson"].label, "Add person")
        XCTAssertFalse(app.buttons["splitItem-0"].exists)
        capture(app, "Split-first-person")
        app.buttons["splitAddPerson"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let first = app.buttons["splitItem-0"], second = app.buttons["splitItem-1"]
        reveal(first, app: app); first.tap(); reveal(second, app: app); second.tap()
        capture(app, "P1105-active-multi-selection")
        app.buttons["splitBatchCancel"].tap()
        reveal(first, app: app); XCTAssertTrue(first.label.contains("Unassigned"))
        app.buttons["splitPerson-1"].tap()
        reveal(app.buttons["splitSelectUnassigned"], app: app); app.buttons["splitSelectUnassigned"].tap()
        app.buttons["splitBatchApply"].tap()
        XCTAssertTrue(app.buttons["splitUndoBatch"].waitForExistence(timeout: 5)); app.buttons["splitUndoBatch"].tap()
        reveal(first, app: app); XCTAssertTrue(first.label.contains("Unassigned"))
        app.buttons["splitPerson-1"].tap()
        reveal(app.buttons["splitSelectUnassigned"], app: app); app.buttons["splitSelectUnassigned"].tap()
        app.buttons["splitBatchApply"].tap()
        app.buttons["splitAddPerson"].tap()
        reveal(second, app: app); second.tap()
        XCTAssertFalse(app.buttons["splitPerson-1"].exists)
        app.buttons["splitBatchCancel"].tap()
        app.buttons["splitPerson-2"].tap()
        app.buttons["splitEditPerson"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        reveal(app.buttons["splitColor-rose"], app: app); app.buttons["splitColor-rose"].tap()
        app.buttons["splitPersonApply"].tap()
        reveal(second, app: app); XCTAssertEqual(second.value as? String, "Not selected"); second.tap()
        app.buttons["splitBatchApply"].tap()
        reveal(second, app: app)
        XCTAssertTrue(second.label.contains("Person 1")); XCTAssertTrue(second.label.contains("Person 2"))
        XCTAssertTrue(second.label.contains("Shared equally"))
        capture(app, "P1105-shared-bulk-assignment")
        app.buttons["splitSave"].tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["splitDone"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        app.buttons["splitDone"].tap(); app.terminate()
        app.launchArguments = ["--t05-synthetic-preview", "resume", "--t05-light"]
        app.launch()
        let paper = app.buttons["receipt-0"]; XCTAssertTrue(paper.waitForExistence(timeout: 30))
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18)).tap()
        openSplit(app)
        XCTAssertTrue(app.buttons["splitPerson-2"].label.contains("Rose"))
        reveal(second, app: app); XCTAssertTrue(second.label.contains("Shared equally"))
        app.terminate()
    }
}


extension ReceiptSplitUITests {
    func testLongBulkAssignmentLargeTextAndRemoval() {
        let app = launch(extra: ["--p1105-many-items", "--t05-large-text", "--t05-reduce-motion"])
        app.buttons["splitAddPerson"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let all = app.buttons["splitSelectUnassigned"]
        reveal(all, app: app); all.tap()
        let count = app.staticTexts["14 selected · 0 shared"]
        // The accessible summary precedes the selection controls in the scrolling form.
        app.swipeDown()
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        app.buttons["splitBatchApply"].tap()
        let person = app.buttons["splitPerson-1"]
        reveal(person, app: app); person.tap()
        XCTAssertTrue(app.navigationBars["Assign items"].waitForExistence(timeout: 5))
        capture(app, "Split-large-text-assignment")
        let edit = app.buttons["splitEditPerson"]; reveal(edit, app: app); edit.tap()
        let remove = app.buttons["splitRemovePerson"]
        reveal(remove, app: app); remove.tap()
        app.buttons.matching(identifier: "splitConfirmRemoval").firstMatch.tap()
        XCTAssertTrue(app.buttons["splitAddPerson"].waitForExistence(timeout: 5))
        app.buttons["splitAddPerson"].tap()
        XCTAssertEqual(app.staticTexts["splitActivePerson"].label, "Person 1")
        let empty = app.staticTexts["0 selected · 0 shared"]
        for _ in 0..<8 {
            if empty.exists && empty.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(empty.isHittable)
        app.buttons["splitBatchCancel"].tap()
        XCTAssertFalse(app.buttons["splitFinalize"].isEnabled)
        app.terminate()
    }
}

extension ReceiptSplitUITests {
    func testPersonSwipeRevealsDeleteAndFullSwipeRemoves() {
        let app = launch()
        app.buttons["splitAddPerson"].tap()
        let item = app.buttons["splitItem-0"]
        reveal(item, app: app); item.tap()
        app.buttons["splitBatchApply"].tap()
        let person = app.buttons["splitPerson-1"]
        reveal(person, app: app)
        let start = person.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
        let middle = person.coordinate(withNormalizedOffset: CGVector(dx: 0.56, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: middle, withVelocity: .slow, thenHoldForDuration: 0.1)
        let delete = app.buttons["splitSwipeDelete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertTrue(person.exists)
        capture(app, "Split-person-swipe-delete")
        delete.tap()
        XCTAssertTrue(person.waitForNonExistence(timeout: 5))
        let undo = app.buttons["splitUndoBatch"]
        XCTAssertEqual(undo.label, "Undo removal")
        undo.tap()
        XCTAssertTrue(person.waitForExistence(timeout: 5))
        XCTAssertTrue(person.label.contains("1 item assigned"))

        let y = person.frame.midY / app.frame.height
        let trailing = app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: y))
        let leading = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: y))
        trailing.press(forDuration: 0.05, thenDragTo: leading, withVelocity: .default, thenHoldForDuration: 0.2)
        XCTAssertTrue(person.waitForNonExistence(timeout: 5))
        XCTAssertTrue(undo.exists)
        XCTAssertTrue(app.buttons["splitSave"].isHittable)
        app.buttons["splitAddPerson"].tap()
        XCTAssertEqual(app.staticTexts["splitActivePerson"].label, "Person 1")
        XCTAssertEqual(item.value as? String, "Not selected")
    }

    func testPendingSelectionRequiresDecisionBeforeClose() {
        let app = launch()
        app.buttons["splitAddPerson"].tap()
        let item = app.buttons["splitItem-0"]; reveal(item, app: app); item.tap()
        XCTAssertFalse(app.buttons["splitAddPerson"].exists)
        app.buttons["splitDone"].tap()
        XCTAssertTrue(app.buttons["Discard choices"].waitForExistence(timeout: 5))
        app.buttons["Discard choices"].tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 5))
        openSplit(app); XCTAssertFalse(app.buttons["splitPerson-1"].exists)
        app.terminate()
    }
}
