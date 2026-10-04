import XCTest
import CryptoKit
@testable import AufraeumerKern

final class DateiPruefungTests: XCTestCase {
    private func datei(name: String, inhalt: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("aufraeumer-test-\(name)")
        try inhalt.write(to: url)
        return url
    }

    func testLeerePruefsummeIstSha256() throws {
        let url = try datei(name: "leer", inhalt: Data())
        defer { try? FileManager.default.removeItem(at: url) }
        let gemessen = try DateiPruefung.messen(url: url)
        XCTAssertEqual(gemessen.bytes, 0)
        XCTAssertEqual(gemessen.pruefsumme, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testStueckweisePruefsummeGleichGanzerDatei() throws {
        let inhalt = Data(repeating: 7, count: 2_500_000)
        let url = try datei(name: "gross", inhalt: inhalt)
        defer { try? FileManager.default.removeItem(at: url) }
        let gemessen = try DateiPruefung.messen(url: url)
        let direkt = SHA256.hash(data: inhalt).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(gemessen.bytes, Int64(inhalt.count))
        XCTAssertEqual(gemessen.pruefsumme, direkt)
    }

    func testKopieIstGleichGrossUndMeldetHundertProzent() throws {
        let inhalt = Data(repeating: 3, count: 1_500_000)
        let quelle = try datei(name: "quelle", inhalt: inhalt)
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent("aufraeumer-test-ziel")
        defer {
            try? FileManager.default.removeItem(at: quelle)
            try? FileManager.default.removeItem(at: ziel)
        }
        var letzter: Double = -1
        var rufe = 0
        try DateiKopie.kopieren(von: quelle, nach: ziel) { wert in
            letzter = wert
            rufe += 1
        }
        let gemessen = try DateiPruefung.messen(url: ziel)
        XCTAssertEqual(gemessen.bytes, Int64(inhalt.count))
        XCTAssertEqual(letzter, 1)
        XCTAssertGreaterThan(rufe, 1)
    }

    func testLeereQuelleWirdNichtKopiert() throws {
        let quelle = try datei(name: "leer2", inhalt: Data())
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent("aufraeumer-test-leerziel")
        defer { try? FileManager.default.removeItem(at: quelle) }
        XCTAssertThrowsError(try DateiKopie.kopieren(von: quelle, nach: ziel)) { fehler in
            XCTAssertEqual(fehler as? DateiKopieFehler, .lesen)
        }
    }
}
