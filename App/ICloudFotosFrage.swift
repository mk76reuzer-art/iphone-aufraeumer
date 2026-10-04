import SwiftUI

enum ICloudFotosSpeicher {
    private static let key = "aufraeumer.icloud.fotos.aktiv"

    static var wurdeGefragt: Bool {
        UserDefaults.standard.object(forKey: key) != nil
    }

    static var nutzerSagtAktiv: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func speichern(aktiv: Bool) {
        UserDefaults.standard.set(aktiv, forKey: key)
    }
}

struct ICloudFotosFrageSheet: View {
    var antwort: (Bool) -> Void
    @State private var zeigeOptimieren = false

    var body: some View {
        Group {
            if zeigeOptimieren {
                optimieren
            } else {
                frage
            }
        }
        .bildschirm("bildschirm-icloud")
    }

    private var frage: some View {
        VStack(spacing: 20) {
            Text("Sind iCloud-Fotos an?")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("Wenn ja, werden gelöschte Fotos auch aus der Cloud und von deinen anderen Geräten entfernt. Auf dem iPhone wird der Speicher erst frei, wenn du unter Zuletzt gelöscht alles endgültig löschst.")
                .font(.body)
                .multilineTextAlignment(.center)
            HauptButton(titel: "Ja, iCloud-Fotos sind an") { zeigeOptimieren = true }
            Button("Nein, nur auf dem iPhone") { antwort(false) }
                .font(.title3)
                .padding(.bottom, 12)
        }
        .padding()
    }

    private var optimieren: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Zuerst den iPhone-Speicher optimieren")
                    .font(.title.bold())
                Text("Dann liegen auf dem iPhone kleinere Kopien. Die großen Originale bleiben in der Cloud.")
                    .font(.body)
                Text("1. Öffne die Einstellungen.")
                Text("2. Tippe oben auf deinen Namen.")
                Text("3. Tippe auf iCloud, dann auf Fotos.")
                Text("4. Wähle iPhone-Speicher optimieren.")
                Text("Wenn du in dieser App etwas löschst, wird es auch in der Cloud und auf deinen anderen Geräten gelöscht.")
                    .font(.body)
                    .padding(.top, 4)
                HauptButton(titel: "Verstanden") { antwort(true) }
            }
            .padding()
        }
    }
}
