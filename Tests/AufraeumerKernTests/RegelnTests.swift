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

    func testUnbekannteGroesseOderNurCloudWirdNieAngeboten() {
        XCTAssertTrue(kat(T.k("A", groesse: 0, aufnahme: T.jahreher(5), video: true)).isEmpty)
        XCTAssertTrue(kat(T.k("B", groesse: 900_000_000, aufnahme: T.jahreher(5), video: true, lokal: false)).isEmpty)
    }

    func testScreenshotErstNachNeunzigTagen() {
        XCTAssertEqual(kat(T.k("A", aufnahme: T.tageher(91), screenshot: true)), [.alteScreenshots])
        XCTAssertTrue(kat(T.k("B", aufnahme: T.tageher(90), screenshot: true)).isEmpty)
        XCTAssertTrue(kat(T.k("C", aufnahme: T.tageher(89), screenshot: true)).isEmpty)
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
    }
}
