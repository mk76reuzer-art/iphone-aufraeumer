import Foundation
import AufraeumerKern

/// Feste Daten für Simulator-Screenshots. Keine echten Fotos.
enum DemoDaten {
    static var screenshotPhase: String? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-ScreenshotPhase=") }) else {
            return nil
        }
        return String(arg.dropFirst("-ScreenshotPhase=".count))
    }

    static var speicher: SpeicherStand {
        let gesamt: Int64 = 256_000_000_000
        let frei: Int64 = 8_500_000_000
        return SpeicherStand(freiBytes: frei, belegtBytes: gesamt - frei, gesamtBytes: gesamt,
                             medienBelegtBytes: 5_080_000_000,
                             groessteKategorie: ("Große Videos", 4_400_000_000))
    }

    static var scan: ScanErgebnis {
        let video = kandidat("demo-video", "Urlaubsfilm.mov", 3_600_000_000, video: true, dauer: 600)
        let videoKlein = kandidat("demo-video-klein", "Kurzfilm.mov", 800_000_000, video: true, dauer: 180)
        let shot = kandidat("demo-shot", "Bildschirmfoto.jpg", 600_000_000, screenshot: true)
        let alt = kandidat("demo-alt", "Altes Foto.jpg", 50_000_000, alt: true)
        let dupA = kandidat("demo-dup-a", "Doppeltes Foto.jpg", 20_000_000)
        let dupB = kandidat("demo-dup-b", "Doppeltes Foto Kopie.jpg", 20_000_000)
        let s1 = kandidat("demo-serie-1", "Serie 1.jpg", 5_000_000)
        let s2 = kandidat("demo-serie-2", "Serie 2.jpg", 5_000_000)
        let s3 = kandidat("demo-serie-3", "Serie 3.jpg", 5_000_000)
        let alle = [video, videoKlein, shot, alt, dupA, dupB, s1, s2, s3]
        let kategorien: [Kategorie: Set<String>] = [
            .grosseVideos: [video.id, videoKlein.id],
            .alteScreenshots: [shot.id],
            .langeUnberuehrt: [alt.id],
            .duplikate: [dupB.id],
            .serienbilder: [s2.id, s3.id]
        ]
        var bytes: [Kategorie: Int64] = [:]
        for (kat, ids) in kategorien {
            bytes[kat] = ids.reduce(0) { summe, id in
                summe + (alle.first { $0.id == id }?.groesseBytes ?? 0)
            }
        }
        let summe = alle.reduce(Int64(0)) { $0 + $1.groesseBytes }
        let videos = alle.filter(\.istVideo).reduce(Int64(0)) { $0 + $1.groesseBytes }
        return ScanErgebnis(
            kandidaten: alle,
            kategorien: kategorien,
            duplikatGruppen: [DuplikatGruppe(behalten: dupA.id, loeschbar: [dupB.id])],
            serienGruppen: [DuplikatGruppe(behalten: s1.id, loeschbar: [s2.id, s3.id])],
            bytesJeKategorie: bytes,
            anzahlAssets: alle.count,
            mediathekLokalBytes: summe,
            videoLokalBytes: videos,
            anzahlNurCloud: 0
        )
    }

    static let ausgewaehlt: Set<String> = ["demo-video", "demo-shot"]

    private static func kandidat(
        _ id: String, _ name: String, _ bytes: Int64,
        video: Bool = false, screenshot: Bool = false, alt: Bool = false, dauer: Double? = nil
    ) -> Kandidat {
        let aufnahme = alt
            ? Date(timeIntervalSince1970: 1_500_000_000)
            : Date(timeIntervalSince1970: 1_700_000_000)
        return Kandidat(
            id: id, name: name, groesseBytes: bytes, aufnahme: aufnahme,
            dauerSekunden: dauer, istVideo: video, istScreenshot: screenshot,
            istFavorit: false, istBearbeitet: false, inAlbum: false,
            istAusgeblendet: false, istLokalVorhanden: true
        )
    }
}
