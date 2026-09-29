import Foundation

public struct Auswahl: Sendable {
    public let kandidat: Kandidat
    public let modus: Modus
    public let favoritBestaetigt: Bool
    public init(kandidat: Kandidat, modus: Modus, favoritBestaetigt: Bool) {
        self.kandidat = kandidat
        self.modus = modus
        self.favoritBestaetigt = favoritBestaetigt
    }
}

public struct LoeschlaufErgebnis: Sendable {
    public let geloescht: [String]
    /// Kennung → Grund, warum nicht gelöscht wurde.
    public let nichtGeloescht: [String: String]
    public let protokoll: Protokoll
}

public enum LoeschlaufFehler: Error, Equatable {
    case uploadZeitueberschreitung
    case nichtLokalOderGroesseUnbekannt
    case exportLeer
    case exportGroesseAbweichend
}

/// Steuert den ganzen Ablauf. Sicherheitsprinzip: Jede Unsicherheit führt zu „nicht löschen“.
public final class Loeschlauf: Sendable {
    private let bibliothek: any MedienBibliothek
    private let sicherung: any Sicherung
    private let wartezeit: TimeInterval
    private let pollIntervall: TimeInterval
    private let jetzt: @Sendable () -> Date
    private let aufEintrag: (@Sendable (ProtokollEintrag) -> Void)?

    public init(bibliothek: any MedienBibliothek, sicherung: any Sicherung,
                wartezeit: TimeInterval = 600, pollIntervall: TimeInterval = 2,
                jetzt: @escaping @Sendable () -> Date = { Date() },
                aufEintrag: (@Sendable (ProtokollEintrag) -> Void)? = nil) {
        self.bibliothek = bibliothek
        self.sicherung = sicherung
        self.wartezeit = wartezeit
        self.pollIntervall = pollIntervall
        self.jetzt = jetzt
        self.aufEintrag = aufEintrag
    }

    public func ausfuehren(auswahl: [Auswahl], gruppen: [DuplikatGruppe],
                           bestaetigt: Bool) async -> LoeschlaufErgebnis {
        var protokoll = Protokoll()
        var nicht: [String: String] = [:]
        let jetzt = self.jetzt
        let aufEintrag = self.aufEintrag

        func notiere(_ k: Kandidat, _ a: Aktion, _ grund: String? = nil) {
            let e = ProtokollEintrag(zeit: jetzt(), id: k.id, name: k.name,
                                     groesseBytes: k.groesseBytes, aktion: a, grund: grund)
            protokoll.hinzufuegen(e)
            aufEintrag?(e)
        }

        // Dieselbe Datei nur einmal verarbeiten. Bei widersprüchlichen Angaben gilt die vorsichtigere:
        // gesichert wird, sobald ein Eintrag es verlangt; ein Favorit gilt nur als bestätigt, wenn alle bestätigen.
        var reihenfolge: [String] = []
        var zusammen: [String: Auswahl] = [:]
        for a in auswahl {
            let id = a.kandidat.id
            if let vorhanden = zusammen[id] {
                zusammen[id] = Auswahl(
                    kandidat: vorhanden.kandidat,
                    modus: (vorhanden.modus == .erstSichern || a.modus == .erstSichern) ? .erstSichern : .nurLoeschen,
                    favoritBestaetigt: vorhanden.favoritBestaetigt && a.favoritBestaetigt)
            } else {
                zusammen[id] = a
                reihenfolge.append(id)
            }
        }
        let einzeln = reihenfolge.compactMap { zusammen[$0] }

        guard bestaetigt else {
            for a in einzeln {
                nicht[a.kandidat.id] = "Keine Bestätigung"
                notiere(a.kandidat, .abgebrochen, "Keine Bestätigung")
            }
            return LoeschlaufErgebnis(geloescht: [], nichtGeloescht: nicht, protokoll: protokoll)
        }

        // Stufe 1: je Datei sichern und prüfen (nur im Modus erstSichern), dann freigeben.
        var abl: [String: DateiAblauf] = [:]
        for a in einzeln {
            let k = a.kandidat
            var ablauf = DateiAblauf(kandidat: k, modus: a.modus)
            do {
                if Task.isCancelled { throw CancellationError() }
                guard k.istLokalVorhanden, k.groesseBytes > 0 else {
                    throw LoeschlaufFehler.nichtLokalOderGroesseUnbekannt
                }
                try ablauf.auswaehlen()
                if a.modus == .erstSichern {
                    let export = try await bibliothek.exportieren(id: k.id)
                    defer { try? FileManager.default.removeItem(at: export.datei) }
                    guard export.bytes > 0 else { throw LoeschlaufFehler.exportLeer }
                    guard export.bytes == k.groesseBytes else { throw LoeschlaufFehler.exportGroesseAbweichend }
                    let beleg = try await sicherung.ablegen(export, name: k.name)
                    let kopie = try await sicherung.kopieLesen(beleg)
                    try ablauf.kopiert(bytes: kopie.bytes, pruefsumme: kopie.pruefsumme)
                    try ablauf.pruefen(originalBytes: export.bytes, originalPruefsumme: export.pruefsumme)
                    try await warteAufUpload(beleg)
                    try ablauf.hochgeladen()
                    notiere(k, .gesichert)
                }
                try ablauf.freigeben(favoritBestaetigt: a.favoritBestaetigt)
            } catch {
                let grund = Loeschlauf.beschreibe(error)
                try? ablauf.abbrechen(grund: grund)
                nicht[k.id] = grund
                notiere(k, .abgebrochen, grund)
            }
            abl[k.id] = ablauf
        }

        // Stufe 2: Kandidaten für das Löschen bestimmen.
        var zuLoeschen = einzeln.map(\.kandidat.id).filter { abl[$0]?.loeschenErlaubt == true }

        // Das zu behaltende Exemplar einer Duplikatgruppe wird nur gelöscht, wenn es selbst eine geprüfte
        // Sicherung hat. Das gilt unabhängig davon, was sonst ausgewählt ist (auch bei veralteten Gruppen).
        for g in gruppen where zuLoeschen.contains(g.behalten) {
            if abl[g.behalten]?.modus == .erstSichern { continue }
            guard let behalten = abl[g.behalten] else { continue }
            zuLoeschen.removeAll { $0 == g.behalten }
            let grund = "Letztes Exemplar einer Duplikatgruppe bleibt erhalten"
            nicht[g.behalten] = grund
            notiere(behalten.kandidat, .abgebrochen, grund)
        }

        // Ein abgebrochener Vorgang löscht nichts mehr.
        if Task.isCancelled {
            for id in zuLoeschen {
                nicht[id] = "Vorgang abgebrochen"
                if let a = abl[id] { notiere(a.kandidat, .abgebrochen, "Vorgang abgebrochen") }
            }
            return LoeschlaufErgebnis(geloescht: [], nichtGeloescht: nicht, protokoll: protokoll)
        }

        guard !zuLoeschen.isEmpty else {
            return LoeschlaufErgebnis(geloescht: [], nichtGeloescht: nicht, protokoll: protokoll)
        }

        // Stufe 3: erst „beabsichtigt“ festhalten, dann löschen, dann Ergebnis festhalten.
        for id in zuLoeschen { if let a = abl[id] { notiere(a.kandidat, .beabsichtigt) } }
        do {
            try await bibliothek.loeschen(ids: zuLoeschen)
            for id in zuLoeschen {
                _ = try? abl[id]?.geloescht()
                if let a = abl[id] { notiere(a.kandidat, .geloescht) }
            }
            return LoeschlaufErgebnis(geloescht: zuLoeschen, nichtGeloescht: nicht, protokoll: protokoll)
        } catch {
            let grund = "Löschen nicht ausgeführt: \(Loeschlauf.beschreibe(error))"
            for id in zuLoeschen {
                nicht[id] = grund
                if let a = abl[id] { notiere(a.kandidat, .abgebrochen, grund) }
            }
            return LoeschlaufErgebnis(geloescht: [], nichtGeloescht: nicht, protokoll: protokoll)
        }
    }

    private func warteAufUpload(_ beleg: SicherungsBeleg) async throws {
        let ende = Date().addingTimeInterval(wartezeit)
        while true {
            if try await sicherung.istHochgeladen(beleg) { return }
            if Date() >= ende { throw LoeschlaufFehler.uploadZeitueberschreitung }
            try await Task.sleep(nanoseconds: UInt64(pollIntervall * 1_000_000_000))
        }
    }

    static func beschreibe(_ fehler: Error) -> String {
        if fehler is CancellationError { return "Vorgang abgebrochen" }
        if let a = fehler as? AblaufFehler {
            switch a {
            case .groesseUngleich: return "Größe der Kopie stimmt nicht"
            case .pruefsummeUngleich: return "Prüfsumme der Kopie stimmt nicht"
            case .favoritOhneBestaetigung: return "Favorit ohne ausdrückliche Bestätigung"
            case .unerlaubterUebergang(let von, let nach): return "Unerlaubter Übergang \(von) → \(nach)"
            }
        }
        if let l = fehler as? LoeschlaufFehler {
            switch l {
            case .uploadZeitueberschreitung: return "Upload nicht rechtzeitig fertig"
            case .nichtLokalOderGroesseUnbekannt: return "Datei nicht lokal vorhanden oder Größe unbekannt"
            case .exportLeer: return "Export ist leer"
            case .exportGroesseAbweichend: return "Größe des Exports weicht vom Original ab"
            }
        }
        return "Fehler: \(fehler.localizedDescription)"
    }
}
