import Foundation
import AufraeumerKern

/// Feste Daten für Simulator-Screenshots ohne echte Fotomediathek.
enum DemoDaten {
    static var speicher: SpeicherStand {
        let gesamt: Int64 = 256_000_000_000
        let frei: Int64 = 8_500_000_000
        return SpeicherStand(freiBytes: frei, belegtBytes: gesamt - frei, gesamtBytes: gesamt,
                             medienBelegtBytes: 42_000_000_000,
                             groessteKategorie: ("Große Videos", 18_000_000_000))
    }

    static var scan: ScanErgebnis {
        let k1 = Kandidat(id: "demo-1", name: "IMG_DEMO_A.MOV", groesseBytes: 1_200_000_000,
                          aufnahme: Date(timeIntervalSince1970: 1_600_000_000), dauerSekunden: 180,
                          istVideo: true, istScreenshot: false, istFavorit: false, istBearbeitet: false,
                          inAlbum: false, istAusgeblendet: false, istLokalVorhanden: true)
        let k2 = Kandidat(id: "demo-2", name: "IMG_DEMO_B.HEIC", groesseBytes: 4_200_000,
                          aufnahme: Date(timeIntervalSince1970: 1_700_000_000), dauerSekunden: nil,
                          istVideo: false, istScreenshot: true, istFavorit: false, istBearbeitet: false,
                          inAlbum: false, istAusgeblendet: false, istLokalVorhanden: true)
        let kat: [Kategorie: Set<String>] = [
            .grosseVideos: [k1.id],
            .alteScreenshots: [k2.id]
        ]
        var bytes: [Kategorie: Int64] = [.grosseVideos: k1.groesseBytes, .alteScreenshots: k2.groesseBytes]
        return ScanErgebnis(kandidaten: [k1, k2], kategorien: kat, bytesJeKategorie: bytes,
                            duplikatGruppen: [], serienGruppen: [])
    }

    static func phaseAusArgument() -> AufraeumerModel.Phase? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-ScreenshotPhase=") }) else {
            return nil
        }
        let name = String(arg.dropFirst("-ScreenshotPhase=".count))
        switch name {
        case "uebersicht": return .uebersicht
        case "auswahl": return .auswahl
        case "sichern": return .sichern
        case "bestaetigen": return .bestaetigen
        case "bericht": return .bericht
        default: return nil
        }
    }
}
