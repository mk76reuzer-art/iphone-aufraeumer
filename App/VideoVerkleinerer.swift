import AVFoundation
import Photos
import AufraeumerKern

enum VideoVerkleinererFehler: LocalizedError {
    case nichtGefunden
    case nichtAufDemGeraet
    case nichtMoeglich
    case zuKlein
    case abgebrochen
    case speichernFehlgeschlagen
    case zuWenigPlatz(frei: String, noetig: String)

    var errorDescription: String? {
        switch self {
        case .nichtGefunden:
            return "Das Video ist nicht mehr in der Mediathek. Tippe auf Neu prüfen."
        case .nichtAufDemGeraet:
            return "Das Video liegt nur in der Cloud und macht auf dem iPhone kaum Platz frei. Lass es aus, oder lade es in der Fotos-App herunter."
        case .nichtMoeglich:
            return "Dieses Video kann auf dem iPhone nicht verkleinert werden. Du kannst es stattdessen sichern und löschen."
        case .zuKlein:
            return "Die kleinere Fassung ist leer. Das Original bleibt erhalten. Versuche ein anderes Video."
        case .abgebrochen:
            return "Abgebrochen. Es wurde nichts verändert."
        case .speichernFehlgeschlagen:
            return "Die kleinere Fassung konnte nicht gespeichert werden. Das Original bleibt erhalten."
        case .zuWenigPlatz(let frei, let noetig):
            return "Zum Verkleinern braucht das iPhone kurz etwa \(noetig) frei. Im Moment sind \(frei) frei. Leere zuerst Zuletzt gelöscht in der Fotos-App."
        }
    }
}

/// Große Videos in kleinere Qualität umwandeln. Datum und Ort bleiben an der neuen Fassung.
@MainActor
final class VideoVerkleinerer {
    private let bibliothek: PhotoKitBibliothek

    init(bibliothek: PhotoKitBibliothek) { self.bibliothek = bibliothek }

    static func platzHinweis(kandidaten: [Kandidat], frei: Int64?) -> String? {
        guard let frei, let groesstes = kandidaten.max(by: { $0.groesseBytes < $1.groesseBytes }) else { return nil }
        let schaetzung = VideoSparSchaetzung.geschaetzteGroesseNachher(
            bytes: groesstes.groesseBytes, dauerSekunden: groesstes.dauerSekunden)
        let noetig = schaetzung + 300_000_000
        guard frei < noetig else { return nil }
        return VideoVerkleinererFehler.zuWenigPlatz(
            frei: Formatierung.gigabytes(frei),
            noetig: Formatierung.gigabytes(noetig)
        ).errorDescription
    }

    func verkleinern(
        kandidaten: [Kandidat],
        fortschritt: @escaping (Double, String) -> Void
    ) async -> (erfolg: [String], fehler: [String: String]) {
        var ok: [String] = []
        var fehler: [String: String] = [:]
        let gesamt = Double(max(1, kandidaten.count))
        for (index, k) in kandidaten.enumerated() {
            if Task.isCancelled {
                fehler[k.id] = VideoVerkleinererFehler.abgebrochen.localizedDescription
                break
            }
            fortschritt(Double(index) / gesamt, k.name)
            do {
                try await einzeln(k)
                ok.append(k.id)
            } catch {
                fehler[k.id] = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            fortschritt(Double(index + 1) / gesamt, k.name)
        }
        return (ok, fehler)
    }

    private func einzeln(_ k: Kandidat) async throws {
        guard let asset = bibliothek.asset(id: k.id) else {
            throw VideoVerkleinererFehler.nichtGefunden
        }
        let geladen = try await filmLaden(asset)
        let eingang: URL
        let aufraeumen: Bool
        switch geladen {
        case .datei(let url):
            eingang = url
            aufraeumen = false
        case .kopieNoetig:
            let export = try await bibliothek.exportieren(id: k.id)
            eingang = export.datei
            aufraeumen = true
        }
        defer { if aufraeumen { try? FileManager.default.removeItem(at: eingang) } }

        let quelle = AVURLAsset(url: eingang)
        let passend = AVAssetExportSession.exportPresets(compatibleWith: quelle)
        let preset = [AVAssetExportPresetHEVC1920x1080, AVAssetExportPreset1920x1080].first(where: passend.contains)
        guard let preset, let session = AVAssetExportSession(asset: quelle, presetName: preset) else {
            throw VideoVerkleinererFehler.nichtMoeglich
        }
        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent("verkleinert-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: ziel) }
        session.outputURL = ziel
        session.outputFileType = .mov
        await session.export()
        guard session.status == .completed else { throw VideoVerkleinererFehler.nichtMoeglich }
        let groesse = (try? DateiPruefung.messen(url: ziel).bytes) ?? 0
        guard groesse > 100_000 else { throw VideoVerkleinererFehler.zuKlein }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let anfrage = PHAssetCreationRequest.forAsset()
                let optionen = PHAssetResourceCreationOptions()
                optionen.shouldMoveFile = true
                anfrage.addResource(with: .video, fileURL: ziel, options: optionen)
                if let datum = asset.creationDate { anfrage.creationDate = datum }
                if let ort = asset.location { anfrage.location = ort }
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
        } catch {
            if Self.istAbbruch(error) { throw VideoVerkleinererFehler.abgebrochen }
            throw VideoVerkleinererFehler.speichernFehlgeschlagen
        }
    }

    private enum FilmQuelle {
        case datei(URL)
        case kopieNoetig
    }

    private func filmLaden(_ asset: PHAsset) async throws -> FilmQuelle {
        let anfrage = FilmAnfrage()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (fort: CheckedContinuation<FilmQuelle, Error>) in
                let optionen = PHVideoRequestOptions()
                optionen.isNetworkAccessAllowed = false
                optionen.deliveryMode = .highQualityFormat
                anfrage.requestId = PHImageManager.default().requestAVAsset(forVideo: asset, options: optionen) { av, _, info in
                    anfrage.einmal {
                        if (info?[PHImageCancelledKey] as? Bool) == true {
                            fort.resume(throwing: VideoVerkleinererFehler.abgebrochen)
                            return
                        }
                        if let urlAsset = av as? AVURLAsset {
                            fort.resume(returning: .datei(urlAsset.url))
                            return
                        }
                        if av != nil {
                            fort.resume(returning: .kopieNoetig)
                            return
                        }
                        if (info?[PHImageResultIsInCloudKey] as? Bool) == true {
                            fort.resume(throwing: VideoVerkleinererFehler.nichtAufDemGeraet)
                            return
                        }
                        fort.resume(throwing: VideoVerkleinererFehler.nichtGefunden)
                    }
                }
            }
        } onCancel: {
            if anfrage.requestId != PHInvalidImageRequestID {
                PHImageManager.default().cancelImageRequest(anfrage.requestId)
            }
        }
    }

    private static func istAbbruch(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.code == NSUserCancelledError { return true }
        let text = ns.localizedDescription.lowercased()
        return text.contains("cancel") || text.contains("abgebrochen")
    }
}

private final class FilmAnfrage: @unchecked Sendable {
    var requestId: PHImageRequestID = PHInvalidImageRequestID
    private let lock = NSLock()
    private var erledigt = false

    func einmal(_ body: () -> Void) {
        lock.lock()
        if erledigt {
            lock.unlock()
            return
        }
        erledigt = true
        lock.unlock()
        body()
    }
}
