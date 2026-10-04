import XCTest
@testable import AufraeumerKern

final class RegelnTests: XCTestCase {
    private func kat(_ k: Kandidat, _ s: Schwellen = Schwellen()) -> Set<Kategorie> {
        Regeln.kategorien(fuer: k, jetzt: T.jetzt, schwellen: s, kalender: T.kal)
    }

    func testGrossesVideoAbSchwelle() {
        XCTAssertEqual(kat(T.k("A", groesse: 60_000_000, video: true)), [.grosseVideos])
        XCTAssertEqual(kat(T.k("B", groesse: 50_000_000, video: true)), [.grosseVideos])
        XCTAssertTrue(kat(T.k("C", groesse: 49_999_999, video: true)).isEmpty)
    }

    func testFotoIstNieGrossesVideo() {
        XCTAssertTrue(kat(T.k("A", groesse: 900_000_000, video: false)).isEmpty)
    }

    func testUnbekannteGroesseWirdNichtAlsVideoAngeboten() {
        XCTAssertTrue(kat(T.k("A", groesse: 0, aufnahme: T.jahreher(5), video: true)).isEmpty)
    }

    func testNurCloudBleibtSichtbarAberOhneFreiplatz() {
        let k = T.k("B", groesse: 900_000_000, aufnahme: T.jahreher(5), video: true, lokal: false, nurCloud: true)
        XCTAssertEqual(kat(k), [.grosseVideos])
        XCTAssertFalse(Regeln.bringtPlatz(k))
        XCTAssertTrue(Regeln.bringtPlatz(T.k("C", groesse: 900_000_000, video: true)))
    }

    func testScreenshotWirdImmerGezaehlt() {
        XCTAssertEqual(kat(T.k("A", aufnahme: T.tageher(91), screenshot: true)), [.alteScreenshots])
        XCTAssertEqual(kat(T.k("B", aufnahme: T.tageher(1), screenshot: true)), [.alteScreenshots])
        XCTAssertEqual(kat(T.k("C", groesse: 0, screenshot: true, lokal: false)), [.alteScreenshots])
        XCTAssertEqual(kat(T.k("D", name: "Bildschirmfoto 2024.png")), [.alteScreenshots])
    }

    func testLangeVideosLiveRawAufnahmeUndWhatsApp() {
        XCTAssertEqual(kat(T.k("L", groesse: 2_000_000, video: true, dauer: 180)), [.langeVideos])
        XCTAssertTrue(kat(T.k("K", groesse: 2_000_000, video: true, dauer: 179)).isEmpty)
        XCTAssertEqual(kat(T.k("Live", live: true)), [.liveFotos])
        XCTAssertEqual(kat(T.k("Raw", raw: true)), [.rawFotos])
        XCTAssertEqual(kat(T.k("DNG", name: "Urlaub.DNG")), [.rawFotos])
        XCTAssertEqual(kat(T.k("Film", groesse: 8_000_000, video: true, bildschirmfilm: true)), [.bildschirmaufnahmen])
        XCTAssertEqual(
            kat(T.k("WA", groesse: 8_000_000, video: true, name: "VID-20240101-WA0001.mp4")),
            [.whatsAppVideos]
        )
        let gross = kat(T.k("Beide", groesse: 80_000_000, video: true, name: "WhatsApp Video.mp4"))
        XCTAssertEqual(gross, [.grosseVideos, .whatsAppVideos])
    }

    func testLangeUnberuehrtBrauchtAlleBedingungen() {
        XCTAssertEqual(kat(T.k("A", aufnahme: T.jahreher(3))), [.langeUnberuehrt])
        XCTAssertTrue(kat(T.k("B", aufnahme: T.jahreher(1))).isEmpty)
        XCTAssertTrue(kat(T.k("C", aufnahme: T.jahreher(3), favorit: true)).isEmpty)
        XCTAssertTrue(kat(T.k("D", aufnahme: T.jahreher(3), bearbeitet: true)).isEmpty)
        XCTAssertTrue(kat(T.k("E", aufnahme: T.jahreher(3), album: true)).isEmpty)
    }

    func testMehrereKategorienUndModus() {
        let k = kat(T.k("A", groesse: 60_000_000, aufnahme: T.jahreher(3), video: true))
        XCTAssertEqual(k, [.grosseVideos, .langeUnberuehrt])
        XCTAssertEqual(Regeln.modus(fuer: k), .erstSichern)
        XCTAssertEqual(Regeln.modus(fuer: [.alteScreenshots]), .nurLoeschen)
        XCTAssertEqual(Regeln.modus(fuer: [.duplikate]), .nurLoeschen)
        XCTAssertEqual(Regeln.modus(fuer: [.alteScreenshots, .langeUnberuehrt]), .erstSichern)
        XCTAssertEqual(Regeln.modus(fuer: []), .erstSichern)
    }

    func testEigeneSchwellen() {
        var s = Schwellen()
        s.grosseVideoBytes = 10
        XCTAssertEqual(kat(T.k("A", groesse: 10, video: true), s), [.grosseVideos])
    }

    func testSichernNoetigJeKategorie() {
        XCTAssertTrue(Kategorie.grosseVideos.sichernNoetig)
        XCTAssertTrue(Kategorie.langeUnberuehrt.sichernNoetig)
        XCTAssertFalse(Kategorie.duplikate.sichernNoetig)
        XCTAssertFalse(Kategorie.serienbilder.sichernNoetig)
        XCTAssertFalse(Kategorie.alteScreenshots.sichernNoetig)
        XCTAssertTrue(Kategorie.langeVideos.sichernNoetig)
        XCTAssertTrue(Kategorie.whatsAppVideos.sichernNoetig)
        XCTAssertTrue(Kategorie.liveFotos.sichernNoetig)
        XCTAssertFalse(Kategorie.alteScreenshots.sichernNoetig)
    }
}
