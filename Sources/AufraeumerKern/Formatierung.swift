import Foundation

public enum Formatierung {
    public static func gigabytes(_ bytes: Int64) -> String {
        if bytes <= 0 { return "0 MB" }
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 10 { return "\(zahl(gb, stellen: 0)) GB" }
        if gb >= 1 { return "\(zahl(gb, stellen: 1)) GB" }
        let mb = Double(bytes) / 1_000_000
        if mb >= 100 { return "\(zahl(mb, stellen: 0)) MB" }
        if mb >= 1 { return "\(zahl(mb, stellen: 1)) MB" }
        let kb = Double(bytes) / 1_000
        if kb >= 1 { return "\(zahl(kb, stellen: 0)) KB" }
        return "\(bytes) Byte"
    }

    public static func prozent(_ wert: Double) -> String {
        String(format: "%.0f %%", min(100, max(0, wert * 100)))
    }

    public static func datum(_ d: Date) -> String {
        d.formatted(date: .abbreviated, time: .omitted)
    }

    public static func restzeit(sekunden: TimeInterval) -> String {
        guard sekunden.isFinite, sekunden >= 0 else { return "" }
        if sekunden <= 3 { return "gleich fertig" }
        if sekunden < 60 { return "noch etwa \(Int(sekunden)) Sekunden" }
        let minuten = Int(sekunden / 60)
        if minuten == 1 { return "noch etwa 1 Minute" }
        return "noch etwa \(minuten) Minuten"
    }

    private static func zahl(_ wert: Double, stellen: Int) -> String {
        let format = NumberFormatter()
        format.locale = Locale(identifier: "de_DE")
        format.numberStyle = .decimal
        format.minimumFractionDigits = stellen
        format.maximumFractionDigits = stellen
        return format.string(from: NSNumber(value: wert)) ?? String(format: "%.\(stellen)f", wert)
    }
}
