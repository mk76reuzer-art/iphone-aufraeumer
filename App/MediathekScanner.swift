import Foundation
import Photos
import AufraeumerKern

struct ScanErgebnis: Sendable {
    var kandidaten: [Kandidat]
    var kategorien: [Kategorie: Set<String>]
    var duplikatGruppen: [DuplikatGruppe]
    var serienGruppen: [DuplikatGruppe]
    var bytesJeKategorie: [Kategorie: Int64]
    var hinweis: String? = nil
    var anzahlAssets: Int = 0
    var mediathekLokalBytes: Int64 = 0
    var videoLokalBytes: Int64 = 0
    var anzahlNurCloud: Int = 0
}

enum MediathekScanner {
    static func scan(
        bibliothek: PhotoKitBibliothek,
        schwellen: Schwellen = Schwellen(),
        jetzt: Date = Date(),
        fortschritt: @escaping @Sendable (Double, String) -> Void
    ) async throws -> ScanErgebnis {
        fortschritt(0.02, "Foto-Zugriff wird geprüft …")
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized else {
            throw ScanFehler.keinZugriff
        }

        let optionen = PHFetchOptions()
        optionen.includeHiddenAssets = true
        let alle = PHAsset.fetchAssets(with: optionen)
        let gesamt = alle.count
        guard gesamt > 0 else {
            return ScanErgebnis(kandidaten: [], kategorien: [:], duplikatGruppen: [],
                                  serienGruppen: [], bytesJeKategorie: [:])
        }

        var liste: [Kandidat] = []
        var serienEintraege: [(Kandidat, String)] = []
        var index = 0
        var abgebrochen = false
        var mediathekLokal: Int64 = 0
        var videoLokal: Int64 = 0
        var nurCloud = 0

        alle.enumerateObjects { asset, _, stop in
            if Task.isCancelled {
                abgebrochen = true
                stop.pointee = true
                return
            }
            index += 1
            if index % 40 == 0 {
                fortschritt(0.05 + 0.55 * Double(index) / Double(gesamt), "Fotos werden gelesen …")
            }
            bibliothek.registriere(asset)
            let meta = PhotoKitHilfen.groesseUndLokal(asset: asset)
            let giltAlsLokal = meta.lokal ?? true
            let nurInCloud = meta.lokal == false
            if nurInCloud { nurCloud += 1 }
            if giltAlsLokal && meta.groesse > 0 {
                mediathekLokal += meta.groesse
                if asset.mediaType == .video { videoLokal += meta.groesse }
            }
            let aufnahme = asset.creationDate ?? Date()
            let nameIstScreenshot = Regeln.istBildschirmfotoName(meta.name)
            let k = Kandidat(
                id: asset.localIdentifier,
                name: meta.name,
                groesseBytes: meta.groesse,
                aufnahme: aufnahme,
                dauerSekunden: asset.mediaType == .video ? asset.duration : nil,
                istVideo: asset.mediaType == .video,
                istScreenshot: asset.mediaSubtypes.contains(.photoScreenshot) || nameIstScreenshot,
                istFavorit: asset.isFavorite,
                istBearbeitet: asset.hasAdjustments,
                inAlbum: PhotoKitHilfen.inBenutzerAlbum(asset: asset),
                istAusgeblendet: asset.isHidden,
                istLokalVorhanden: giltAlsLokal && meta.groesse > 0 && !nurInCloud,
                istLiveFoto: asset.mediaSubtypes.contains(.photoLive),
                istRaw: asset.mediaSubtypes.contains(.photoRAW),
                istBildschirmaufnahme: asset.mediaType == .video && (
                    asset.mediaSubtypes.contains(.videoScreenRecording)
                    || Regeln.istBildschirmaufnahmeName(meta.name)
                ),
                nurInCloud: nurInCloud
            )
            liste.append(k)
            if let sk = PhotoKitHilfen.serienKennung(asset: asset) {
                serienEintraege.append((k, sk))
            }
        }
        if abgebrochen { throw CancellationError() }

        fortschritt(0.65, "Aufräum-Vorschläge werden berechnet …")
        var katMap: [Kategorie: Set<String>] = [:]
        var bytes: [Kategorie: Int64] = [:]
        for k in liste {
            let kat = Regeln.kategorien(fuer: k, jetzt: jetzt, schwellen: schwellen)
            for c in kat {
                katMap[c, default: []].insert(k.id)
                bytes[c, default: 0] += k.groesseBytes
            }
        }

        fortschritt(0.75, "Doppelte werden gesucht …")
        let duplikatStand = try await duplikatGruppen(aus: liste, bibliothek: bibliothek)
        let duplikate = duplikatStand.gruppen
        for g in duplikate {
            katMap[.duplikate, default: []].formUnion(g.loeschbar)
            for id in g.loeschbar {
                if let k = liste.first(where: { $0.id == id }) {
                    bytes[.duplikate, default: 0] += k.groesseBytes
                }
            }
        }

        fortschritt(0.88, "Serienbilder werden gesucht …")
        let serien = SerienFinder.gruppen(aus: serienEintraege.map { ($0.0, $0.1) })
        for g in serien {
            katMap[.serienbilder, default: []].formUnion(g.loeschbar)
            for id in g.loeschbar {
                if let k = liste.first(where: { $0.id == id }) {
                    bytes[.serienbilder, default: 0] += k.groesseBytes
                }
            }
        }

        fortschritt(1, "Fertig.")
        let hinweis = duplikatStand.uebersprungen > 0
            ? "Einige mögliche Doppelte konnten nicht verglichen werden, weil zu wenig Speicher frei ist. Angezeigt wird nur, was sicher geprüft wurde."
            : nil
        return ScanErgebnis(kandidaten: liste, kategorien: katMap, duplikatGruppen: duplikate,
                            serienGruppen: serien, bytesJeKategorie: bytes, hinweis: hinweis,
                            anzahlAssets: gesamt, mediathekLokalBytes: mediathekLokal,
                            videoLokalBytes: videoLokal, anzahlNurCloud: nurCloud)
    }

    private struct DuplikatStand {
        var gruppen: [DuplikatGruppe]
        var uebersprungen: Int
    }

    private static func duplikatGruppen(
        aus liste: [Kandidat],
        bibliothek: PhotoKitBibliothek
    ) async throws -> DuplikatStand {
        let tauglich = liste.filter { $0.istLokalVorhanden && $0.groesseBytes > 0 }
        let nachGroesse = Dictionary(grouping: tauglich, by: \.groesseBytes)
        var ergebnis: [DuplikatGruppe] = []
        var uebersprungen = 0

        for (_, gleichGross) in nachGroesse where gleichGross.count >= 2 {
            if Task.isCancelled { throw CancellationError() }
            var nachSumme: [String: [Kandidat]] = [:]
            var gruppeUnvollstaendig = false
            for k in gleichGross {
                if Task.isCancelled { throw CancellationError() }
                let frei = SpeicherAnzeige.lesen()?.freiBytes ?? 0
                if frei < k.groesseBytes + 150_000_000 {
                    gruppeUnvollstaendig = true
                    continue
                }
                do {
                    let export = try await bibliothek.exportieren(id: k.id)
                    defer { try? FileManager.default.removeItem(at: export.datei) }
                    nachSumme[export.pruefsumme, default: []].append(k)
                } catch {
                    gruppeUnvollstaendig = true
                }
            }
            if gruppeUnvollstaendig { uebersprungen += gleichGross.count }
            for (_, gleich) in nachSumme where gleich.count >= 2 {
                let sortiert = gleich.sorted { a, b in
                    if a.istFavorit != b.istFavorit { return a.istFavorit }
                    if a.aufnahme != b.aufnahme { return a.aufnahme < b.aufnahme }
                    return a.id < b.id
                }
                ergebnis.append(DuplikatGruppe(
                    behalten: sortiert[0].id,
                    loeschbar: sortiert.dropFirst().map(\.id).sorted()))
            }
        }
        return DuplikatStand(gruppen: ergebnis.sorted { $0.behalten < $1.behalten },
                             uebersprungen: uebersprungen)
    }
}

enum ScanFehler: LocalizedError, Equatable {
    case keinZugriff

    var errorDescription: String? {
        switch self {
        case .keinZugriff:
            return "Bitte in den Einstellungen „Alle Fotos“ erlauben, damit der Aufräumer helfen kann."
        }
    }

    static func hilfeText(fuer error: Error) -> String {
        if let s = error as? ScanFehler, s == .keinZugriff {
            return "Kein Zugriff auf Fotos. Tippe auf Einstellungen öffnen, dann auf Fotos, und wähle Alle Fotos. Komm danach zurück, die Prüfung startet von selbst."
        }
        if error is CancellationError {
            return "Abgebrochen. Es wurde nichts verändert."
        }
        return "Das Prüfen ist fehlgeschlagen. Tippe auf Erneut versuchen."
    }
}
