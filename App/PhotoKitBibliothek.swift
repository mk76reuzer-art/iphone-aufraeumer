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

struct LokalBefund {
    var groesse: Int64
    /// nil heißt: nicht feststellbar. Dann gilt die Datei als auf dem iPhone.
    var lokal: Bool?
    var name: String
}

enum PhotoKitHilfen {
    static func groesseUndLokal(asset: PHAsset) -> LokalBefund {
        let ressourcen = PHAssetResource.assetResources(for: asset)
        let haupt = ressourcen.first(where: { $0.type == .fullSizeVideo || $0.type == .video })
            ?? ressourcen.first(where: { $0.type == .photo || $0.type == .fullSizePhoto })
            ?? ressourcen.first
        guard let res = haupt else {
            return LokalBefund(groesse: 0, lokal: nil, name: asset.localIdentifier)
        }
        let groesse = int64WennVorhanden(res, "fileSize") ?? 0
        // Der private Getter heißt je nach System isLocallyAvailable oder locallyAvailable.
        // value(forKey:) nur nach responds(to:), sonst NSUnknownKeyException.
        let lokal = boolWennVorhanden(res, "isLocallyAvailable")
            ?? boolWennVorhanden(res, "locallyAvailable")
        return LokalBefund(groesse: groesse, lokal: lokal, name: res.originalFilename)
    }

    private static func boolWennVorhanden(_ obj: NSObject, _ key: String) -> Bool? {
        let sel = NSSelectorFromString(key)
        guard obj.responds(to: sel), let n = obj.value(forKey: key) as? NSNumber else { return nil }
        return n.boolValue
    }

    private static func int64WennVorhanden(_ obj: NSObject, _ key: String) -> Int64? {
        let sel = NSSelectorFromString(key)
        guard obj.responds(to: sel), let n = obj.value(forKey: key) as? NSNumber else { return nil }
        return n.int64Value
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
