import XCTest
@testable import AufraeumerKern

final class SicherungsOptionenTests: XCTestCase {
    func testDuplikatOhneOptionBrauchtKeinenOrdner() {
        let opt = SicherungsOptionen()
        let modus = opt.effektiverModus(kategorien: [.duplikate])
        XCTAssertEqual(modus, .nurLoeschen)
    }

    func testGrossesVideoBrauchtImmerOrdner() {
        let opt = SicherungsOptionen()
        let modus = opt.effektiverModus(kategorien: [.grosseVideos])
        XCTAssertEqual(modus, .erstSichern)
    }

    func testDuplikatMitOptionBrauchtOrdner() {
        let opt = SicherungsOptionen(duplikateSichern: true)
        let modus = opt.effektiverModus(kategorien: [.duplikate])
        XCTAssertEqual(modus, .erstSichern)
    }

    func testSerienUndBildschirmfotosSindAbwaehlbar() {
        let aus = SicherungsOptionen()
        XCTAssertEqual(aus.effektiverModus(kategorien: [.serienbilder]), .nurLoeschen)
        XCTAssertEqual(aus.effektiverModus(kategorien: [.alteScreenshots]), .nurLoeschen)
        let an = SicherungsOptionen(serienSichern: true, screenshotsSichern: true)
        XCTAssertEqual(an.effektiverModus(kategorien: [.serienbilder]), .erstSichern)
        XCTAssertEqual(an.effektiverModus(kategorien: [.alteScreenshots]), .erstSichern)
    }

    func testScanKarteSiehtDuplikatAuchWennRegelnEsNichtSetzt() {
        let karte: [Kategorie: Set<String>] = [.duplikate: ["a"]]
        let kats = KategorieBlick.von(id: "a", kategorien: karte)
        XCTAssertEqual(kats, [.duplikate])
        let modus = SicherungsOptionen(duplikateSichern: true).effektiverModus(kategorien: kats)
        XCTAssertEqual(modus, .erstSichern)
        XCTAssertEqual(SicherungsOptionen().effektiverModus(kategorien: kats), .nurLoeschen)
    }
}
