import XCTest

final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ScreenshotModus"]
    }

    func testAlleBildschirme() throws {
        for phase in ["uebersicht", "auswahl", "sichern", "bestaetigen", "bericht"] {
            app.launchArguments = ["-ScreenshotModus", "-ScreenshotPhase=\(phase)"]
            app.launch()
            sleep(1)
            let shot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = phase
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }
}
