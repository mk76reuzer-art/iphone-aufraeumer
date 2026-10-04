import Foundation
import Photos

/// Nur lesend: zählt, was PhotoKit sieht, auch ausgeblendete Objekte, und die größten Videos.
enum MediathekProbe {
    static func lauf(_ ausgabe: @escaping @MainActor (String) -> Void) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await ausgabe("Foto-Zugriff: \(status.rawValue) (3 = voll, 4 = eingeschränkt)")
        guard status == .authorized else {
            await ausgabe("Kein Vollzugriff, Abbruch.")
            return
        }

        let optionen = PHFetchOptions()
        optionen.includeHiddenAssets = true
        let alle = PHAsset.fetchAssets(with: optionen)

        var ausgeblendet = 0, videos = 0, lokaleVideos = 0, screenshots = 0
        var lokalGesamt: Int64 = 0
        var groesste: [(mb: Double, ausgeblendet: Bool, lokal: Bool, name: String)] = []

        alle.enumerateObjects { asset, _, _ in
            if asset.isHidden { ausgeblendet += 1 }
            if asset.mediaSubtypes.contains(.photoScreenshot) { screenshots += 1 }
            guard asset.mediaType == .video else { return }
            videos += 1
            let ressourcen = PHAssetResource.assetResources(for: asset)
            let haupt = ressourcen.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) ?? ressourcen.first
            guard let haupt = haupt else { return }
            let meta = PhotoKitHilfen.groesseUndLokal(asset: asset)
            let groesse = meta.groesse
            let lokal = meta.lokal ?? true
            if lokal && groesse > 0 { lokaleVideos += 1; lokalGesamt += groesse }
            groesste.append((Double(groesse) / 1_000_000, asset.isHidden, lokal, haupt.originalFilename))
        }

        await ausgabe("Einträge gesamt: \(alle.count), davon ausgeblendet: \(ausgeblendet)")
        await ausgabe("Screenshots: \(screenshots)")
        await ausgabe("Videos: \(videos), davon lokal vorhanden: \(lokaleVideos)")
        await ausgabe("Lokale Videos zusammen: \(Int(Double(lokalGesamt) / 1_000_000)) MB")
        for v in groesste.sorted(by: { $0.mb > $1.mb }).prefix(5) {
            await ausgabe("  \(Int(v.mb)) MB | ausgeblendet=\(v.ausgeblendet) | lokal=\(v.lokal)")
        }

        let werte = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        if let frei = werte?.volumeAvailableCapacityForImportantUsage, let gesamt = werte?.volumeTotalCapacity {
            await ausgabe("Speicher: \(frei / 1_000_000_000) GB frei von \(gesamt / 1_000_000_000) GB")
        }
    }
}
