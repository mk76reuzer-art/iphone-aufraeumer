import Foundation
@testable import AufraeumerKern

enum FehlerT: Error { case boom }

enum T {
    static var kal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    /// 2026-09-21T14:13:20Z
    static let jetzt = Date(timeIntervalSince1970: 1_790_000_000)
    static func tageher(_ n: Int) -> Date { kal.date(byAdding: .day, value: -n, to: jetzt)! }
    static func jahreher(_ n: Int) -> Date { kal.date(byAdding: .year, value: -n, to: jetzt)! }

    static func k(_ id: String = "A", groesse: Int64 = 1_000, aufnahme: Date? = nil,
                  video: Bool = false, screenshot: Bool = false, favorit: Bool = false,
                  bearbeitet: Bool = false, album: Bool = false, ausgeblendet: Bool = false,
                  lokal: Bool = true, dauer: Double? = nil, name: String? = nil) -> Kandidat {
        Kandidat(id: id, name: name ?? "IMG_\(id).MP4", groesseBytes: groesse,
                 aufnahme: aufnahme ?? tageher(1), dauerSekunden: dauer, istVideo: video,
                 istScreenshot: screenshot, istFavorit: favorit, istBearbeitet: bearbeitet,
                 inAlbum: album, istAusgeblendet: ausgeblendet, istLokalVorhanden: lokal)
    }
}
