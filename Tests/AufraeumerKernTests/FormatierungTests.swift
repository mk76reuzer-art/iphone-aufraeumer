import XCTest
@testable import AufraeumerKern

final class FormatierungTests: XCTestCase {
    func testDeutschesKommaBeiVierKommaZweiGigabyte() {
        XCTAssertEqual(Formatierung.gigabytes(4_200_000_000), "4,2 GB")
    }

    func testGrosseZahlOhneNachkommastelle() {
        XCTAssertEqual(Formatierung.gigabytes(18_000_000_000), "18 GB")
    }

    func testMegabyteMitKomma() {
        XCTAssertEqual(Formatierung.gigabytes(4_200_000), "4,2 MB")
    }

    func testRestzeitEinzahl() {
        XCTAssertEqual(Formatierung.restzeit(sekunden: 60), "noch etwa 1 Minute")
        XCTAssertEqual(Formatierung.restzeit(sekunden: 125), "noch etwa 2 Minuten")
    }
}
