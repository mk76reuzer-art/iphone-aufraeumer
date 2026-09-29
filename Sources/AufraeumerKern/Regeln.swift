import Foundation

public struct Schwellen: Equatable, Sendable {
    public var grosseVideoBytes: Int64 = 50_000_000
    public var unberuehrtJahre: Int = 2
    public var screenshotTage: Int = 90
    public init() {}
}

public enum Regeln {
    /// Ordnet einen Kandidaten den Kategorien zu. `.duplikate` entscheidet der `DuplikatFinder`.
    public static func kategorien(fuer k: Kandidat, jetzt: Date,
                                  schwellen: Schwellen = Schwellen(),
                                  kalender: Calendar = .current) -> Set<Kategorie> {
        guard k.istLokalVorhanden, k.groesseBytes > 0 else { return [] }
        var ergebnis = Set<Kategorie>()

        if k.istVideo && k.groesseBytes >= schwellen.grosseVideoBytes {
            ergebnis.insert(.grosseVideos)
        }
        if k.istScreenshot,
           let grenze = kalender.date(byAdding: .day, value: -schwellen.screenshotTage, to: jetzt),
           k.aufnahme < grenze {
            ergebnis.insert(.alteScreenshots)
        }
        if !k.istFavorit, !k.istBearbeitet, !k.inAlbum,
           let grenze = kalender.date(byAdding: .year, value: -schwellen.unberuehrtJahre, to: jetzt),
           k.aufnahme < grenze {
            ergebnis.insert(.langeUnberuehrt)
        }
        return ergebnis
    }

    /// Im Zweifel wird gesichert: sobald eine Kategorie Sicherung verlangt (oder keine bekannt ist).
    public static func modus(fuer kategorien: Set<Kategorie>) -> Modus {
        if kategorien.isEmpty || kategorien.contains(where: { $0.sichernNoetig }) {
            return .erstSichern
        }
        return .nurLoeschen
    }
}
