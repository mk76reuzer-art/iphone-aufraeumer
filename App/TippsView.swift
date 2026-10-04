import SwiftUI
import UIKit

struct TippsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Mehr Speicher ohne diese App")
                    .font(.title2.bold())
                tippBlock(
                    titel: "iCloud-Fotos: Speicher optimieren",
                    text: "Öffne Einstellungen, tippe auf deinen Namen, dann iCloud, dann Fotos. Wähle „iPhone-Speicher optimieren“. Dann liegen Originale in der Cloud und auf dem iPhone bleiben kleinere Kopien.",
                    knopf: "Einstellungen öffnen",
                    url: "App-prefs:root=CASTLE"
                )
                tippBlock(
                    titel: "Ungenutzte Apps auslagern",
                    text: "Öffne Einstellungen, dann Allgemein, dann iPhone-Speicher. Tippe auf eine App, die du selten nutzt, und wähle „App auslagern“. Deine Daten bleiben, die App wird entfernt.",
                    knopf: "Speicher-Einstellungen",
                    url: "App-prefs:root=General&path=STORAGE_MGMT"
                )
                tippBlock(
                    titel: "Große Anhänge in Nachrichten",
                    text: "Öffne Einstellungen, dann Allgemein, dann iPhone-Speicher. Unter „Empfehlungen“ findest du oft „Große Anhänge prüfen“ für Nachrichten.",
                    knopf: "Speicher-Einstellungen",
                    url: "App-prefs:root=General&path=STORAGE_MGMT"
                )
            }
            .padding()
        }
        .navigationTitle("Tipps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Zurück") { dismiss() }
            }
        }
    }

    private func tippBlock(titel: String, text: String, knopf: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel).font(.headline)
            Text(text).font(.body)
            Button(knopf) { EinstellungenOeffner.oeffnen(pfad: url) }
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }
}

enum EinstellungenOeffner {
    static func oeffnen(pfad: String) {
        if let url = URL(string: pfad) {
            UIApplication.shared.open(url)
        }
    }
}
