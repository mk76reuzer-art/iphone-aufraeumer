import Foundation
import CryptoKit
import Security

/// Schreibt eine 5-MB-Testdatei in einen vom Nutzer gewählten iCloud-Drive-Ordner und beobachtet,
/// ob iOS den Upload-Status („hochgeladen“) für diese Datei meldet.
enum ICloudProbe {
    static func lauf(ordner: URL, ausgabe: @escaping @MainActor (String) -> Void) async {
        let zugriff = ordner.startAccessingSecurityScopedResource()
        defer { if zugriff { ordner.stopAccessingSecurityScopedResource() } }
        await ausgabe("Ordner: \(ordner.lastPathComponent) (Zugriff: \(zugriff))")

        var bytes = [UInt8](repeating: 0, count: 5_000_000)
        let anzahl = bytes.count
        guard SecRandomCopyBytes(kSecRandomDefault, anzahl, &bytes) == errSecSuccess else {
            await ausgabe("Zufallsdaten fehlgeschlagen.")
            return
        }
        let daten = Data(bytes)
        let summe = SHA256.hash(data: daten).map { String(format: "%02x", $0) }.joined()
        var ziel = ordner.appendingPathComponent("aufraeumer-probe-\(Int(Date().timeIntervalSince1970)).bin")

        var koordinatorFehler: NSError?
        var schreibFehler: Error?
        NSFileCoordinator().coordinate(writingItemAt: ziel, options: .forReplacing,
                                       error: &koordinatorFehler) { url in
            do { try daten.write(to: url, options: .atomic) } catch { schreibFehler = error }
        }
        if let fehler = koordinatorFehler ?? (schreibFehler as NSError?) {
            await ausgabe("Schreiben fehlgeschlagen: \(fehler.localizedDescription)")
            return
        }
        await ausgabe("Geschrieben: \(daten.count) Bytes, SHA-256 \(summe.prefix(12))…")

        let start = Date()
        var hochgeladen = false
        var letzte = ""
        while Date().timeIntervalSince(start) < 180 {
            // Zwischengespeicherte Werte verwerfen, sonst kann ein veralteter Upload-Status zurückkommen.
            ziel.removeAllCachedResourceValues()
            let w = try? ziel.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemIsUploadedKey,
                                                       .ubiquitousItemIsUploadingKey, .ubiquitousItemUploadingErrorKey])
            let zeile = "ubiquitär=\(String(describing: w?.isUbiquitousItem)) "
                + "hochgeladen=\(String(describing: w?.ubiquitousItemIsUploaded)) "
                + "lädt=\(String(describing: w?.ubiquitousItemIsUploading)) "
                + "fehler=\(String(describing: w?.ubiquitousItemUploadingError?.localizedDescription))"
            if zeile != letzte {
                await ausgabe("+\(Int(Date().timeIntervalSince(start))) s: \(zeile)")
                letzte = zeile
            }
            if w?.ubiquitousItemIsUploaded == true { hochgeladen = true; break }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        if let gelesen = try? Data(contentsOf: ziel) {
            let summe2 = SHA256.hash(data: gelesen).map { String(format: "%02x", $0) }.joined()
            await ausgabe("Erneut gelesen: \(gelesen.count) Bytes, Prüfsumme gleich: \(summe2 == summe)")
        } else {
            await ausgabe("Kopie konnte nicht erneut gelesen werden.")
        }
        await ausgabe(hochgeladen
            ? "ERGEBNIS: Upload-Nachweis funktioniert."
            : "ERGEBNIS: Kein Upload-Nachweis innerhalb von 180 s.")
        await ausgabe("Bitte die Datei \(ziel.lastPathComponent) (5 MB) danach in der Dateien-App löschen.")
    }
}
