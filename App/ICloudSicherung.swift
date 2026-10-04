import Foundation
import AufraeumerKern

enum SicherungsNamen {
    static let unterordner = "Aufräumer-Sicherung"
}

enum OrdnerFehler: LocalizedError {
    case keinZugriff
    case nichtMerkbar

    var errorDescription: String? {
        switch self {
        case .keinZugriff:
            return "Auf den Ordner konnte nicht zugegriffen werden. Öffne den Ordner in der Dateien-App und tippe oben rechts auf Öffnen."
        case .nichtMerkbar:
            return "Der Ordner konnte nicht gemerkt werden. Wähle ihn bitte erneut."
        }
    }
}

/// Ablage in einem vom Nutzer gewählten Ordner der Dateien-App. Der Zugriff bleibt, bis die Sicherung endet.
final class ICloudSicherung: Sicherung, @unchecked Sendable {
    private let ordnerURL: URL
    private var dateien: [String: URL] = [:]
    private let lock = NSLock()
    let hatZugriff: Bool

    /// 0…1 während des Kopierens einer Datei.
    var kopierFortschritt: (@Sendable (Double) -> Void)?

    init(ordner: URL) {
        self.ordnerURL = ordner
        hatZugriff = ordner.startAccessingSecurityScopedResource()
    }

    deinit {
        if hatZugriff { ordnerURL.stopAccessingSecurityScopedResource() }
    }

    func legeHinweisAb() throws {
        guard hatZugriff else { throw OrdnerFehler.keinZugriff }
        let ordner = try unterordnerURL()
        let datei = ordner.appendingPathComponent("Liesmich.txt")
        let text = """
        Dieser Ordner gehört zur App Aufräumer.
        Hier liegen Kopien, bevor etwas in Fotos gelöscht wird.
        Du kannst den Ordner in der Dateien-App öffnen.
        """
        var koordinatorFehler: NSError?
        var schreibFehler: Error?
        NSFileCoordinator().coordinate(writingItemAt: datei, options: .forReplacing, error: &koordinatorFehler) { url in
            do { try Data(text.utf8).write(to: url, options: .atomic) }
            catch { schreibFehler = error }
        }
        if let fehler = koordinatorFehler ?? schreibFehler { throw fehler }
    }

    func ablegen(_ export: Export, name: String) async throws -> SicherungsBeleg {
        guard hatZugriff else { throw OrdnerFehler.keinZugriff }
        let sicher = name.replacingOccurrences(of: "/", with: "_")
        let basis = try unterordnerURL()
        let ziel = basis.appendingPathComponent("aufraeumer-\(export.pruefsumme.prefix(8))-\(sicher)")

        var koordinatorFehler: NSError?
        var schreibFehler: Error?
        let fortschritt = kopierFortschritt
        NSFileCoordinator().coordinate(writingItemAt: ziel, options: .forReplacing, error: &koordinatorFehler) { url in
            do {
                try DateiKopie.kopieren(von: export.datei, nach: url) { fortschritt?($0) }
            } catch { schreibFehler = error }
        }
        if let fehler = koordinatorFehler ?? schreibFehler { throw fehler }

        lock.lock()
        dateien[export.pruefsumme] = ziel
        lock.unlock()
        return SicherungsBeleg(kennung: export.pruefsumme)
    }

    func kopieLesen(_ beleg: SicherungsBeleg) async throws -> KopieInfo {
        guard hatZugriff else { throw DateiKopieFehler.lesen }
        let url = try url(fuer: beleg)
        var koordinatorFehler: NSError?
        var ergebnis: KopieInfo?
        var leseFehler: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &koordinatorFehler) { gelesen in
            do {
                let gemessen = try DateiPruefung.messen(url: gelesen)
                ergebnis = KopieInfo(bytes: gemessen.bytes, pruefsumme: gemessen.pruefsumme)
            } catch { leseFehler = error }
        }
        if let fehler = koordinatorFehler ?? leseFehler { throw fehler }
        guard let ergebnis else { throw DateiKopieFehler.lesen }
        return ergebnis
    }

    func istHochgeladen(_ beleg: SicherungsBeleg) async throws -> Bool {
        guard hatZugriff else { throw DateiKopieFehler.lesen }
        let url = try url(fuer: beleg)
        let w = try url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemIsUploadedKey,
            .ubiquitousItemIsUploadingKey
        ])
        if w.isUbiquitousItem != true { return true }
        return w.ubiquitousItemIsUploaded == true
    }

    private func unterordnerURL() throws -> URL {
        let url = ordnerURL.appendingPathComponent(SicherungsNamen.unterordner, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private func url(fuer beleg: SicherungsBeleg) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        guard let u = dateien[beleg.kennung] else { throw DateiKopieFehler.lesen }
        return u
    }
}

enum ICloudOrdnerSpeicher {
    private static let key = "aufraeumer.ordner.lesezeichen"
    private static let alterSchluessel = "aufraeumer.icloud.ordner"

    static func speichern(_ url: URL) throws {
        let zugriff = url.startAccessingSecurityScopedResource()
        defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
        guard zugriff else { throw OrdnerFehler.keinZugriff }
        let daten: Data
        do {
            daten = try url.bookmarkData(options: .minimalBookmark,
                                         includingResourceValuesForKeys: nil,
                                         relativeTo: nil)
        } catch {
            throw OrdnerFehler.nichtMerkbar
        }
        UserDefaults.standard.set(daten, forKey: key)
    }

    static func laden() -> URL? {
        let daten = UserDefaults.standard.data(forKey: key)
            ?? UserDefaults.standard.data(forKey: alterSchluessel)
        guard let daten else { return nil }
        var veraltet = false
        guard let url = try? URL(resolvingBookmarkData: daten, options: [], relativeTo: nil,
                                 bookmarkDataIsStale: &veraltet) else { return nil }
        if veraltet, url.startAccessingSecurityScopedResource() {
            if let neu = try? url.bookmarkData(options: .minimalBookmark,
                                               includingResourceValuesForKeys: nil,
                                               relativeTo: nil) {
                UserDefaults.standard.set(neu, forKey: key)
            }
            url.stopAccessingSecurityScopedResource()
        }
        return url
    }

    static func anzeigename(fuer url: URL) -> String {
        "\(url.lastPathComponent), Ordner \(SicherungsNamen.unterordner)"
    }
}
