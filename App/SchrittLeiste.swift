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
            HStack(spacing: 6) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func schrittKapsel(_ schritt: AufraeumSchritt) -> some View {
        let aktiv = schritt.rawValue <= aktuell.rawValue
        let fett = schritt == aktuell
        return Text(schritt.titel)
            .font(.caption.weight(fett ? .bold : .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(aktiv ? Color.accentColor.opacity(fett ? 0.28 : 0.14) : Color.gray.opacity(0.12))
            .cornerRadius(8)
            .accessibilityIdentifier("schritt-\(schritt.titel)")
    }
}
