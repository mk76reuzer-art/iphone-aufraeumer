import SwiftUI

struct HauptButton: View {
    let titel: String
    var aktiv = true
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            Text(titel)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!aktiv)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
