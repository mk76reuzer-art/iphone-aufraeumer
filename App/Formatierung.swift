import Foundation

enum Formatierung {
    static func gigabytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 10 { return String(format: "%.0f GB", gb) }
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_000_000
        if mb >= 100 { return String(format: "%.0f MB", mb) }
        return String(format: "%.1f MB", mb)
    }

    static func prozent(_ wert: Double) -> String {
        String(format: "%.0f %%", min(100, max(0, wert * 100)))
    }

    static func datum(_ d: Date) -> String {
        d.formatted(date: .abbreviated, time: .omitted)
    }
}
