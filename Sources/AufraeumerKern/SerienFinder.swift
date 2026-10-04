import Foundation

/// Serien- und Burst-Aufnahmen: in jeder Gruppe bleibt ein Bild erhalten (wie bei Duplikaten).
public enum SerienFinder {
    /// `serienKennung` kommt z. B. aus dem Burst-Kennzeichen der Fotos-Bibliothek.
    public static func gruppen(
        aus eintraege: [(kandidat: Kandidat, serienKennung: String)],
        mindestAnzahl: Int = 3
    ) -> [DuplikatGruppe] {
        guard mindestAnzahl >= 2 else { return [] }
        // Auch nur in iCloud: Serien werden gezählt. Die Oberfläche sagt dann, dass Löschen die Cloud mittrifft.
        let tauglich = eintraege.filter { $0.kandidat.groesseBytes > 0 && !$0.kandidat.istVideo }
        let nachSerie = Dictionary(grouping: tauglich, by: \.serienKennung)
        var ergebnis: [DuplikatGruppe] = []

        for (_, gruppe) in nachSerie where gruppe.count >= mindestAnzahl {
            let kandidaten = gruppe.map(\.kandidat)
            let sortiert = kandidaten.sorted { a, b in
                if a.istFavorit != b.istFavorit { return a.istFavorit }
                if a.aufnahme != b.aufnahme { return a.aufnahme < b.aufnahme }
                return a.id < b.id
            }
            ergebnis.append(DuplikatGruppe(
                behalten: sortiert[0].id,
                loeschbar: sortiert.dropFirst().map(\.id).sorted()))
        }
        return ergebnis.sorted { $0.behalten < $1.behalten }
    }
}
