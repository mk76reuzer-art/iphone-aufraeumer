import XCTest
@testable import AufraeumerKern

final class DateiAblaufTests: XCTestCase {
    private func sichern(favorit: Bool = false) -> DateiAblauf {
        DateiAblauf(kandidat: T.k("A", video: true, favorit: favorit), modus: .erstSichern)
    }

    func testVollerWegMitSicherungErlaubtLoeschenErstAmEnde() throws {
        var a = sichern()
        XCTAssertFalse(a.loeschenErlaubt)
        try a.auswaehlen()
        try a.kopiert(bytes: 1000, pruefsumme: "s")
        XCTAssertFalse(a.loeschenErlaubt)
        try a.pruefen(originalBytes: 1000, originalPruefsumme: "s")
        XCTAssertEqual(a.zustand, .geprueft)
        XCTAssertFalse(a.loeschenErlaubt)
        try a.hochgeladen()
        XCTAssertFalse(a.loeschenErlaubt)
        try a.freigeben(favoritBestaetigt: false)
        XCTAssertTrue(a.loeschenErlaubt)
        try a.geloescht()
        XCTAssertEqual(a.zustand, .geloescht)
        XCTAssertTrue(a.istEnde)
    }

    func testNurLoeschenBrauchtKeineSicherungsstufen() throws {
        var a = DateiAblauf(kandidat: T.k("A", screenshot: true), modus: .nurLoeschen)
        try a.auswaehlen()
        try a.freigeben(favoritBestaetigt: false)
        XCTAssertTrue(a.loeschenErlaubt)
        try a.geloescht()
    }

    func testStufenKoennenNichtUebersprungenWerden() throws {
        var a = sichern()
        XCTAssertThrowsError(try a.freigeben(favoritBestaetigt: false))
        try a.auswaehlen()
        XCTAssertThrowsError(try a.freigeben(favoritBestaetigt: false))
        XCTAssertThrowsError(try a.hochgeladen())
        XCTAssertThrowsError(try a.geloescht())
        XCTAssertFalse(a.loeschenErlaubt)
    }

    func testNurLoeschenDarfNichtKopieren() throws {
        var a = DateiAblauf(kandidat: T.k("A"), modus: .nurLoeschen)
        try a.auswaehlen()
        XCTAssertThrowsError(try a.kopiert(bytes: 1, pruefsumme: "s"))
    }

    func testFalschePruefsummeBrichtAbUndSperrtLoeschen() throws {
        var a = sichern()
        try a.auswaehlen()
        try a.kopiert(bytes: 1000, pruefsumme: "kopie")
        XCTAssertThrowsError(try a.pruefen(originalBytes: 1000, originalPruefsumme: "original")) {
            XCTAssertEqual($0 as? AblaufFehler, .pruefsummeUngleich)
        }
        if case .abgebrochen = a.zustand {} else { XCTFail("Zustand sollte abgebrochen sein") }
        XCTAssertFalse(a.loeschenErlaubt)
        XCTAssertThrowsError(try a.hochgeladen())
        XCTAssertThrowsError(try a.freigeben(favoritBestaetigt: true))
    }

    func testFalscheGroesseBrichtAb() throws {
        var a = sichern()
        try a.auswaehlen()
        try a.kopiert(bytes: 999, pruefsumme: "s")
        XCTAssertThrowsError(try a.pruefen(originalBytes: 1000, originalPruefsumme: "s")) {
            XCTAssertEqual($0 as? AblaufFehler, .groesseUngleich)
        }
        XCTAssertFalse(a.loeschenErlaubt)
    }

    func testFavoritBrauchtAusdruecklicheBestaetigung() throws {
        var a = sichern(favorit: true)
        try a.auswaehlen()
        try a.kopiert(bytes: 1000, pruefsumme: "s")
        try a.pruefen(originalBytes: 1000, originalPruefsumme: "s")
        try a.hochgeladen()
        XCTAssertThrowsError(try a.freigeben(favoritBestaetigt: false)) {
            XCTAssertEqual($0 as? AblaufFehler, .favoritOhneBestaetigung)
        }
        XCTAssertFalse(a.loeschenErlaubt)
        XCTAssertEqual(a.zustand, .hochgeladen)
        try a.freigeben(favoritBestaetigt: true)
        XCTAssertTrue(a.loeschenErlaubt)
    }

    func testAbbrechenSperrtAlleWeiterenSchritteAberNichtNachDemLoeschen() throws {
        var a = sichern()
        try a.auswaehlen()
        try a.abbrechen(grund: "Nutzer hat es sich anders überlegt")
        XCTAssertEqual(a.zustand, .abgebrochen("Nutzer hat es sich anders überlegt"))
        XCTAssertThrowsError(try a.kopiert(bytes: 1, pruefsumme: "s"))
        XCTAssertThrowsError(try a.abbrechen(grund: "nochmal"))

        var b = DateiAblauf(kandidat: T.k("B"), modus: .nurLoeschen)
        try b.auswaehlen()
        try b.freigeben(favoritBestaetigt: false)
        try b.geloescht()
        XCTAssertThrowsError(try b.abbrechen(grund: "zu spät"))
        XCTAssertEqual(b.zustand, .geloescht)
    }

    func testGeloeschtNurAusFreigegeben() throws {
        var a = DateiAblauf(kandidat: T.k("A"), modus: .nurLoeschen)
        XCTAssertThrowsError(try a.geloescht())
        try a.auswaehlen()
        XCTAssertThrowsError(try a.geloescht())
    }
}
