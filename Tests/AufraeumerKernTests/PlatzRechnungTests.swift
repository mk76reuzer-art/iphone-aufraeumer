import XCTest
@testable import AufraeumerKern

final class PlatzRechnungTests: XCTestCase {
    func testDateiInZweiGruppenZaehltEinmal() {
        let bytes = ["a": Int64(100), "b": Int64(40)]
        let kategorien: [Kategorie: Set<String>] = [
            .grosseVideos: ["a"],
            .langeUnberuehrt: ["a", "b"]
        ]
        XCTAssertEqual(PlatzRechnung.eindeutig(bytesJeId: bytes, kategorien: kategorien), 140)
    }

    func testHauptkategorieNimmtDenGroesstenHebel() {
        let kategorien: [Kategorie: Set<String>] = [
            .alteScreenshots: ["a"],
            .grosseVideos: ["a"],
            .duplikate: ["b"]
        ]
        XCTAssertEqual(PlatzRechnung.hauptkategorie(id: "a", kategorien: kategorien), .grosseVideos)
        XCTAssertEqual(PlatzRechnung.hauptkategorie(id: "b", kategorien: kategorien), .duplikate)
        XCTAssertNil(PlatzRechnung.hauptkategorie(id: "fehlt", kategorien: kategorien))
    }
}
