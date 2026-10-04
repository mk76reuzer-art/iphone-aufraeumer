import Foundation

public enum Kategorie: String, Codable, CaseIterable, Sendable {
    case grosseVideos, langeVideos, bildschirmaufnahmen, whatsAppVideos
    case rawFotos, liveFotos, langeUnberuehrt, duplikate, serienbilder, alteScreenshots

    /// Große oder persönliche Dateien: Sicherung wird empfohlen, ist aber keine Pflicht.
    public var sichernNoetig: Bool {
        switch self {
        case .grosseVideos, .langeVideos, .bildschirmaufnahmen, .whatsAppVideos,
             .rawFotos, .liveFotos, .langeUnberuehrt:
            return true
        case .duplikate, .serienbilder, .alteScreenshots:
            return false
        }
    }

    public var anzeigeName: String {
        switch self {
        case .grosseVideos: return "Große Videos"
        case .langeVideos: return "Lange Videos"
        case .bildschirmaufnahmen: return "Bildschirmaufnahmen"
        case .whatsAppVideos: return "WhatsApp-Videos"
        case .rawFotos: return "RAW-Fotos"
        case .liveFotos: return "Live-Fotos"
        case .langeUnberuehrt: return "Alte Aufnahmen"
        case .duplikate: return "Doppelte Fotos"
        case .serienbilder: return "Ähnliche Serienbilder"
        case .alteScreenshots: return "Bildschirmfotos"
        }
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
    public let istLiveFoto: Bool
    public let istRaw: Bool
    public let istBildschirmaufnahme: Bool
    /// Bekannt nur in iCloud. Unbekannt gilt nicht als nur-Cloud.
    public let nurInCloud: Bool

    public init(id: String, name: String, groesseBytes: Int64, aufnahme: Date,
                dauerSekunden: Double?, istVideo: Bool, istScreenshot: Bool,
                istFavorit: Bool, istBearbeitet: Bool, inAlbum: Bool,
                istAusgeblendet: Bool, istLokalVorhanden: Bool,
                istLiveFoto: Bool = false, istRaw: Bool = false,
                istBildschirmaufnahme: Bool = false, nurInCloud: Bool = false) {
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
        self.istLiveFoto = istLiveFoto
        self.istRaw = istRaw
        self.istBildschirmaufnahme = istBildschirmaufnahme
        self.nurInCloud = nurInCloud
    }
}
