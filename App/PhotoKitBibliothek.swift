import Foundation
import Photos
import AufraeumerKern

/// PhotoKit-Umsetzung von `MedienBibliothek`.
final class PhotoKitBibliothek: MedienBibliothek, @unchecked Sendable {
    private var assets: [String: PHAsset] = [:]
    private let lock = NSLock()

    func registriere(_ asset: PHAsset) {
        lock.lock()
        assets[asset.localIdentifier] = asset
        lock.unlock()
    }

    func asset(id: String) -> PHAsset? {
        lock.lock()
        defer { lock.unlock() }
        return assets[id]
    }

    func exportieren(id: String) async throws -> Export {
        guard let asset = asset(id: id) else {
            throw NSError(domain: "PhotoKit", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Foto nicht mehr vorhanden"])
        }
        let ressourcen = PHAssetResource.assetResources(for: asset)
        let haupt = ressourcen.first(where: { $0.type == .fullSizeVideo || $0.type == .video })
            ?? ressourcen.first(where: { $0.type == .photo || $0.type == .fullSizePhoto })
            ?? ressourcen.first
        guard let res = haupt else {
            throw NSError(domain: "PhotoKit", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Datei konnte nicht gelesen werden"])
        }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("aufraeumer-\(UUID().uuidString)")
        try? FileManager.default.removeItem(at: temp)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: res, toFile: temp, options: nil) { fehler in
                if let fehler {
                    let ns = fehler as NSError
                    if ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError {
                        cont.resume(throwing: DateiKopieFehler.zuWenigPlatz)
                    } else {
                        cont.resume(throwing: fehler)
                    }
                } else {
                    cont.resume()
                }
            }
        }

        let gemessen = try DateiPruefung.messen(url: temp)
        return Export(datei: temp, bytes: gemessen.bytes, pruefsumme: gemessen.pruefsumme)
    }

    func loeschen(ids: [String]) async throws {
        let objekte = ids.compactMap { asset(id: $0) }
        guard !objekte.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(objekte as NSArray)
        }
    }
}

enum PhotoKitHilfen {
    static func groesseUndLokal(asset: PHAsset) -> (groesse: Int64, lokal: Bool, name: String) {
        let ressourcen = PHAssetResource.assetResources(for: asset)
        let haupt = ressourcen.first(where: { $0.type == .fullSizeVideo || $0.type == .video })
            ?? ressourcen.first(where: { $0.type == .photo || $0.type == .fullSizePhoto })
            ?? ressourcen.first
        guard let res = haupt else { return (0, false, asset.localIdentifier) }
        var groesse: Int64 = 0
        var lokal = false
        if res.responds(to: NSSelectorFromString("fileSize")),
           let n = res.value(forKey: "fileSize") as? NSNumber { groesse = n.int64Value }
        if res.responds(to: NSSelectorFromString("locallyAvailable")),
           let n = res.value(forKey: "locallyAvailable") as? NSNumber { lokal = n.boolValue }
        return (groesse, lokal, res.originalFilename)
    }

    static func inBenutzerAlbum(asset: PHAsset) -> Bool {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "estimatedAssetCount > 0")
        let sammlungen = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: opts)
        var zaehler = 0
        sammlungen.enumerateObjects { col, _, _ in
            if col.assetCollectionSubtype != .smartAlbumAllHidden { zaehler += 1 }
        }
        return zaehler > 0
    }

    static func serienKennung(asset: PHAsset) -> String? {
        if let burst = asset.burstIdentifier, !burst.isEmpty { return "burst:\(burst)" }
        guard asset.mediaType == .image, !asset.mediaSubtypes.contains(.photoScreenshot) else { return nil }
        let sek = Int(asset.creationDate?.timeIntervalSince1970 ?? 0)
        return "zeit:\(sek / 2)"
    }
}
