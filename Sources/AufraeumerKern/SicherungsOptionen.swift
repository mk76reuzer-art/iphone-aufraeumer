import Foundation

/// Welche Kategorien vor dem Löschen extra in den Nutzerordner kopiert werden.
public struct SicherungsOptionen: Equatable, Sendable {
    public var duplikateSichern: Bool
    public var serienSichern: Bool
    public var screenshotsSichern: Bool
    /// Empfehlung für große und persönliche Dateien. Ausgeschaltet heißt: ohne Kopie löschen.
    public var grosseSichern: Bool

    public init(duplikateSichern: Bool = false, serienSichern: Bool = false,
                screenshotsSichern: Bool = false, grosseSichern: Bool = true) {
        self.duplikateSichern = duplikateSichern
        self.serienSichern = serienSichern
        self.screenshotsSichern = screenshotsSichern
        self.grosseSichern = grosseSichern
    }

    public func effektiverModus(kategorien: Set<Kategorie>) -> Modus {
        let brauchtOrdner = kategorien.contains { kat in
            switch kat {
            case .grosseVideos, .langeVideos, .bildschirmaufnahmen, .whatsAppVideos,
                 .rawFotos, .liveFotos, .langeUnberuehrt:
                return grosseSichern
            case .duplikate: return duplikateSichern
            case .serienbilder: return serienSichern
            case .alteScreenshots: return screenshotsSichern
            }
        }
        return brauchtOrdner ? .erstSichern : .nurLoeschen
    }
}
