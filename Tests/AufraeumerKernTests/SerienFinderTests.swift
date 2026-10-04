import XCTest
@testable import AufraeumerKern

final class SerienFinderTests: XCTestCase {
    func testDreiBilderEinerSerieEineGruppeAeltestesBleibt() {
        let eintraege = [
            (T.k("A", groesse: 100, aufnahme: T.tageher(10)), "serie-1"),
            (T.k("B", groesse: 110, aufnahme: T.tageher(5)), "serie-1"),
            (T.k("C", groesse: 120, aufnahme: T.tageher(1)), "serie-1"),
        ]
        let g = SerienFinder.gruppen(aus: eintraege)
        XCTAssertEqual(g, [DuplikatGruppe(behalten: "A", loeschbar: ["B", "C"])])
    }

    func testZweiBilderReichenNichtBeiMindestDrei() {
        let eintraege = [
            (T.k("A", groesse: 100), "serie-1"),
            (T.k("B", groesse: 100), "serie-1"),
        ]
        XCTAssertTrue(SerienFinder.gruppen(aus: eintraege, mindestAnzahl: 3).isEmpty)
        XCTAssertEqual(SerienFinder.gruppen(aus: eintraege, mindestAnzahl: 2).count, 1)
    }

    func testVideosWerdenIgnoriert() {
        let eintraege = (1...3).map { i in
            (T.k("\(i)", groesse: 100, video: true), "serie-v")
        }
        XCTAssertTrue(SerienFinder.gruppen(aus: eintraege).isEmpty)
    }

    func testNurCloudWirdTrotzdemGezaehlt() {
        let eintraege = [
            (T.k("A", groesse: 100, lokal: false), "s"),
            (T.k("B", groesse: 100, lokal: false), "s"),
            (T.k("C", groesse: 100, lokal: false), "s"),
        ]
        XCTAssertEqual(SerienFinder.gruppen(aus: eintraege).count, 1)
    }

    func testFavoritWirdBehalten() {
        let eintraege = [
            (T.k("A", groesse: 100, aufnahme: T.tageher(10)), "s"),
            (T.k("B", groesse: 100, aufnahme: T.tageher(20), favorit: true), "s"),
            (T.k("C", groesse: 100, aufnahme: T.tageher(1)), "s"),
        ]
        let g = SerienFinder.gruppen(aus: eintraege)
        XCTAssertEqual(g.first?.behalten, "B")
    }
}
