import Foundation
import CryptoKit
import AufraeumerKern

/// Ablage in einem vom Nutzer gewählten iCloud-Drive-Ordner (Lesezeichen).
final class ICloudSicherung: Sicherung, @unchecked Sendable {
    private let ordnerURL: URL
    private var dateien: [String: URL] = [:]
    private let lock = NSLock()

    /// Fortschritt 0…1 während des Hochladens (vom Aufrufer auf dem Hauptthread beobachten).
    var uploadFortschritt: (@Sendable (Double) -> Void)?

    init(ordner: URL) {
        self.ordnerURL = ordner
    }

    func ablegen(_ export: Export, name: String) async throws -> SicherungsBeleg {
        let zugriff = ordnerURL.startAccessingSecurityScopedResource()
        defer { if zugriff { ordnerURL.stopAccessingSecurityScopedResource() } }

        let sicher = name.replacingOccurrences(of: "/", with: "_")
        let ziel = ordnerURL.appendingPathComponent("aufraeumer-\(export.pruefsumme.prefix(8))-\(sicher)")

        var koordinatorFehler: NSError?
        var schreibFehler: Error?
        NSFileCoordinator().coordinate(writingItemAt: ziel, options: .forReplacing, error: &koordinatorFehler) { url in
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try FileManager.default.copyItem(at: export.datei, to: url)
            } catch { schreibFehler = error }
        }
        if let fehler = koordinatorFehler ?? schreibFehler { throw fehler }

        lock.lock()
        dateien[export.pruefsumme] = ziel
        lock.unlock()
        return SicherungsBeleg(kennung: export.pruefsumme)
    }

    func kopieLesen(_ beleg: SicherungsBeleg) async throws -> KopieInfo {
        let url = try url(fuer: beleg)
        let daten = try Data(contentsOf: url)
        let summe = SHA256.hash(data: daten).map { String(format: "%02x", $0) }.joined()
        return KopieInfo(bytes: Int64(daten.count), pruefsumme: summe)
    }

    func istHochgeladen(_ beleg: SicherungsBeleg) async throws -> Bool {
        let url = try url(fuer: beleg)
        let w = try url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemIsUploadedKey,
            .ubiquitousItemIsUploadingKey
        ])
        if w.isUbiquitousItem != true { return true }
        if w.ubiquitousItemIsUploading == true {
            uploadFortschritt?(0.5)
        }
        return w.ubiquitousItemIsUploaded == true
    }

    private func url(fuer beleg: SicherungsBeleg) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        guard let u = dateien[beleg.kennung] else {
            throw NSError(domain: "ICloudSicherung", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Sicherungsdatei nicht gefunden"])
        }
        return u
    }
}

enum ICloudOrdnerSpeicher {
    private static let key = "aufraeumer.icloud.ordner"

    static func speichern(_ url: URL) throws {
        let daten = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil,
                                         relativeTo: nil)
        UserDefaults.standard.set(daten, forKey: key)
    }

    static func laden() -> URL? {
        guard let daten = UserDefaults.standard.data(forKey: key) else { return nil }
        var veraltet = false
        return try? URL(resolvingBookmarkData: daten, options: [], relativeTo: nil,
                        bookmarkDataIsStale: &veraltet)
    }
}
