import Foundation
import CryptoKit

public enum DateiKopieFehler: Error, Equatable, LocalizedError {
    case zuWenigPlatz
    case lesen
    case schreiben

    public var errorDescription: String? {
        switch self {
        case .zuWenigPlatz:
            return "Zu wenig freier Speicher für die Kopie. Leere zuerst Zuletzt gelöscht in der Fotos-App und versuche es erneut."
        case .lesen:
            return "Die Datei konnte nicht gelesen werden. Prüfe erneut und wähle sie noch einmal."
        case .schreiben:
            return "Die Kopie konnte nicht geschrieben werden. Wähle einen anderen Ordner, zum Beispiel in iCloud Drive."
        }
    }
}

/// Größe und SHA-256, ohne die Datei in den Arbeitsspeicher zu laden.
public enum DateiPruefung {
    public static func messen(url: URL) throws -> (bytes: Int64, pruefsumme: String) {
        let werte = try FileManager.default.attributesOfItem(atPath: url.path)
        let groesse = (werte[.size] as? NSNumber)?.int64Value ?? 0
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let stueck = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if stueck.isEmpty { break }
            hasher.update(data: stueck)
        }
        let summe = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return (groesse, summe)
    }
}

/// Kopiert in Stücken und meldet 0…1. Ersetzt die Datei am Ziel.
public enum DateiKopie {
    public static func kopieren(von quelle: URL, nach ziel: URL,
                                beiFortschritt: ((Double) -> Void)? = nil) throws {
        let werte = try FileManager.default.attributesOfItem(atPath: quelle.path)
        let groesse = (werte[.size] as? NSNumber)?.int64Value ?? 0
        guard groesse > 0 else { throw DateiKopieFehler.lesen }
        if FileManager.default.fileExists(atPath: ziel.path) {
            try FileManager.default.removeItem(at: ziel)
        }
        FileManager.default.createFile(atPath: ziel.path, contents: nil)
        let lesen = try FileHandle(forReadingFrom: quelle)
        let schreiben = try FileHandle(forWritingTo: ziel)
        defer {
            try? lesen.close()
            try? schreiben.close()
        }
        var kopiert: Int64 = 0
        beiFortschritt?(0)
        while true {
            let stueck: Data
            do { stueck = try lesen.read(upToCount: 1024 * 1024) ?? Data() }
            catch { throw DateiKopieFehler.lesen }
            if stueck.isEmpty { break }
            do { try schreiben.write(contentsOf: stueck) }
            catch {
                let ns = error as NSError
                if ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError {
                    throw DateiKopieFehler.zuWenigPlatz
                }
                throw DateiKopieFehler.schreiben
            }
            kopiert += Int64(stueck.count)
            if groesse > 0 { beiFortschritt?(Double(kopiert) / Double(groesse)) }
        }
        try schreiben.synchronize()
        guard kopiert == groesse else { throw DateiKopieFehler.schreiben }
        beiFortschritt?(1)
    }
}
