import Foundation

public struct DuplikatGruppe: Equatable, Sendable {
    /// Dieses Exemplar bleibt erhalten.
    public let behalten: String
    public let loeschbar: [String]
    public var alleIds: [String] { [behalten] + loeschbar }

    public init(behalten: String, loeschbar: [String]) {
        self.behalten = behalten
        self.loeschbar = loeschbar
    }
}

public enum DuplikatFinder {
    /// Gruppiert zuerst nach Größe (billig), bildet nur für gleich große Dateien die Prüfsumme
    /// und fasst Dateien mit gleicher Prüfsumme zusammen. Die gespeicherte Dauer wird nicht verglichen.
    public static func gruppen(aus kandidaten: [Kandidat],
                               pruefsumme: (String) throws -> String) rethrows -> [DuplikatGruppe] {
        let tauglich = kandidaten.filter { $0.istLokalVorhanden && $0.groesseBytes > 0 }
        let nachGroesse = Dictionary(grouping: tauglich, by: { $0.groesseBytes })
        var ergebnis: [DuplikatGruppe] = []

        for (_, gleichGross) in nachGroesse where gleichGross.count >= 2 {
            var nachSumme: [String: [Kandidat]] = [:]
            for k in gleichGross {
                let summe = try pruefsumme(k.id)
                nachSumme[summe, default: []].append(k)
            }
            for (_, gleich) in nachSumme where gleich.count >= 2 {
                let sortiert = gleich.sorted { a, b in
                    if a.istFavorit != b.istFavorit { return a.istFavorit }
                    if a.aufnahme != b.aufnahme { return a.aufnahme < b.aufnahme }
                    return a.id < b.id
                }
                ergebnis.append(DuplikatGruppe(
                    behalten: sortiert[0].id,
                    loeschbar: sortiert.dropFirst().map(\.id).sorted()))
            }
        }
        return ergebnis.sorted { $0.behalten < $1.behalten }
    }
}
