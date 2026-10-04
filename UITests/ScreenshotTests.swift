import XCTest

final class ScreenshotTests: XCTestCase {
    func testAlleBildschirme() throws {
        let ziele = [
            "uebersicht": "bildschirm-uebersicht",
            "auswahl": "bildschirm-auswahl",
            "sichern": "bildschirm-sichern",
            "bestaetigen": "bildschirm-loeschen",
            "bericht": "bildschirm-bericht",
            "tipps": "bildschirm-tipps",
            "videos": "bildschirm-videos",
            "icloud": "bildschirm-icloud",
            "fehler": "bildschirm-fehler",
            "lauf": "bildschirm-lauf",
            "scan": "bildschirm-scan"
        ]
        for phase in ziele.keys.sorted() {
            let app = XCUIApplication()
            app.launchArguments = [
                "-ScreenshotModus",
                "-ScreenshotPhase=\(phase)",
                "-AppleLanguages", "(de)",
                "-AppleLocale", "de_DE"
            ]
            app.launch()
            let kennung = ziele[phase] ?? phase
            let gefunden = app.descendants(matching: .any)[kennung].waitForExistence(timeout: 25)
            let shot = XCUIScreen.main.screenshot()
            let ordner = URL(fileURLWithPath: "/tmp/aufraeumer-shots", isDirectory: true)
            try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: ordner.appendingPathComponent("\(phase).png"))
            let anhang = XCTAttachment(screenshot: shot)
            anhang.name = phase
            anhang.lifetime = .keepAlways
            add(anhang)
            XCTAssertTrue(gefunden, "Bildschirm \(phase) nicht sichtbar")
            app.terminate()
        }
    }
}
