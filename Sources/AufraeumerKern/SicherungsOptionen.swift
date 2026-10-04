import Foundation

/// Welche Kategorien vor dem Löschen extra in den Nutzerordner kopiert werden.
public struct SicherungsOptionen: Equatable, Sendable {
    public var duplikateSichern: Bool
    public var serienSichern: Bool
    public var screenshotsSichern: Bool

    public init(duplikateSichern: Bool = false, serienSichern: Bool = false, screenshotsSichern: Bool = false) {
        self.duplikateSichern = duplikateSichern
        self.serienSichern = serienSichern
        self.screenshotsSichern = screenshotsSichern
    }

    public func effektiverModus(kategorien: Set<Kategorie>, basis: Modus? = nil) -> Modus {
        let basis = basis ?? Regeln.modus(fuer: kategorien)
        if basis == .nurLoeschen { return .nurLoeschen }
        let brauchtOrdner = kategorien.contains { kat in
            switch kat {
            case .grosseVideos, .langeUnberuehrt: return true
            case .duplikate: return duplikateSichern
            case .serienbilder: return serienSichern
            case .alteScreenshots: return screenshotsSichern
            }
        }
        return brauchtOrdner ? .erstSichern : .nurLoeschen
    }
}
