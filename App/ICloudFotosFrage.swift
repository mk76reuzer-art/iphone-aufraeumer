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
    @Environment(\.dismiss) private var dismiss
    @Binding var erledigt: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Sind iCloud-Fotos an?")
                .font(.title2.bold())
            Text("Wenn ja, werden gelöschte Fotos auch aus der Cloud entfernt. Auf dem iPhone wird Speicher erst frei, wenn du unter „Zuletzt gelöscht“ alles endgültig löschst.")
                .multilineTextAlignment(.center)
            HauptButton(titel: "Ja, iCloud-Fotos sind an") {
                ICloudFotosSpeicher.speichern(aktiv: true)
                erledigt = true
                dismiss()
            }
            HauptButton(titel: "Nein, nur auf dem iPhone") {
                ICloudFotosSpeicher.speichern(aktiv: false)
                erledigt = true
                dismiss()
            }
        }
        .padding()
    }
}
