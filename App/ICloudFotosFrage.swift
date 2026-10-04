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

    var body: some View {
        VStack(spacing: 20) {
            Text("Sind iCloud-Fotos an?")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("Wenn ja, werden gelöschte Fotos auch aus der Cloud und von deinen anderen Geräten entfernt. Auf dem iPhone wird der Speicher erst frei, wenn du unter Zuletzt gelöscht alles endgültig löschst.")
                .font(.body)
                .multilineTextAlignment(.center)
            HauptButton(titel: "Ja, iCloud-Fotos sind an") { antwort(true) }
            Button("Nein, nur auf dem iPhone") { antwort(false) }
                .font(.title3)
                .padding(.bottom, 12)
        }
        .padding()
        .bildschirm("bildschirm-icloud")
    }
}
