import Foundation
import SwiftUI
import AufraeumerKern

struct AnzeigeZeile: Identifiable {
    let kat: Kategorie
    let anzahl: Int
    let bytes: Int64
    var id: Kategorie { kat }
}

struct AuswahlBlock: Identifiable {
    let kat: Kategorie
    let ids: [String]
    var id: Kategorie { kat }
}

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
    @Published var fehlerIstZugriff = false
    @Published var scan: ScanErgebnis?
    @Published var ausgewaehlt: Set<String> = []
    @Published var laufFortschritt: Double = 0
    @Published var laufText = ""
    @Published var laufSchrittText = ""
    @Published var ergebnis: LoeschlaufErgebnis?
    @Published var speicherNachher: SpeicherStand?
    @Published var sicherOrdnerName: String?
    @Published var ordnerWaehlen = false
    @Published var sicherungsOptionen = SicherungsOptionen()
    @Published var iCloudFotosFrageOffen = false
    @Published var zeigeVideoVerkleinern = false
    @Published var tippsAnzeigen = false
    @Published var favoritenTrotzdem = false
    @Published var laufAbgebrochen = false
    @Published var berichtArt: LaufArt = .sichernUndLoeschen

    @Published var laufDateiIndex = 0
    @Published var laufDateiGesamt = 0
    @Published var laufStartzeit: Date?
    @Published var laufArt: LaufArt = .sichernUndLoeschen

    let bibliothek = PhotoKitBibliothek()
    private var sicherung: ICloudSicherung?
    private var sicherOrdnerURL: URL?
    private var speicherVorher: Int64 = 0
    private var dateiAnteil: Double = 0
    private var laufSchritt: LaufMeldung.Schritt = .kopieren
    private var arbeit: Task<Void, Never>?
    private let demoModus = ProcessInfo.processInfo.arguments.contains("-ScreenshotModus")

    func beimStart() async {
        if demoModus {
            demoEinrichten()
            return
        }
        speicher = SpeicherAnzeige.lesen()
        if let url = ICloudOrdnerSpeicher.laden() {
            sicherOrdnerURL = url
            let neu = ICloudSicherung(ordner: url)
            if neu.hatZugriff {
                sicherung = neu
                sicherOrdnerName = ICloudOrdnerSpeicher.anzeigename(fuer: url)
            } else {
                sicherOrdnerName = nil
            }
        }
        if !ICloudFotosSpeicher.wurdeGefragt { iCloudFotosFrageOffen = true }
        await scanStarten()
    }

    func scanStarten() async {
        if demoModus {
            phase = .uebersicht
            return
        }
        arbeit?.cancel()
        let lauf = Task { await self.scanIntern() }
        arbeit = lauf
        await lauf.value
    }

    func abbrechenLauf() {
        laufAbgebrochen = true
        arbeit?.cancel()
    }

    func abbrechenOhneVerlust() {
        if phase == .lauf || phase == .scannt {
            abbrechenLauf()
            return
        }
        fehlerText = nil
        phase = .uebersicht
    }

    func iCloudAntwort(_ aktiv: Bool) {
        ICloudFotosSpeicher.speichern(aktiv: aktiv)
        iCloudFotosFrageOffen = false
    }

    func weiterVonUebersicht() {
        fehlerText = nil
        phase = .auswahl
    }

    func weiterVonAuswahl() {
        if brauchtSicherung() && sicherung == nil {
            fehlerText = "Bitte wähle einen Ordner. Tippe links auf iCloud Drive, Auf meinem iPhone oder deinen Stick, öffne den Ordner und tippe oben rechts auf Öffnen."
            phase = .sichern
            ordnerWaehlen = true
            return
        }
        fehlerText = nil
        phase = brauchtSicherung() ? .sichern : .bestaetigen
    }

    func weiterVonSichern() {
        guard sicherung != nil else {
            fehlerText = "Noch kein Ordner. Tippe auf Ordner wählen."
            ordnerWaehlen = true
            return
        }
        fehlerText = nil
        phase = .bestaetigen
    }

    func ordnerGewaehlt(_ url: URL) {
        do {
            try ICloudOrdnerSpeicher.speichern(url)
            guard let gemerkt = ICloudOrdnerSpeicher.laden() else { throw OrdnerFehler.nichtMerkbar }
            let neu = ICloudSicherung(ordner: gemerkt)
            guard neu.hatZugriff else { throw OrdnerFehler.keinZugriff }
            try neu.legeHinweisAb()
            sicherung = neu
            sicherOrdnerURL = gemerkt
            sicherOrdnerName = ICloudOrdnerSpeicher.anzeigename(fuer: gemerkt)
            fehlerText = nil
        } catch {
            sicherung = nil
            sicherOrdnerName = nil
            fehlerText = (error as? LocalizedError)?.errorDescription
                ?? "Der Ordner lässt sich nicht verwenden. Wähle einen anderen Ordner in iCloud Drive."
        }
    }

    func ordnerAbbruch() {
        if brauchtSicherung() && sicherung == nil {
            fehlerText = "Ohne Ordner wird nichts gelöscht, das eine Kopie braucht. Du kannst zurück und nur Doppelte oder Bildschirmfotos wählen."
        }
    }

    var hatSicherungsordner: Bool { sicherung != nil }
    var startOrdner: URL? { sicherOrdnerURL }

    func loeschenBestaetigt() {
        guard scan != nil else { return }
        if brauchtSicherung() && sicherung == nil {
            fehlerText = "Bitte zuerst einen Sicherungsordner wählen."
            phase = .sichern
            return
        }
        laufAbgebrochen = false
        arbeit?.cancel()
        arbeit = Task { await self.loeschlaufIntern() }
    }

    func videosVerkleinernStarten(ids: Set<String>) {
        let liste = ids.compactMap { kandidat($0) }
        guard !liste.isEmpty else { return }
        if let hinweis = VideoVerkleinerer.platzHinweis(kandidaten: liste, frei: SpeicherAnzeige.lesen()?.freiBytes) {
            fehlerText = hinweis
            phase = .uebersicht
            return
        }
        laufAbgebrochen = false
        arbeit?.cancel()
        arbeit = Task { await self.videoIntern(liste) }
    }

    func kategorien(fuer id: String) -> Set<Kategorie> {
        guard let scan else { return [] }
        return KategorieBlick.von(id: id, kategorien: scan.kategorien)
    }

    func modus(fuer id: String) -> Modus {
        let kat = kategorien(fuer: id)
        if kat.isEmpty { return .erstSichern }
        return sicherungsOptionen.effektiverModus(kategorien: kat)
    }

    func brauchtSicherung() -> Bool {
        ausgewaehlt.contains { modus(fuer: $0) == .erstSichern }
    }

    func kandidat(_ id: String) -> Kandidat? {
        scan?.kandidaten.first { $0.id == id }
    }

    func freimachbareBytes() -> Int64 {
        guard let scan else { return 0 }
        var bytes: [String: Int64] = [:]
        for k in scan.kandidaten { bytes[k.id] = k.groesseBytes }
        return PlatzRechnung.eindeutig(bytesJeId: bytes, kategorien: scan.kategorien)
    }

    func bytesAusgewaehlt() -> Int64 {
        ausgewaehlt.reduce(0) { $0 + (kandidat($1)?.groesseBytes ?? 0) }
    }

    func zeilen() -> [AnzeigeZeile] {
        guard let scan else { return [] }
        return Kategorie.allCases.map { kat in
            let ids = scan.kandidaten.map(\.id).filter {
                PlatzRechnung.hauptkategorie(id: $0, kategorien: scan.kategorien) == kat
            }
            let summe = ids.reduce(Int64(0)) { $0 + (kandidat($1)?.groesseBytes ?? 0) }
            return AnzeigeZeile(kat: kat, anzahl: ids.count, bytes: summe)
        }
    }

    func auswahlBloecke() -> [AuswahlBlock] {
        guard let scan else { return [] }
        return Kategorie.allCases.compactMap { kat in
            let ids = scan.kandidaten.map(\.id).filter {
                PlatzRechnung.hauptkategorie(id: $0, kategorien: scan.kategorien) == kat
            }.sorted()
            guard !ids.isEmpty else { return nil }
            return AuswahlBlock(kat: kat, ids: ids)
        }
    }

    func nutzenSatz(fuer schritt: AufraeumSchritt) -> String {
        let bytes = bytesAusgewaehlt()
        switch schritt {
        case .pruefen:
            let summe = freimachbareBytes()
            return summe > 0
                ? "Etwa \(Formatierung.gigabytes(summe)) kannst du freimachen."
                : "Hier siehst du, was du aufräumen kannst."
        case .auswaehlen:
            return bytes > 0
                ? "Das macht etwa \(Formatierung.gigabytes(bytes)) frei."
                : "Wähle Dateien aus, die weg können."
        case .sichern:
            return "Die Kopie wird geprüft, bevor etwas gelöscht wird."
        case .loeschen:
            return bytes > 0
                ? "Danach werden etwa \(Formatierung.gigabytes(bytes)) frei, wenn du Zuletzt gelöscht leerst."
                : "Danach fragt das iPhone noch einmal nach."
        }
    }

    func aktuellerSchritt() -> AufraeumSchritt {
        switch phase {
        case .start, .scannt, .uebersicht: return .pruefen
        case .auswahl: return .auswaehlen
        case .sichern: return .sichern
        case .lauf:
            if laufArt == .sichernUndLoeschen && laufSchritt != .loeschen { return .sichern }
            return .loeschen
        case .bestaetigen, .bericht: return .loeschen
        }
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

    func ersparnis(fuer k: Kandidat) -> Int64 {
        VideoSparSchaetzung.geschaetzteErsparnis(bytes: k.groesseBytes, dauerSekunden: k.dauerSekunden)
    }

    var favoritenInAuswahl: Int {
        ausgewaehlt.filter { kandidat($0)?.istFavorit == true }.count
    }

    var loeschenBereit: Bool {
        !ausgewaehlt.isEmpty && (favoritenInAuswahl == 0 || favoritenTrotzdem)
    }

    var freiVorher: Int64 { speicherVorher }

    var freigewordenerPlatz: Int64 {
        let nach = speicherNachher?.freiBytes ?? speicherVorher
        return max(0, nach - speicherVorher)
    }

    func erwarteteFreigabe() -> Int64 {
        guard let ergebnis else { return 0 }
        return ergebnis.geloescht.reduce(0) { $0 + (kandidat($1)?.groesseBytes ?? 0) }
    }

    var laufRestzeitText: String {
        guard let start = laufStartzeit, laufFortschritt > 0.02 else { return "" }
        let vergangen = Date().timeIntervalSince(start)
        let gesamt = vergangen / laufFortschritt
        return Formatierung.restzeit(sekunden: gesamt - vergangen)
    }

    private func scanIntern() async {
        phase = .scannt
        fehlerText = nil
        fehlerIstZugriff = false
        scanFortschritt = 0
        scanText = "Foto-Zugriff wird geprüft …"
        do {
            let ergebnis = try await MediathekScanner.scan(bibliothek: bibliothek) { [weak self] p, t in
                Task { @MainActor in
                    self?.scanFortschritt = p
                    self?.scanText = t
                }
            }
            if Task.isCancelled { throw CancellationError() }
            scan = ergebnis
            ausgewaehlt = Self.sichereVorauswahl(ergebnis: ergebnis)
            if var s = speicher {
                s.medienBelegtBytes = freimachbareBytes()
                s.groessteKategorie = zeilen().max(by: { $0.bytes < $1.bytes }).flatMap { zeile in
                    zeile.bytes > 0 ? (zeile.kat.anzeigeName, zeile.bytes) : nil
                }
                speicher = s
            }
            phase = .uebersicht
        } catch is CancellationError {
            fehlerText = "Abgebrochen. Es wurde nichts verändert."
            phase = .uebersicht
        } catch let fehler as ScanFehler where fehler == .keinZugriff {
            fehlerIstZugriff = true
            fehlerText = ScanFehler.hilfeText(fuer: fehler)
            phase = .uebersicht
        } catch {
            fehlerText = ScanFehler.hilfeText(fuer: error)
            phase = .uebersicht
        }
    }

    private func loeschlaufIntern() async {
        guard let scan else { return }
        let sicherungLauf: any Sicherung = sicherung ?? LeereSicherung()
        speicherVorher = speicher?.freiBytes ?? SpeicherAnzeige.lesen()?.freiBytes ?? 0
        phase = .lauf
        laufArt = .sichernUndLoeschen
        berichtArt = .sichernUndLoeschen
        laufFortschritt = 0
        dateiAnteil = 0
        laufSchritt = .kopieren
        laufSchrittText = "Wird vorbereitet"
        laufText = ""
        laufStartzeit = Date()

        let auswahl = ausgewaehlt.compactMap { id -> Auswahl? in
            guard let k = kandidat(id) else { return nil }
            let favoritOk = !k.istFavorit || favoritenTrotzdem
            return Auswahl(kandidat: k, modus: modus(fuer: id), favoritBestaetigt: favoritOk)
        }
        let gruppen = scan.duplikatGruppen + scan.serienGruppen
        laufDateiGesamt = auswahl.count
        laufDateiIndex = 0
        sicherung?.kopierFortschritt = { [weak self] anteil in
            Task { @MainActor in self?.kopierAnteil(anteil) }
        }
        let lauf = Loeschlauf(bibliothek: bibliothek, sicherung: sicherungLauf, aufFortschritt: { [weak self] meldung in
            Task { @MainActor in self?.uebernehmen(meldung) }
        })
        let er = await lauf.ausfuehren(auswahl: auswahl, gruppen: gruppen, bestaetigt: true)
        laufFortschritt = 1
        ergebnis = er
        speicherNachher = SpeicherAnzeige.lesen()
        phase = .bericht
    }

    private func videoIntern(_ liste: [Kandidat]) async {
        speicherVorher = speicher?.freiBytes ?? SpeicherAnzeige.lesen()?.freiBytes ?? 0
        phase = .lauf
        laufArt = .nurVideosVerkleinern
        berichtArt = .nurVideosVerkleinern
        laufStartzeit = Date()
        laufSchritt = .kopieren
        laufSchrittText = "Wird verkleinert"
        laufDateiGesamt = liste.count
        let verkleinerer = VideoVerkleinerer(bibliothek: bibliothek)
        let ergebnisLauf = await verkleinerer.verkleinern(kandidaten: liste) { [weak self] p, name in
            Task { @MainActor in
                self?.laufFortschritt = p
                self?.laufText = name
                self?.laufDateiIndex = min(liste.count, Int((p * Double(liste.count)).rounded(.up)))
            }
        }
        if ergebnisLauf.fehler.isEmpty {
            fehlerText = nil
        } else if let erster = ergebnisLauf.fehler.values.first {
            fehlerText = "\(ergebnisLauf.fehler.count) von \(liste.count) Videos wurden nicht verkleinert. \(erster)"
        }
        speicherNachher = SpeicherAnzeige.lesen()
        ergebnis = LoeschlaufErgebnis(geloescht: ergebnisLauf.erfolg, nichtGeloescht: ergebnisLauf.fehler,
                                      protokoll: Protokoll())
        phase = .bericht
    }

    private func uebernehmen(_ meldung: LaufMeldung) {
        laufSchritt = meldung.schritt
        laufDateiIndex = meldung.index
        laufDateiGesamt = meldung.gesamt
        laufText = meldung.name
        switch meldung.schritt {
        case .kopieren:
            laufSchrittText = "Wird kopiert"
            dateiAnteil = 0.02
        case .pruefen:
            laufSchrittText = "Kopie wird geprüft"
            dateiAnteil = 0.92
        case .wartenAufCloud:
            laufSchrittText = "Wird in die Cloud geladen"
            dateiAnteil = 0.97
        case .loeschen:
            laufSchrittText = "Wird gelöscht"
            dateiAnteil = 1
        }
        neuBerechnen()
    }

    private func kopierAnteil(_ anteil: Double) {
        guard laufSchritt == .kopieren else { return }
        dateiAnteil = 0.05 + 0.85 * min(1, max(0, anteil))
        neuBerechnen()
    }

    private func neuBerechnen() {
        guard laufDateiGesamt > 0 else { return }
        let stand = (Double(max(0, laufDateiIndex - 1)) + dateiAnteil) / Double(laufDateiGesamt)
        laufFortschritt = min(0.99, max(laufFortschritt, stand))
    }

    static func sichereVorauswahl(ergebnis: ScanErgebnis) -> Set<String> {
        var ids = Set<String>()
        for g in ergebnis.duplikatGruppen + ergebnis.serienGruppen {
            for id in g.loeschbar {
                if let k = ergebnis.kandidaten.first(where: { $0.id == id }),
                   !k.istFavorit, !k.istAusgeblendet { ids.insert(id) }
            }
        }
        for k in ergebnis.kandidaten {
            let kat = Regeln.kategorien(fuer: k, jetzt: Date())
            guard kat.contains(.alteScreenshots), !k.istFavorit, !k.istAusgeblendet else { continue }
            ids.insert(k.id)
        }
        return ids
    }

    private func demoEinrichten() {
        let name = DemoDaten.screenshotPhase
        speicher = DemoDaten.speicher
        scan = DemoDaten.scan
        ausgewaehlt = DemoDaten.ausgewaehlt
        if name != "sichern" {
            sicherOrdnerName = "iCloud Drive, Ordner \(SicherungsNamen.unterordner)"
        }
        if name != "icloud" {
            ICloudFotosSpeicher.speichern(aktiv: true)
        }
        switch name {
        case "auswahl":
            phase = .auswahl
        case "sichern":
            phase = .sichern
        case "bestaetigen":
            phase = .bestaetigen
        case "bericht":
            speicherVorher = 4_300_000_000
            speicherNachher = speicher
            ergebnis = LoeschlaufErgebnis(
                geloescht: Array(DemoDaten.ausgewaehlt),
                nichtGeloescht: [:],
                protokoll: Protokoll()
            )
            phase = .bericht
        case "tipps":
            phase = .uebersicht
            tippsAnzeigen = true
        case "videos":
            phase = .uebersicht
            zeigeVideoVerkleinern = true
        case "icloud":
            phase = .uebersicht
            iCloudFotosFrageOffen = true
        case "fehler":
            scan = nil
            fehlerIstZugriff = true
            fehlerText = "Kein Zugriff auf Fotos. Tippe auf Einstellungen öffnen, dann auf Fotos, und wähle Alle Fotos. Komm danach zurück, die Prüfung startet von selbst."
            phase = .uebersicht
        case "lauf":
            phase = .lauf
            laufArt = .sichernUndLoeschen
            laufSchritt = .kopieren
            laufSchrittText = "Wird kopiert"
            laufFortschritt = 0.42
            laufText = "Urlaubsfilm.mov"
            laufDateiIndex = 2
            laufDateiGesamt = 5
            laufStartzeit = Date().addingTimeInterval(-80)
            dateiAnteil = 0.4
        case "scan":
            phase = .scannt
            scanFortschritt = 0.35
            scanText = "Fotos werden gelesen …"
        default:
            phase = .uebersicht
        }
    }
}
