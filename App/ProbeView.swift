import SwiftUI
import UniformTypeIdentifiers

struct ProbeView: View {
    @State private var bericht: [String] = ["Bereit."]
    @State private var ordnerWaehlen = false
    @State private var laeuft = false

    var body: some View {
        NavigationStack {
            List {
                Section("Schritt 1: Mediathek (nur lesen)") {
                    Button("Mediathek zählen") { starteMediathek() }
                        .disabled(laeuft)
                }
                Section("Schritt 2: iCloud-Drive-Upload") {
                    Button("Ordner wählen und Testdatei senden") { ordnerWaehlen = true }
                        .disabled(laeuft)
                }
                Section("Ergebnis") {
                    ForEach(Array(bericht.enumerated()), id: \.offset) { _, zeile in
                        Text(zeile).font(.footnote.monospaced()).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Aufräumer – Probe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: bericht.joined(separator: "\n"))
                }
            }
            .fileImporter(isPresented: $ordnerWaehlen, allowedContentTypes: [.folder]) { ergebnis in
                switch ergebnis {
                case .success(let url): starteICloud(url)
                case .failure(let fehler): zeige("Ordnerwahl fehlgeschlagen: \(fehler.localizedDescription)")
                }
            }
        }
    }

    @MainActor private func zeige(_ text: String) { bericht.append(text) }

    @MainActor private func starteMediathek() {
        laeuft = true
        Task {
            await MediathekProbe.lauf { zeige($0) }
            laeuft = false
        }
    }

    @MainActor private func starteICloud(_ url: URL) {
        laeuft = true
        Task {
            await ICloudProbe.lauf(ordner: url) { zeige($0) }
            laeuft = false
        }
    }
}
