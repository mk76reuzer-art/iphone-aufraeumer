import SwiftUI
import Photos

struct FotoVorschau: View {
    let assetId: String
    @State private var bild: UIImage?

    var body: some View {
        Group {
            if let bild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .clipped()
        .task { await laden() }
    }

    private func laden() async {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetch.firstObject else { return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill, options: opts
        ) { img, _ in
            Task { @MainActor in bild = img }
        }
    }
}
