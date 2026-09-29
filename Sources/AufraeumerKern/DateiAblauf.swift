import Foundation

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

/// Zustandsautomat für genau eine Datei. Löschen ist nur im Zustand `freigegeben` erlaubt,
/// und dahin führt nur der vollständige Weg.
public struct DateiAblauf: Sendable {
    public let kandidat: Kandidat
    public let modus: Modus
    public private(set) var zustand: Zustand = .gefunden
    private var kopie: (bytes: Int64, pruefsumme: String)?

    public init(kandidat: Kandidat, modus: Modus) {
        self.kandidat = kandidat
        self.modus = modus
    }

    public var loeschenErlaubt: Bool { zustand == .freigegeben }

    public var istEnde: Bool {
        switch zustand {
        case .geloescht, .abgebrochen: return true
        default: return false
        }
    }

    private func unerlaubt(_ nach: String) -> AblaufFehler {
        .unerlaubterUebergang(von: "\(zustand)", nach: nach)
    }

    private mutating func uebergang(erlaubtVon erlaubt: [Zustand], nach neu: Zustand) throws {
        guard erlaubt.contains(zustand) else { throw unerlaubt("\(neu)") }
        zustand = neu
    }

    public mutating func auswaehlen() throws {
        try uebergang(erlaubtVon: [.gefunden], nach: .ausgewaehlt)
    }

    public mutating func kopiert(bytes: Int64, pruefsumme: String) throws {
        guard modus == .erstSichern else { throw unerlaubt("kopiert (Modus nurLoeschen)") }
        try uebergang(erlaubtVon: [.ausgewaehlt], nach: .kopiert)
        kopie = (bytes, pruefsumme)
    }

    public mutating func pruefen(originalBytes: Int64, originalPruefsumme: String) throws {
        guard zustand == .kopiert, let kopie = kopie else { throw unerlaubt("geprueft") }
        if kopie.bytes != originalBytes {
            zustand = .abgebrochen("Größe der Kopie stimmt nicht")
            throw AblaufFehler.groesseUngleich
        }
        if kopie.pruefsumme != originalPruefsumme {
            zustand = .abgebrochen("Prüfsumme der Kopie stimmt nicht")
            throw AblaufFehler.pruefsummeUngleich
        }
        zustand = .geprueft
    }

    public mutating func hochgeladen() throws {
        try uebergang(erlaubtVon: [.geprueft], nach: .hochgeladen)
    }

    public mutating func freigeben(favoritBestaetigt: Bool) throws {
        let vorher: Zustand = (modus == .erstSichern) ? .hochgeladen : .ausgewaehlt
        guard zustand == vorher else { throw unerlaubt("freigegeben") }
        if kandidat.istFavorit && !favoritBestaetigt { throw AblaufFehler.favoritOhneBestaetigung }
        zustand = .freigegeben
    }

    public mutating func geloescht() throws {
        try uebergang(erlaubtVon: [.freigegeben], nach: .geloescht)
    }

    public mutating func abbrechen(grund: String) throws {
        guard !istEnde else { throw unerlaubt("abgebrochen") }
        zustand = .abgebrochen(grund)
    }
}
