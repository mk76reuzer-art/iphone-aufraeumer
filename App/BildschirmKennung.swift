import SwiftUI

extension View {
    /// Macht den Bildschirm für den Simulator-Test auffindbar, ohne die Inhalte zu verstecken.
    func bildschirm(_ name: String) -> some View {
        accessibilityElement(children: .contain)
            .accessibilityIdentifier(name)
    }
}
