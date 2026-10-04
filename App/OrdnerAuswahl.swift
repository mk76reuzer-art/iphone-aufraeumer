import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Ordnerwahl über die Dateien-App (zuverlässiger als fileImporter auf dem Gerät).
struct OrdnerAuswahl: UIViewControllerRepresentable {
    @Binding var istAktiv: Bool
    var onGewaehlt: (URL) -> Void
    var onAbbruch: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: OrdnerAuswahl
        init(_ parent: OrdnerAuswahl) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.istAktiv = false
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            parent.onGewaehlt(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.istAktiv = false
            parent.onAbbruch()
        }
    }
}
