import Foundation
import SwiftUI
import AufraeumerKern

@MainActor
final class AufraeumerModel: ObservableObject {
    enum Phase: Equatable {
        case start, scannt, uebersicht, auswahl, sichern, bestaetigen, lauf, bericht
    }

    enum LaufArt: Equatable {
        case sichernUndLoeschen
        case nurVideosVerkleinern
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
    @Published var sicherOrdnerName: String?
    @Published var ordnerWaehlen = false
    @Published var sicherungsOptionen = SicherungsOptionen()
    @Published var iCloudFotosFrageOffen = false
    @Published var zeigeVideoVerkleinern = false
    @Published var videoLaufAktiv = false

    @Published var laufDateiIndex = 0
    @Published var laufDateiGesamt = 0
    @Published var laufStartzeit: Date?
    @Published var laufArt: LaufArt = .sichernUndLoeschen

    let bibliothek = PhotoKitBibliothek()
    private var sicherung: ICloudSicherung?
    private var speicherVorher: Int64 = 0
    private let demoModus = ProcessInfo.processInfo.arguments.contains("-ScreenshotModus")

    func beimStart() async {
        if demoModus {
            speicher = DemoDaten.speicher
            scan = DemoDaten.scan
            ausgewaehlt = ["demo-2"]
            sicherOrdnerName = "Mein Sicherungsordner"
            let ziel = DemoDaten.phaseAusArgument() ?? .uebersicht
            if ziel == .bericht {
                speicherVorher = (speicher?.freiBytes ?? 0) - 2_000_000_000
                speicherNachher = speicher
                ergebnis = LoeschlaufErgebnis(geloescht: ["demo-2"], nichtGeloescht: [:], protokoll: Protokoll())
            }
            phase = ziel
            return
        }
        speicher = SpeicherAnzeige.lesen()
        if let url = ICloudOrdnerSpeicher.laden() {
            sicherOrdnerName = url.lastPathComponent
            sicherung = ICloudSicherung(ordner: url)
        }
        if !ICloudFotosSpeicher.wurdeGefragt { iCloudFotosFrageOffen = true }
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
            fehlerText = ScanFehler.hilfeText(fuer: error)
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
        return sicherungsOptionen.effektiverModus(kategorien: kat)
    }

    func brauchtSicherung() -> Bool {
        ausgewaehlt.contains { modus(fuer: $0) == .erstSichern }
    }

    func nutzenSatz(fuer schritt: AufraeumSchritt) -> String {
        let bytes = bytesAusgewaehlt()
        switch schritt {
        case .pruefen:
            let summe = scan?.bytesJeKategorie.values.reduce(0, +) ?? 0
            return summe > 0
                ? "Hier siehst du, was du aufräumen kannst – insgesamt etwa \(Formatierung.gigabytes(summe))."
                : "Hier siehst du, was du aufräumen kannst."
        case .auswaehlen:
            return bytes > 0
                ? "Das macht etwa \(Formatierung.gigabytes(bytes)) frei."
                : "Wähle Dateien aus, die weg können."
        case .sichern:
            return "Deine Auswahl wird kopiert, bevor etwas gelöscht wird."
        case .loeschen:
            return bytes > 0
                ? "Danach werden etwa \(Formatierung.gigabytes(bytes)) frei – nach dem Leeren von „Zuletzt gelöscht“."
                : "Danach fragt das iPhone noch einmal nach."
        }
    }

    func aktuellerSchritt() -> AufraeumSchritt {
        switch phase {
        case .start, .scannt, .uebersicht: return .pruefen
        case .auswahl: return .auswaehlen
        case .sichern: return .sichern
        case .lauf:
            if laufArt == .sichernUndLoeschen && laufFortschritt < 0.85 { return .sichern }
            return .loeschen
        case .bestaetigen, .bericht: return .loeschen
        }
    }

    func weiterVonUebersicht() {
        phase = .auswahl
    }

    func weiterVonAuswahl() {
        if brauchtSicherung() {
            if sicherung == nil {
                fehlerText = "Bitte wähle einen Ordner in der Dateien-App. Du kannst iCloud Drive, „Auf meinem iPhone“ oder einen Stick nutzen."
                ordnerWaehlen = true
                return
            }
            phase = .sichern
        } else {
            phase = .bestaetigen
        }
    }

    func weiterVonSichern() {
        phase = .bestaetigen
    }

    func ordnerGewaehlt(_ url: URL) {
        do {
            try ICloudOrdnerSpeicher.speichern(url)
            sicherOrdnerName = url.lastPathComponent
            sicherung = ICloudSicherung(ordner: url)
            fehlerText = nil
        } catch {
            fehlerText = "Ordner konnte nicht gemerkt werden. Bitte erneut wählen. Grund: \(error.localizedDescription)"
        }
    }

    func ordnerAbbruch() {
        if brauchtSicherung() && sicherung == nil {
            fehlerText = "Ohne Ordner wird nichts gelöscht, das eine Sicherung braucht."
        }
    }

    func loeschenBestaetigt() async {
        guard let scan else { return }
        if brauchtSicherung() && sicherung == nil {
            fehlerText = "Bitte zuerst einen Sicherungsordner wählen."
            phase = .sichern
            return
        }
        let sicherungLauf: any Sicherung = sicherung ?? LeereSicherung()
        speicherVorher = speicher?.freiBytes ?? 0
        phase = .lauf
        laufArt = .sichernUndLoeschen
        laufFortschritt = 0
        laufText = "Vorbereitung …"
        uploadProzent = 0
        laufStartzeit = Date()

        let auswahl = ausgewaehlt.compactMap { id -> Auswahl? in
            guard let k = kandidat(id) else { return nil }
            return Auswahl(kandidat: k, modus: modus(fuer: id), favoritBestaetigt: false)
        }
        let gruppen = scan.duplikatGruppen + scan.serienGruppen
        laufDateiGesamt = auswahl.count
        laufDateiIndex = 0

        sicherung?.uploadFortschritt = { [weak self] p in
            Task { @MainActor in self?.uploadProzent = p }
        }

        var erledigt = 0
        let lauf = Loeschlauf(bibliothek: bibliothek, sicherung: sicherungLauf) { [weak self] eintrag in
            Task { @MainActor in
                guard let self else { return }
                erledigt += 1
                self.laufDateiIndex = min(erledigt, self.laufDateiGesamt)
                self.laufFortschritt = self.laufDateiGesamt > 0
                    ? Double(erledigt) / Double(self.laufDateiGesamt) : 1
                self.laufText = eintrag.name
            }
        }

        let er = await lauf.ausfuehren(auswahl: auswahl, gruppen: gruppen, bestaetigt: true)
        laufFortschritt = 1
        ergebnis = er
        speicherNachher = SpeicherAnzeige.lesen()
        phase = .bericht
    }

    func videosVerkleinernStarten(ids: Set<String>) async {
        guard !ids.isEmpty else { return }
        speicherVorher = speicher?.freiBytes ?? 0
        videoLaufAktiv = true
        phase = .lauf
        laufArt = .nurVideosVerkleinern
        laufStartzeit = Date()
        let liste = ids.compactMap { kandidat($0) }
        laufDateiGesamt = liste.count
        let verkleinerer = VideoVerkleinerer(bibliothek: bibliothek)
        let ergebnisLauf = await verkleinerer.verkleinern(kandidaten: liste) { [weak self] p, name in
            Task { @MainActor in
                self?.laufFortschritt = p
                self?.laufText = name
                self?.laufDateiIndex = Int(p * Double(liste.count))
            }
        }
        videoLaufAktiv = false
        if ergebnisLauf.fehler.isEmpty {
            fehlerText = nil
        } else {
            fehlerText = "\(ergebnisLauf.fehler.count) Video(s) konnten nicht verkleinert werden."
        }
        speicherNachher = SpeicherAnzeige.lesen()
        phase = .bericht
        ergebnis = LoeschlaufErgebnis(geloescht: ergebnisLauf.erfolg, nichtGeloescht: ergebnisLauf.fehler,
                                      protokoll: Protokoll())
    }

    var freigewordenerPlatz: Int64 {
        let nach = speicherNachher?.freiBytes ?? speicherVorher
        return max(0, nach - speicherVorher)
    }

    func bytesAusgewaehlt() -> Int64 {
        ausgewaehlt.reduce(0) { $0 + (kandidat($1)?.groesseBytes ?? 0) }
    }

    func grosseVideoKandidaten() -> [Kandidat] {
        guard let scan else { return [] }
        let ids = scan.kategorien[.grosseVideos] ?? []
        return ids.compactMap { kandidat($0) }.filter { $0.istVideo && $0.istLokalVorhanden }
    }

    func geschaetzteVideoErsparnis() -> Int64 {
        grosseVideoKandidaten().reduce(0) {
            $0 + VideoSparSchaetzung.geschaetzteErsparnis(bytes: $1.groesseBytes, dauerSekunden: $1.dauerSekunden)
        }
    }

    var laufRestzeitText: String {
        guard let start = laufStartzeit, laufFortschritt > 0.05 else { return "" }
        let vergangen = Date().timeIntervalSince(start)
        let gesamt = vergangen / laufFortschritt
        return Formatierung.restzeit(sekunden: gesamt - vergangen)
    }

    func abbrechenOhneVerlust() {
        if phase == .lauf { return }
        fehlerText = nil
        phase = .uebersicht
    }

    /// Für die Oberfläche: Ordner gewählt und Schreibzugriff vorbereitet.
    var hatSicherungsordner: Bool { sicherOrdnerName != nil }
}
