import XCTest
@testable import AufraeumerKern

final class VersionTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(Kern.version, "0.1.0")
    }
}
