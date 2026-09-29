import Foundation

// ATTRAPPE FÜR DEN ROT-SCHRITT: absichtlich falsch (erlaubt alles, prüft nichts).
// Wird im nächsten Commit durch die echte Umsetzung ersetzt.

public enum Zustand: Equatable, Sendable {
    case gefunden, ausgewaehlt, kopiert, geprueft, hochgeladen, freigegeben, geloescht
    case abgebrochen(String)
}

public enum AblaufFehler: Error, Equatable {
    case unerlaubterUebergang(von: String, nach: String)
    case groesseUngleich
    case pruefsummeUngleich
    case favoritOhneBestaetigung
}

public struct DateiAblauf: Sendable {
    public let kandidat: Kandidat
    public let modus: Modus
    public private(set) var zustand: Zustand = .gefunden

    public init(kandidat: Kandidat, modus: Modus) {
        self.kandidat = kandidat
        self.modus = modus
    }

    public var loeschenErlaubt: Bool { true }
    public var istEnde: Bool { false }

    public mutating func auswaehlen() throws {}
    public mutating func kopiert(bytes: Int64, pruefsumme: String) throws {}
    public mutating func pruefen(originalBytes: Int64, originalPruefsumme: String) throws {}
    public mutating func hochgeladen() throws {}
    public mutating func freigeben(favoritBestaetigt: Bool) throws {}
    public mutating func geloescht() throws {}
    public mutating func abbrechen(grund: String) throws {}
}
