import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Ordnerwahl der Dateien-App. Apple nennt das die Dokumentauswahl für einen Ordner.
/// Darüber erreicht man iCloud Drive, Auf meinem iPhone, OneDrive und einen Stick.
/// Ein reiner Export gibt nur eine einzelne Datei zurück, keinen Ordner zum Merken.
struct OrdnerAuswahl: UIViewControllerRepresentable {
    @Binding var istAktiv: Bool
    var startOrdner: URL?
    var onGewaehlt: (URL) -> Void
    var onAbbruch: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        if let startOrdner {
            picker.directoryURL = startOrdner
        }
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
            parent.onGewaehlt(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.istAktiv = false
            parent.onAbbruch()
        }
    }
}
