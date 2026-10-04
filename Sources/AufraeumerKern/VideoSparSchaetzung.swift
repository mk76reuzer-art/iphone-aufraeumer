import Foundation

/// Grobe Schätzung, wie viel Speicher HEVC 1080p statt des Originals spart (ohne echtes Transkodieren).
public enum VideoSparSchaetzung {
    /// Anteil der Größe nach Verkleinerung (konservativ, damit die Anzeige nicht zu optimistisch wirkt).
    public static func geschaetzteGroesseNachher(bytes: Int64, dauerSekunden: Double?) -> Int64 {
        guard bytes > 0 else { return 0 }
        let dauer = max(1, dauerSekunden ?? 60)
        let mbProMinute = Double(bytes) / dauer / 60.0 / 1_000_000.0
        let faktor: Double
        if mbProMinute > 25 { faktor = 0.35 }
        else if mbProMinute > 12 { faktor = 0.45 }
        else { faktor = 0.55 }
        return max(1, Int64(Double(bytes) * faktor))
    }

    public static func geschaetzteErsparnis(bytes: Int64, dauerSekunden: Double?) -> Int64 {
        max(0, bytes - geschaetzteGroesseNachher(bytes: bytes, dauerSekunden: dauerSekunden))
    }
}
