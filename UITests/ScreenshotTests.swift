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

    func testPruefenFindetEingespielteMedien() throws {
        let app = XCUIApplication()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        addUIInterruptionMonitor(withDescription: "Fotos erlauben") { alert in
            self.tippeErlauben(alert)
        }
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        tippe(app, "Nein, nur auf dem iPhone", 6)
        erlaubenTippen(app)
        erlaubenTippen(system)
        app.swipeUp()

        let video = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "grosses-video")).firstMatch
        var videoDa = video.waitForExistence(timeout: 45)
        if !videoDa, app.buttons["Erneut versuchen"].waitForExistence(timeout: 2) {
            app.buttons["Erneut versuchen"].tap()
            videoDa = video.waitForExistence(timeout: 45)
        }
        if videoDa {
            app.swipeUp()
        }

        let shot = XCUIScreen.main.screenshot()
        let ordner = URL(fileURLWithPath: "/tmp/aufraeumer-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: ordner.appendingPathComponent("pruefen-fund.png"))
        let anhang = XCTAttachment(screenshot: shot)
        anhang.name = "pruefen-fund"
        anhang.lifetime = .keepAlways
        add(anhang)

        let bild = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Bildschirmfoto")).firstMatch
        let gleich = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "gleich-a")).firstMatch
        let doppel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Doppelte Fotos")).firstMatch
        let knopf = app.descendants(matching: .any)["knopf-freimachen"]
        let sichtbar = app.staticTexts.allElementsBoundByIndex.prefix(25).map(\.label).joined(separator: " | ")
        XCTAssertTrue(videoDa, "grosses-video nicht sichtbar. Sichtbar: \(sichtbar)")
        XCTAssertTrue(bild.waitForExistence(timeout: 5), "Bildschirmfoto nicht sichtbar. Sichtbar: \(sichtbar)")
        XCTAssertTrue(gleich.exists, "gleiches Bild nicht sichtbar. Sichtbar: \(sichtbar)")
        XCTAssertTrue(doppel.exists, "Doppelte Fotos nicht sichtbar. Sichtbar: \(sichtbar)")
        XCTAssertTrue(knopf.waitForExistence(timeout: 15), "Knopf freimachen fehlt. Sichtbar: \(sichtbar)")
    }

    private func erlaubenTippen(_ app: XCUIApplication) {
        let titel = [
            "Vollen Zugriff erlauben",
            "Alle Fotos erlauben",
            "Allow Full Access",
            "Allow Access to All Photos"
        ]
        for name in titel {
            tippe(app, name, 1)
        }
    }

    private func tippeErlauben(_ alert: XCUIElement) -> Bool {
        let titel = [
            "Vollen Zugriff erlauben",
            "Alle Fotos erlauben",
            "Allow Full Access",
            "Allow Access to All Photos"
        ]
        for name in titel where alert.buttons[name].exists {
            alert.buttons[name].tap()
            return true
        }
        return false
    }

    private func tippe(_ app: XCUIApplication, _ titel: String, _ sekunden: TimeInterval) {
        let knopf = app.buttons[titel]
        if knopf.waitForExistence(timeout: sekunden) {
            knopf.tap()
        }
    }
}
