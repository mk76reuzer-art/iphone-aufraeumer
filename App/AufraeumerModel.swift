import Foundation
import SwiftUI
import AufraeumerKern

@MainActor
final class AufraeumerModel: ObservableObject {
    enum Phase: Equatable {
        case start, scannt, uebersicht, auswahl, sichern, bestaetigen, lauf, bericht
    }

    @Published var phase: Phase = .start
    @Published var speicher: SpeicherStand?
    @Published var scanFortschritt: Double = 0
    @Published var scanText = ""
    @Published var fehlerText: String?
    @Published var scan: ScanErgebnis?
    @Published var ausgewaehlt: Set<String> = []
    @Published var laufFortschritt: Double = 0
    @Published var laufText = ""
    @Published var uploadProzent: Double = 0
    @Published var ergebnis: LoeschlaufErgebnis?
    @Published var speicherNachher: SpeicherStand?
    @Published var iCloudOrdnerName: String?
    @Published var ordnerWaehlen = false

    let bibliothek = PhotoKitBibliothek()
    private var sicherung: ICloudSicherung?
    private var speicherVorher: Int64 = 0

    func beimStart() async {
        speicher = SpeicherAnzeige.lesen()
        if let url = ICloudOrdnerSpeicher.laden() {
            iCloudOrdnerName = url.lastPathComponent
            sicherung = ICloudSicherung(ordner: url)
        }
        await scanStarten()
    }

    func scanStarten() async {
        phase = .scannt
        fehlerText = nil
        scanFortschritt = 0
        do {
            let ergebnis = try await MediathekScanner.scan(bibliothek: bibliothek) { p, t in
                Task { @MainActor in
                    self.scanFortschritt = p
                    self.scanText = t
                }
            }
            scan = ergebnis
            ausgewaehlt = Self.sichereVorauswahl(ergebnis: ergebnis)
            if var s = speicher {
                s.medienBelegtBytes = ergebnis.bytesJeKategorie.values.reduce(0, +)
                s.groessteKategorie = ergebnis.bytesJeKategorie.max(by: { $0.value < $1.value })
                    .map { ($0.key.anzeigeName, $0.value) }
                speicher = s
            }
            phase = .uebersicht
        } catch {
            fehlerText = error.localizedDescription
            phase = .uebersicht
        }
    }

    static func sichereVorauswahl(ergebnis: ScanErgebnis) -> Set<String> {
        var ids = Set<String>()
        for g in ergebnis.duplikatGruppen {
            for id in g.loeschbar {
                if let k = ergebnis.kandidaten.first(where: { $0.id == id }),
                   !k.istFavorit, !k.istAusgeblendet { ids.insert(id) }
            }
        }
        for g in ergebnis.serienGruppen {
            for id in g.loeschbar {
                if let k = ergebnis.kandidaten.first(where: { $0.id == id }),
                   !k.istFavorit, !k.istAusgeblendet { ids.insert(id) }
            }
        }
        for k in ergebnis.kandidaten {
            let kat = Regeln.kategorien(fuer: k, jetzt: Date())
            guard !kat.isEmpty, !k.istFavorit, !k.istAusgeblendet else { continue }
            if kat.contains(.alteScreenshots) { ids.insert(k.id) }
        }
        return ids
    }

    func kandidat(_ id: String) -> Kandidat? {
        scan?.kandidaten.first { $0.id == id }
    }

    func modus(fuer id: String) -> Modus {
        guard let k = kandidat(id) else { return .erstSichern }
        let kat = Regeln.kategorien(fuer: k, jetzt: Date())
        return Regeln.modus(fuer: kat)
    }

    func brauchtSicherung() -> Bool {
        ausgewaehlt.contains { modus(fuer: $0) == .erstSichern }
    }

    func weiterVonUebersicht() {
        phase = .auswahl
    }

    func weiterVonAuswahl() {
        if brauchtSicherung() {
            if sicherung == nil {
                fehlerText = "Bitte zuerst einen Ordner in iCloud Drive wählen."
                ordnerWaehlen = true
                return
            }
            phase = .sichern
        } else {
            phase = .bestaetigen
        }
    }

    func auswahlErweitern() {
        guard let scan else { return }
        for kat in Kategorie.allCases {
            guard let ids = scan.kategorien[kat] else { continue }
            for id in ids {
                if let k = kandidat(id), !k.istFavorit, !k.istAusgeblendet {
                    if kat == .grosseVideos || kat == .langeUnberuehrt { continue }
                    ausgewaehlt.insert(id)
                }
            }
        }
    }

    func ordnerGewaehlt(_ url: URL) {
        do {
            try ICloudOrdnerSpeicher.speichern(url)
            iCloudOrdnerName = url.lastPathComponent
            sicherung = ICloudSicherung(ordner: url)
            fehlerText = nil
        } catch {
            fehlerText = "Ordner konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    func loeschenBestaetigt() async {
        guard let scan else { return }
        if brauchtSicherung() && sicherung == nil {
            fehlerText = "Bitte zuerst einen iCloud-Ordner wählen."
            phase = .uebersicht
            return
        }
        let sicherungLauf: any Sicherung = sicherung ?? LeereSicherung()
        speicherVorher = speicher?.freiBytes ?? 0
        phase = .lauf
        laufFortschritt = 0
        laufText = "Vorbereitung …"
        uploadProzent = 0

        let auswahl = ausgewaehlt.compactMap { id -> Auswahl? in
            guard let k = kandidat(id) else { return nil }
            return Auswahl(kandidat: k, modus: modus(fuer: id), favoritBestaetigt: false)
        }
        let gruppen = scan.duplikatGruppen + scan.serienGruppen

        sicherung?.uploadFortschritt = { [weak self] p in
            Task { @MainActor in self?.uploadProzent = p }
        }

        let gesamt = Double(max(1, auswahl.count))
        var erledigt = 0.0
        let lauf = Loeschlauf(bibliothek: bibliothek, sicherung: sicherungLauf) { [weak self] eintrag in
            Task { @MainActor in
                erledigt += 0.25
                self?.laufFortschritt = min(0.95, erledigt / gesamt)
                self?.laufText = eintrag.name
            }
        }

        let er = await lauf.ausfuehren(auswahl: auswahl, gruppen: gruppen, bestaetigt: true)
        laufFortschritt = 1
        ergebnis = er
        speicherNachher = SpeicherAnzeige.lesen()
        phase = .bericht
    }

    var freigewordenerPlatz: Int64 {
        let nach = speicherNachher?.freiBytes ?? speicherVorher
        return max(0, nach - speicherVorher)
    }

    func bytesAusgewaehlt() -> Int64 {
        ausgewaehlt.reduce(0) { $0 + (kandidat($1)?.groesseBytes ?? 0) }
    }
}
