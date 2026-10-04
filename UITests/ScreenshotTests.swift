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
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        let nein = app.buttons["Nein, nur auf dem iPhone"]
        if nein.waitForExistence(timeout: 8) {
            nein.tap()
        }
        let voll = app.buttons["Vollen Zugriff erlauben"]
        if voll.waitForExistence(timeout: 4) {
            voll.tap()
        }
        let englisch = app.buttons["Allow Full Access"]
        if englisch.waitForExistence(timeout: 2) {
            englisch.tap()
        }

        let video = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "grosses-video")).firstMatch
        let videoDa = video.waitForExistence(timeout: 150)
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
        XCTAssertTrue(videoDa, "grosses-video nicht sichtbar")
        XCTAssertTrue(bild.exists, "Bildschirmfoto nicht sichtbar")
        XCTAssertTrue(gleich.exists, "gleiches Bild nicht sichtbar")
        XCTAssertTrue(doppel.exists, "Doppelte Fotos nicht sichtbar")
        XCTAssertTrue(knopf.waitForExistence(timeout: 15), "Knopf freimachen fehlt")
    }
}
