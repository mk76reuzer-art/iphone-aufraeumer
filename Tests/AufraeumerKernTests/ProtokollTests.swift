import XCTest
@testable import AufraeumerKern

final class ProtokollTests: XCTestCase {
    private let t = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21T14:13:20Z

    private func e(_ name: String, _ a: Aktion = .geloescht, grund: String? = nil) -> ProtokollEintrag {
        ProtokollEintrag(zeit: t, id: "id1", name: name, groesseBytes: 123, aktion: a, grund: grund)
    }

    func testLeeresProtokollHatNurKopfzeile() {
        XCTAssertEqual(Protokoll().csv(), "Zeit;ID;Name;Groesse_Bytes;Aktion;Grund")
    }

    func testEinfacheZeile() {
        var p = Protokoll()
        p.hinzufuegen(e("IMG_A.MP4"))
        let zeilen = p.csv().components(separatedBy: "\n")
        XCTAssertEqual(zeilen.count, 2)
        XCTAssertEqual(zeilen[1], "2026-09-21T14:13:20Z;id1;IMG_A.MP4;123;geloescht;")
    }

    func testSonderzeichenWerdenMaskiert() {
        var p = Protokoll()
        p.hinzufuegen(e("Urlaub; \"Sommer\"\nTeil 2 äöü 🎬.MP4", .abgebrochen, grund: "Zeile1\r\nZeile2"))
        let csv = p.csv()
        XCTAssertTrue(csv.contains("\"Urlaub; \"\"Sommer\"\"\nTeil 2 äöü 🎬.MP4\""))
        XCTAssertTrue(csv.contains("\"Zeile1\r\nZeile2\""))
    }

    func testUmlauteUndEmojiOhneSonderzeichenBleibenUnmaskiert() {
        var p = Protokoll()
        p.hinzufuegen(e("Größe äöü 🎬.MP4"))
        XCTAssertTrue(p.csv().contains(";Größe äöü 🎬.MP4;"))
    }

    func testJsonRundreiseErhaeltReihenfolgeUndWerte() throws {
        var p = Protokoll()
        p.hinzufuegen(e("A.MP4", .beabsichtigt))
        p.hinzufuegen(e("B.MP4", .abgebrochen, grund: "Upload nicht rechtzeitig fertig"))
        let q = try Protokoll.aus(json: try p.json())
        XCTAssertEqual(p, q)
        XCTAssertEqual(q.eintraege.map(\.name), ["A.MP4", "B.MP4"])
        XCTAssertNil(q.eintraege[0].grund)
    }
}
