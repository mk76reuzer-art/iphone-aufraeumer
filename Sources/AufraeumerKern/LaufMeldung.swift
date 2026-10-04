import Foundation

/// Fortschritt einer Datei im Sicherungs- und Löschlauf, für die Anzeige.
public struct LaufMeldung: Sendable, Equatable {
    public enum Schritt: String, Sendable, Equatable {
        case kopieren
        case pruefen
        case wartenAufCloud
        case loeschen
    }

    /// 1…gesamt
    public let index: Int
    public let gesamt: Int
    public let name: String
    public let schritt: Schritt

    public init(index: Int, gesamt: Int, name: String, schritt: Schritt) {
        self.index = index
        self.gesamt = gesamt
        self.name = name
        self.schritt = schritt
    }
}
