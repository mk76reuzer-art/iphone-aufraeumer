import AVFoundation
import Photos
import AufraeumerKern

enum VideoVerkleinererFehler: LocalizedError {
    case exportFehlgeschlagen
    case speichernFehlgeschlagen

    var errorDescription: String? {
        switch self {
        case .exportFehlgeschlagen: return "Video konnte nicht verkleinert werden."
        case .speichernFehlgeschlagen: return "Neues Video konnte nicht in Fotos gespeichert werden."
        }
    }
}

/// Große Videos in HEVC 1080p umwandeln, Original danach löschen.
@MainActor
final class VideoVerkleinerer {
    private let bibliothek: PhotoKitBibliothek

    init(bibliothek: PhotoKitBibliothek) { self.bibliothek = bibliothek }

    func verkleinern(
        kandidaten: [Kandidat],
        fortschritt: @escaping (Double, String) -> Void
    ) async -> (erfolg: [String], fehler: [String: String]) {
        var ok: [String] = []
        var fehler: [String: String] = [:]
        let gesamt = Double(max(1, kandidaten.count))
        for (index, k) in kandidaten.enumerated() {
            fortschritt(Double(index) / gesamt, k.name)
            do {
                try await einzeln(k)
                ok.append(k.id)
            } catch {
                fehler[k.id] = error.localizedDescription
            }
            fortschritt(Double(index + 1) / gesamt, k.name)
        }
        return (ok, fehler)
    }

    private func einzeln(_ k: Kandidat) async throws {
        guard let asset = bibliothek.asset(id: k.id) else {
            throw VideoVerkleinererFehler.exportFehlgeschlagen
        }
        let export = try await bibliothek.exportieren(id: k.id)
        defer { try? FileManager.default.removeItem(at: export.datei) }

        let quelle = AVURLAsset(url: export.datei)
        guard let session = AVAssetExportSession(asset: quelle, presetName: AVAssetExportPresetHEVC1920x1080) else {
            throw VideoVerkleinererFehler.exportFehlgeschlagen
        }
        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent("verkleinert-\(UUID().uuidString).mov")
        session.outputURL = ziel
        session.outputFileType = .mov
        await session.export()
        guard session.status == .completed else { throw VideoVerkleinererFehler.exportFehlgeschlagen }

        var neueId: String?
        try await PHPhotoLibrary.shared().performChanges {
            let req = PHAssetCreationRequest.forAsset()
            req.addResource(with: .video, fileURL: ziel, options: nil)
            req.creationDate = asset.creationDate
            req.location = asset.location
            neueId = req.placeholderForCreatedAsset?.localIdentifier
        }
        try? FileManager.default.removeItem(at: ziel)
        guard neueId != nil else { throw VideoVerkleinererFehler.speichernFehlgeschlagen }

        try await bibliothek.loeschen(ids: [k.id])
    }
}
