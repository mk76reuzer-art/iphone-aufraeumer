import XCTest
@testable import AufraeumerKern

final class DuplikatFinderTests: XCTestCase {
    private func summen(_ m: [String: String]) -> (String) throws -> String {
        { id in m[id] ?? "einzigartig-\(id)" }
    }

    func testGleicheGroesseUndSummeBildenGruppeAeltestesBleibt() throws {
        let a = T.k("A", groesse: 500, aufnahme: T.tageher(10), video: true)
        let b = T.k("B", groesse: 500, aufnahme: T.tageher(5), video: true)
        let g = try DuplikatFinder.gruppen(aus: [b, a], pruefsumme: summen(["A": "x", "B": "x"]))
        XCTAssertEqual(g, [DuplikatGruppe(behalten: "A", loeschbar: ["B"])])
        XCTAssertEqual(g[0].alleIds, ["A", "B"])
    }

    func testGleicheGroesseAberAndereSummeIstKeinDuplikat() throws {
        let a = T.k("A", groesse: 500)
        let b = T.k("B", groesse: 500)
        let g = try DuplikatFinder.gruppen(aus: [a, b], pruefsumme: summen(["A": "x", "B": "y"]))
        XCTAssertTrue(g.isEmpty)
    }

    func testUnterschiedlicheGespeicherteDauerStehtDerErkennungNichtImWeg() throws {
        // An echten Daten beobachtet: byte-gleiche Dateien, aber verschiedene gespeicherte Dauer.
        let a = T.k("A", groesse: 800_000, aufnahme: T.tageher(9), video: true, dauer: 3234.2)
        let b = T.k("B", groesse: 800_000, aufnahme: T.tageher(9), video: true, dauer: 222.4)
        let g = try DuplikatFinder.gruppen(aus: [a, b], pruefsumme: summen(["A": "x", "B": "x"]))
        XCTAssertEqual(g.count, 1)
    }

    func testFavoritWirdBehaltenAuchWennJuenger() throws {
        let a = T.k("A", groesse: 500, aufnahme: T.tageher(10))
        let b = T.k("B", groesse: 500, aufnahme: T.tageher(1), favorit: true)
        let g = try DuplikatFinder.gruppen(aus: [a, b], pruefsumme: summen(["A": "x", "B": "x"]))
        XCTAssertEqual(g, [DuplikatGruppe(behalten: "B", loeschbar: ["A"])])
    }

    func testDreiKopienErgebenEineGruppe() throws {
        let ks = ["C", "A", "B"].enumerated().map { i, id in T.k(id, groesse: 500, aufnahme: T.tageher(10 - i)) }
        let g = try DuplikatFinder.gruppen(aus: ks, pruefsumme: summen(["A": "x", "B": "x", "C": "x"]))
        XCTAssertEqual(g.count, 1)
        XCTAssertEqual(g[0].alleIds.count, 3)
        XCTAssertEqual(g[0].loeschbar.count, 2)
        XCTAssertFalse(g[0].loeschbar.contains(g[0].behalten))
    }

    func testUngueltigeWerdenIgnoriert() throws {
        let a = T.k("A", groesse: 0)
        let b = T.k("B", groesse: 0)
        let c = T.k("C", groesse: 500, lokal: false)
        let d = T.k("D", groesse: 500, lokal: false)
        let g = try DuplikatFinder.gruppen(aus: [a, b, c, d], pruefsumme: { _ in "x" })
        XCTAssertTrue(g.isEmpty)
    }

    func testPruefsummeNurFuerGleichGrosse() throws {
        var aufrufe = 0
        let ks = [T.k("A", groesse: 1), T.k("B", groesse: 2), T.k("C", groesse: 3)]
        _ = try DuplikatFinder.gruppen(aus: ks, pruefsumme: { id in aufrufe += 1; return id })
        XCTAssertEqual(aufrufe, 0)
    }

    func testFehlerBeimBildenDerPruefsummeWirdWeitergegeben() {
        let ks = [T.k("A", groesse: 5), T.k("B", groesse: 5)]
        XCTAssertThrowsError(try DuplikatFinder.gruppen(aus: ks, pruefsumme: { _ in throw FehlerT.boom }))
    }
}
