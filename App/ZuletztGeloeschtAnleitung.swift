import SwiftUI

struct ZuletztGeloeschtAnleitung: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("So wird der Speicher wirklich frei")
                .font(.headline)
            schritt(nr: 1, symbol: "photo.on.rectangle", text: "Öffne die Fotos-App.")
            schritt(nr: 2, symbol: "ellipsis.circle", text: "Tippe unten auf „Alben“.")
            schritt(nr: 3, symbol: "trash", text: "Öffne „Zuletzt gelöscht“.")
            schritt(nr: 4, symbol: "trash.fill", text: "Tippe „Alle löschen“ und bestätige.")
        }
        .padding()
        .background(Color.orange.opacity(0.12))
        .cornerRadius(12)
    }

    private func schritt(nr: Int, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 36)
            Text("\(nr). \(text)")
                .font(.body)
        }
    }
}
