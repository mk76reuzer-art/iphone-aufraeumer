import SwiftUI

struct ZuletztGeloeschtAnleitung: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("So wird der Speicher wirklich frei")
                .font(.title3.bold())
            Text("Gelöschtes bleibt 30 Tage liegen. Erst danach ist der Platz frei.")
                .font(.body)
            schritt(nr: 1, symbol: "photo.on.rectangle.angled", text: "Öffne die Fotos-App.")
            schritt(nr: 2, symbol: "rectangle.stack", text: "Tippe unten auf Alben.")
            schritt(nr: 3, symbol: "trash", text: "Öffne Zuletzt gelöscht.")
            schritt(nr: 4, symbol: "trash.slash", text: "Tippe Alle löschen und bestätige.")
        }
        .padding()
        .background(Color.orange.opacity(0.14))
        .cornerRadius(12)
    }

    private func schritt(nr: Int, symbol: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.title)
                .frame(width: 52, height: 52)
                .background(Color.orange.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text("\(nr). \(text)")
                .font(.body)
        }
    }
}
