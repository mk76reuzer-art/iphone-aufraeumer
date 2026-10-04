import Foundation
import Photos
import AufraeumerKern

struct ScanErgebnis: Sendable {
    var kandidaten: [Kandidat]
    var kategorien: [Kategorie: Set<String>]
    var duplikatGruppen: [DuplikatGruppe]
    var serienGruppen: [DuplikatGruppe]
    var bytesJeKategorie: [Kategorie: Int64]
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

        alle.enumerateObjects { asset, _, _ in
            index += 1
            if index % 40 == 0 {
                fortschritt(0.05 + 0.55 * Double(index) / Double(gesamt), "Fotos werden gelesen …")
            }
            bibliothek.registriere(asset)
            let meta = PhotoKitHilfen.groesseUndLokal(asset: asset)
            guard let aufnahme = asset.creationDate else { return }
            let k = Kandidat(
                id: asset.localIdentifier,
                name: meta.name,
                groesseBytes: meta.lokal ? meta.groesse : 0,
                aufnahme: aufnahme,
                dauerSekunden: asset.mediaType == .video ? asset.duration : nil,
                istVideo: asset.mediaType == .video,
                istScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                istFavorit: asset.isFavorite,
                istBearbeitet: asset.hasAdjustments,
                inAlbum: PhotoKitHilfen.inBenutzerAlbum(asset: asset),
                istAusgeblendet: asset.isHidden,
                istLokalVorhanden: meta.lokal && meta.groesse > 0
            )
            liste.append(k)
            if let sk = PhotoKitHilfen.serienKennung(asset: asset) {
                serienEintraege.append((k, sk))
            }
        }

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
        let duplikate = try await duplikatGruppen(aus: liste, bibliothek: bibliothek)
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
        return ScanErgebnis(kandidaten: liste, kategorien: katMap, duplikatGruppen: duplikate,
                            serienGruppen: serien, bytesJeKategorie: bytes)
    }

    private static func duplikatGruppen(
        aus liste: [Kandidat],
        bibliothek: PhotoKitBibliothek
    ) async throws -> [DuplikatGruppe] {
        let tauglich = liste.filter { $0.istLokalVorhanden && $0.groesseBytes > 0 }
        let nachGroesse = Dictionary(grouping: tauglich, by: \.groesseBytes)
        var ergebnis: [DuplikatGruppe] = []

        for (_, gleichGross) in nachGroesse where gleichGross.count >= 2 {
            var nachSumme: [String: [Kandidat]] = [:]
            for k in gleichGross {
                let export = try await bibliothek.exportieren(id: k.id)
                defer { try? FileManager.default.removeItem(at: export.datei) }
                nachSumme[export.pruefsumme, default: []].append(k)
            }
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
        return ergebnis.sorted { $0.behalten < $1.behalten }
    }
}

enum ScanFehler: LocalizedError {
    case keinZugriff

    var errorDescription: String? {
        switch self {
        case .keinZugriff:
            return "Bitte in den Einstellungen „Alle Fotos“ erlauben, damit der Aufräumer helfen kann."
        }
    }

    static func hilfeText(fuer error: Error) -> String {
        if let s = error as? ScanFehler, s == .keinZugriff {
            return "Kein Zugriff auf Fotos. Öffne die Einstellungen, tippe auf Datenschutz und Fotos, und erlaube dem Aufräumer vollen Zugriff."
        }
        return error.localizedDescription
    }
}
