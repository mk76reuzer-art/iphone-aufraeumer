import Foundation

public struct Schwellen: Equatable, Sendable {
    public var grosseVideoBytes: Int64 = 50_000_000
    public var unberuehrtJahre: Int = 2
    public var screenshotTage: Int = 90
    /// Ab dieser Dauer gilt ein Video als lang, auch wenn es unter der Größengrenze liegt.
    public var langesVideoSekunden: Double = 180
    public init() {}
}

public enum Regeln {
    /// Ordnet einen Kandidaten den Kategorien zu. `.duplikate` entscheidet der `DuplikatFinder`.
    public static func kategorien(fuer k: Kandidat, jetzt: Date,
                                  schwellen: Schwellen = Schwellen(),
                                  kalender: Calendar = .current) -> Set<Kategorie> {
        var ergebnis = Set<Kategorie>()

        // Bildschirmfotos immer anzeigen, auch ohne Größenangabe und auch nur in iCloud.
        if k.istScreenshot || istBildschirmfotoName(k.name) {
            ergebnis.insert(.alteScreenshots)
        }

        guard k.groesseBytes > 0 else { return ergebnis }

        if k.istVideo && k.groesseBytes >= schwellen.grosseVideoBytes {
            ergebnis.insert(.grosseVideos)
        }
        if k.istVideo && (k.dauerSekunden ?? 0) >= schwellen.langesVideoSekunden {
            ergebnis.insert(.langeVideos)
        }
        if k.istVideo && (k.istBildschirmaufnahme || istBildschirmaufnahmeName(k.name)) {
            ergebnis.insert(.bildschirmaufnahmen)
        }
        if k.istVideo && istWhatsAppName(k.name) {
            ergebnis.insert(.whatsAppVideos)
        }
        if k.istLiveFoto {
            ergebnis.insert(.liveFotos)
        }
        if k.istRaw || istRawName(k.name) {
            ergebnis.insert(.rawFotos)
        }
        // Alte persönliche Aufnahmen nur, wenn sie wirklich auf dem iPhone liegen.
        if k.istLokalVorhanden, !k.istFavorit, !k.istBearbeitet, !k.inAlbum,
           let grenze = kalender.date(byAdding: .year, value: -schwellen.unberuehrtJahre, to: jetzt),
           k.aufnahme < grenze {
            ergebnis.insert(.langeUnberuehrt)
        }
        return ergebnis
    }

    /// Zählt für den freien Platz auf dem iPhone. Nur-iCloud bleibt sichtbar, macht aber fast nichts frei.
    public static func bringtPlatz(_ k: Kandidat) -> Bool {
        k.istLokalVorhanden && k.groesseBytes > 0 && !k.nurInCloud
    }

    public static func istBildschirmfotoName(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("bildschirmfoto") || n.contains("screenshot")
    }

    public static func istBildschirmaufnahmeName(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("bildschirmaufnahme") || n.contains("screen recording") || n.contains("rpreplay")
    }

    public static func istWhatsAppName(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("whatsapp") || n.contains("-wa")
    }

    public static func istRawName(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.hasSuffix(".dng") || n.hasSuffix(".raw") || n.contains("proraw")
    }

    /// Im Zweifel wird gesichert: sobald eine Kategorie Sicherung verlangt (oder keine bekannt ist).
    public static func modus(fuer kategorien: Set<Kategorie>) -> Modus {
        if kategorien.isEmpty || kategorien.contains(where: { $0.sichernNoetig }) {
            return .erstSichern
        }
        return .nurLoeschen
    }
}
