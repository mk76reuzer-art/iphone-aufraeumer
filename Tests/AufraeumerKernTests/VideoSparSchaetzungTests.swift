import XCTest
@testable import AufraeumerKern

final class VideoSparSchaetzungTests: XCTestCase {
    func testErsparnisIstPositivBeiGrosserDatei() {
        let alt: Int64 = 200_000_000
        let spare = VideoSparSchaetzung.geschaetzteErsparnis(bytes: alt, dauerSekunden: 120)
        XCTAssertGreaterThan(spare, 50_000_000)
        XCTAssertLessThan(spare, alt)
    }

    func testNachherKleinerAlsVorher() {
        let alt: Int64 = 100_000_000
        let neu = VideoSparSchaetzung.geschaetzteGroesseNachher(bytes: alt, dauerSekunden: 60)
        XCTAssertLessThan(neu, alt)
    }
}
