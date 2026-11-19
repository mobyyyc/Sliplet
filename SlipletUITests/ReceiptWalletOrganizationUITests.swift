import XCTest

@MainActor final class ReceiptWalletOrganizationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ count: Int = 50, extra: [String] = [], dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--t05-synthetic-preview", "wallet-months"] + (dark ? [] : ["--t05-light"]) + extra
        app.launchEnvironment["SLIPLET_PREVIEW_COUNT"] = String(count)
        app.launch()
        XCTAssertTrue(app.staticTexts["\(count.formatted()) saved"].waitForExistence(timeout: 120))
        XCTAssertTrue(app.buttons["walletMonths"].waitForExistence(timeout: 10))
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func papers(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "receipt-[0-9]+"))
    }
    private func jump(_ app: XCUIApplication, _ month: String) {
        app.buttons["walletMonths"].tap()
        XCTAssertTrue(app.buttons["walletMonth-" + month].waitForExistence(timeout: 5))
        app.buttons["walletMonth-" + month].tap()
    }
    private func roundTrip(_ app: XCUIApplication) {
        let candidates = papers(app).allElementsBoundByIndex.filter { $0.isHittable && $0.frame.minY > 130 && $0.frame.minY < 420 }
        guard let paper = candidates.first else { XCTFail("An exposed paper must be reachable"); return }
        let before = paper.frame
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09)).tap()
        XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
        app.buttons["back"].tap()
        XCTAssertTrue(paper.waitForExistence(timeout: 10))
        XCTAssertEqual(paper.frame.minY, before.minY, accuracy: 2)
        XCTAssertEqual(paper.frame.minX, before.minX, accuracy: 2)
    }
    func testMonthNavigationSwitchAndRestoration() {
        let app = launch()
        let toggle = app.buttons["allReceipts"]
        XCTAssertEqual(toggle.frame.width, toggle.frame.height, accuracy: 2)
        XCTAssertGreaterThan(toggle.frame.midX, app.frame.width * 0.8)
        jump(app, "2026-09")
        XCTAssertTrue(app.buttons["walletSection-2026-09"].waitForExistence(timeout: 5))
        capture(app, "P14-02-month-boundary-light")
        roundTrip(app)
        let paper = papers(app).allElementsBoundByIndex.first { $0.isHittable && $0.frame.minY > 130 }
        let before = paper?.frame
        app.buttons["allReceipts"].tap()
        XCTAssertTrue(app.buttons["walletTab"].waitForExistence(timeout: 5))
        app.buttons["walletTab"].tap()
        if let paper, let before {
            XCTAssertTrue(paper.waitForExistence(timeout: 10))
            XCTAssertEqual(paper.frame.minY, before.minY, accuracy: 2)
        }
        jump(app, "undated")
        XCTAssertTrue(app.staticTexts["walletSection-undated"].waitForExistence(timeout: 5))
        capture(app, "P14-02-undated")
        app.terminate()
    }
    func testScaleKeepsMountedPapersBoundedAndAllMonthsReachable() {
        var measured: [[String: Int]] = []
        for count in [5, 50, 200, 1000] {
            let app = launch(count)
            let mounted = papers(app).count
            XCTAssertGreaterThan(mounted, 0)
            XCTAssertLessThanOrEqual(mounted, 36)
            jump(app, "2026-11")
            XCTAssertTrue(app.buttons["walletSection-2026-11"].waitForExistence(timeout: 5))
            XCTAssertLessThanOrEqual(papers(app).count, 36)
            if count >= 200 {
                app.buttons["walletMonths"].tap()
                app.buttons["walletYear"].tap()
                app.buttons["2025"].tap()
                app.buttons["walletMonth-2025-12"].tap()
                XCTAssertTrue(app.buttons["walletSection-2025-12"].waitForExistence(timeout: 5))
                roundTrip(app)
            }
            measured.append(["receipts": count, "mountedAtInitialPosition": mounted, "mountedAfterJump": papers(app).count])
            if count == 5 || count == 1000 { capture(app, "P14-02-\(count)-receipts") }
            app.terminate()
        }
        let attachment = XCTAttachment(data: try! JSONSerialization.data(withJSONObject: measured, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "P14-02-native-mounted-papers"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testDarkMonthNavigationAndReturn() {
        let app = launch(50, dark: true)
        jump(app, "2026-09")
        capture(app, "P14-02-month-boundary-dark")
        roundTrip(app)
        app.buttons["walletMonths"].tap()
        capture(app, "P14-02-month-picker-dark")
        app.buttons["Done"].tap()
        app.terminate()
    }
    func testLargeTextAndReducedMotionKeepMonthNavigationAndReturn() {
        let app = launch(50, extra: ["--t05-large-text", "--t05-reduce-motion", "--t05-opaque", "--t05-contrast"])
        XCTAssertTrue(app.buttons["allReceipts"].isHittable)
        jump(app, "2026-09")
        capture(app, "P14-02-accessibility-layout")
        let pocketTop = app.otherElements["walletPocket"].frame.minY
        let paper = papers(app).allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.minY > 120 && $0.frame.minY + 32 < min(500, pocketTop)
        }
        XCTAssertNotNil(paper)
        if let paper {
            let before = paper.frame
            paper.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 20)).tap()
            XCTAssertTrue(app.buttons["edit"].waitForExistence(timeout: 10))
            app.buttons["back"].tap()
            XCTAssertTrue(paper.waitForExistence(timeout: 10))
            XCTAssertEqual(paper.frame.minY, before.minY, accuracy: 2)
        }
        app.terminate()
    }
}
