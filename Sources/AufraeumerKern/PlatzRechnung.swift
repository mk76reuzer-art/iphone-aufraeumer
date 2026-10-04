import Foundation

/// Kategorien einer Datei so, wie der Scanner sie gemeldet hat.
public enum KategorieBlick {
    public static func von(id: String, kategorien: [Kategorie: Set<String>]) -> Set<Kategorie> {
        Set(kategorien.compactMap { kat, ids in ids.contains(id) ? kat : nil })
    }
}

/// Summen für die Anzeige. Jede Datei zählt nur einmal, auch wenn sie in zwei Gruppen steht.
public enum PlatzRechnung {
    public static let reihenfolge: [Kategorie] = [
        .grosseVideos, .langeVideos, .bildschirmaufnahmen, .whatsAppVideos,
        .rawFotos, .liveFotos, .langeUnberuehrt, .duplikate, .serienbilder, .alteScreenshots
    ]

    public static func eindeutig(bytesJeId: [String: Int64], kategorien: [Kategorie: Set<String>]) -> Int64 {
        var gesehen = Set<String>()
        var summe: Int64 = 0
        for ids in kategorien.values {
            for id in ids where gesehen.insert(id).inserted {
                summe += bytesJeId[id] ?? 0
            }
        }
        return summe
    }

    public static func hauptkategorie(id: String, kategorien: [Kategorie: Set<String>]) -> Kategorie? {
        reihenfolge.first { kategorien[$0]?.contains(id) == true }
    }
}
