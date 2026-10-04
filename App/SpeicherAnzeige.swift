import Foundation

struct SpeicherStand: Equatable, Sendable {
    var freiBytes: Int64
    var belegtBytes: Int64
    var gesamtBytes: Int64
    var medienBelegtBytes: Int64
    var groessteKategorie: (name: String, bytes: Int64)?
}

enum SpeicherAnzeige {
    static func lesen() -> SpeicherStand? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let werte = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]),
              let frei = werte.volumeAvailableCapacityForImportantUsage,
              let gesamt = werte.volumeTotalCapacity else { return nil }
        let freiB = Int64(frei)
        let gesamtB = Int64(gesamt)
        let belegt = max(0, gesamtB - freiB)
        return SpeicherStand(freiBytes: freiB, belegtBytes: belegt, gesamtBytes: gesamtB,
                             medienBelegtBytes: 0, groessteKategorie: nil)
    }
}
