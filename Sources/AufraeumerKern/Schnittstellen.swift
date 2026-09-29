import Foundation

public struct Export: Sendable {
    public let datei: URL
    public let bytes: Int64
    public let pruefsumme: String
    public init(datei: URL, bytes: Int64, pruefsumme: String) {
        self.datei = datei
        self.bytes = bytes
        self.pruefsumme = pruefsumme
    }
}

public struct SicherungsBeleg: Hashable, Sendable {
    public let kennung: String
    public init(kennung: String) { self.kennung = kennung }
}

public struct KopieInfo: Sendable {
    public let bytes: Int64
    public let pruefsumme: String
    public init(bytes: Int64, pruefsumme: String) {
        self.bytes = bytes
        self.pruefsumme = pruefsumme
    }
}

/// Zugriff auf die Mediathek (in der App über PhotoKit umgesetzt).
public protocol MedienBibliothek: Sendable {
    /// Schreibt das Original in eine temporäre Datei und liefert Größe und SHA-256.
    func exportieren(id: String) async throws -> Export
    /// Löscht in einem Zug; wirft, wenn der Nutzer die iOS-Abfrage ablehnt oder das Löschen scheitert.
    func loeschen(ids: [String]) async throws
}

/// Ablage in der Cloud (in der App: ein iCloud-Drive-Ordner).
public protocol Sicherung: Sendable {
    func ablegen(_ export: Export, name: String) async throws -> SicherungsBeleg
    /// Liest die abgelegte Kopie erneut und liefert deren Größe und SHA-256.
    func kopieLesen(_ beleg: SicherungsBeleg) async throws -> KopieInfo
    func istHochgeladen(_ beleg: SicherungsBeleg) async throws -> Bool
}
