import Foundation

public enum Kategorie: String, Codable, CaseIterable, Sendable {
    case grosseVideos, langeUnberuehrt, duplikate, alteScreenshots

    /// Kategorien, deren Dateien vor dem Löschen zuerst gesichert werden müssen.
    public var sichernNoetig: Bool {
        self == .grosseVideos || self == .langeUnberuehrt
    }
}

public enum Modus: Equatable, Sendable {
    case nurLoeschen
    case erstSichern
}

public struct Kandidat: Equatable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    /// Lokal belegte Größe in Bytes; 0 bedeutet unbekannt.
    public let groesseBytes: Int64
    public let aufnahme: Date
    public let dauerSekunden: Double?
    public let istVideo: Bool
    public let istScreenshot: Bool
    public let istFavorit: Bool
    public let istBearbeitet: Bool
    public let inAlbum: Bool
    public let istAusgeblendet: Bool
    public let istLokalVorhanden: Bool

    public init(id: String, name: String, groesseBytes: Int64, aufnahme: Date,
                dauerSekunden: Double?, istVideo: Bool, istScreenshot: Bool,
                istFavorit: Bool, istBearbeitet: Bool, inAlbum: Bool,
                istAusgeblendet: Bool, istLokalVorhanden: Bool) {
        self.id = id
        self.name = name
        self.groesseBytes = groesseBytes
        self.aufnahme = aufnahme
        self.dauerSekunden = dauerSekunden
        self.istVideo = istVideo
        self.istScreenshot = istScreenshot
        self.istFavorit = istFavorit
        self.istBearbeitet = istBearbeitet
        self.inAlbum = inAlbum
        self.istAusgeblendet = istAusgeblendet
        self.istLokalVorhanden = istLokalVorhanden
    }
}
