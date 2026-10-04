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
}
