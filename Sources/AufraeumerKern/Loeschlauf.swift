import Foundation

// ATTRAPPE FÜR DEN ROT-SCHRITT: absichtlich gefährlich falsch (löscht alles sofort, ohne
// Bestätigung, ohne Sicherung, ohne Protokoll). Wird im nächsten Commit durch die echte Umsetzung ersetzt.

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
}

public final class Loeschlauf: Sendable {
    private let bibliothek: any MedienBibliothek

    public init(bibliothek: any MedienBibliothek, sicherung: any Sicherung,
                wartezeit: TimeInterval = 600, pollIntervall: TimeInterval = 2,
                jetzt: @escaping @Sendable () -> Date = { Date() },
                aufEintrag: (@Sendable (ProtokollEintrag) -> Void)? = nil) {
        self.bibliothek = bibliothek
    }

    public func ausfuehren(auswahl: [Auswahl], gruppen: [DuplikatGruppe],
                           bestaetigt: Bool) async -> LoeschlaufErgebnis {
        let ids = auswahl.map(\.kandidat.id)
        try? await bibliothek.loeschen(ids: ids)
        return LoeschlaufErgebnis(geloescht: ids, nichtGeloescht: [:], protokoll: Protokoll())
    }
}
