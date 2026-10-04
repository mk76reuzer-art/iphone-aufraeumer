import SwiftUI

enum AufraeumSchritt: Int, CaseIterable {
    case pruefen = 1, auswaehlen, sichern, loeschen

    var titel: String {
        switch self {
        case .pruefen: return "Prüfen"
        case .auswaehlen: return "Auswählen"
        case .sichern: return "Sichern"
        case .loeschen: return "Löschen"
        }
    }
}

struct SchrittLeiste: View {
    let aktuell: AufraeumSchritt
    var nutzenSatz: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(AufraeumSchritt.allCases, id: \.rawValue) { schritt in
                    schrittKapsel(schritt)
                }
            }
            Text(nutzenSatz)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func schrittKapsel(_ schritt: AufraeumSchritt) -> some View {
        let aktiv = schritt.rawValue <= aktuell.rawValue
        let fett = schritt == aktuell
        return Text(schritt.titel)
            .font(fett ? .subheadline.bold() : .subheadline)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(aktiv ? Color.accentColor.opacity(fett ? 0.25 : 0.12) : Color.gray.opacity(0.1))
            .cornerRadius(8)
            .accessibilityIdentifier("schritt-\(schritt.titel)")
    }
}
