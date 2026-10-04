import SwiftUI
import UIKit

struct TippsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Mehr Speicher, den die App nicht selbst freimachen darf.")
                        .font(.body)
                    tipp(
                        titel: "iCloud-Fotos: kleinere Kopien auf dem iPhone",
                        schritte: [
                            "Öffne die Einstellungen.",
                            "Tippe oben auf deinen Namen.",
                            "Tippe auf iCloud, dann auf Fotos.",
                            "Wähle iPhone-Speicher optimieren."
                        ],
                        danach: "Die Originale bleiben in der Cloud. Auf dem iPhone liegen kleinere Kopien."
                    )
                    tipp(
                        titel: "Apps, die du selten nutzt",
                        schritte: [
                            "Öffne die Einstellungen.",
                            "Tippe auf Allgemein.",
                            "Tippe auf iPhone-Speicher.",
                            "Tippe auf eine App und dann auf App auslagern."
                        ],
                        danach: "Deine Daten bleiben. Die App selbst wird entfernt und kommt beim nächsten Öffnen wieder."
                    )
                    tipp(
                        titel: "Große Anhänge in Nachrichten",
                        schritte: [
                            "Öffne die Einstellungen.",
                            "Tippe auf Allgemein.",
                            "Tippe auf iPhone-Speicher.",
                            "Schau unter Empfehlungen nach Große Anhänge prüfen."
                        ],
                        danach: "Dort kannst du alte Filme und Fotos aus Nachrichten löschen."
                    )
                }
                .padding()
                .padding(.bottom, 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HauptButton(titel: "Zurück") { dismiss() }
                    .background(Color(.systemBackground))
            }
        }
        .navigationTitle("Tipps")
        .navigationBarTitleDisplayMode(.inline)
        .bildschirm("bildschirm-tipps")
    }

    private func tipp(titel: String, schritte: [String], danach: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel).font(.title3.bold())
            ForEach(Array(schritte.enumerated()), id: \.offset) { index, satz in
                Text("\(index + 1). \(satz)").font(.body)
            }
            Text(danach)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }
}

enum EinstellungenOeffner {
    /// Öffnet die Einstellungsseite dieser App. Dort liegt die Foto-Erlaubnis.
    static func appEinstellungen() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
