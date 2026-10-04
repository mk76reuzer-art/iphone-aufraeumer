import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AufraeumerKern

struct StartView: View {
    @StateObject private var model = AufraeumerModel()

    var body: some View {
        NavigationStack {
            ZStack {
                inhalt
                if model.phase == .scannt || model.phase == .lauf {
                    FortschrittOverlay(
                        prozent: model.phase == .scannt ? model.scanFortschritt : model.laufFortschritt,
                        text: model.phase == .scannt ? model.scanText : model.laufText,
                        upload: model.uploadProzent
                    )
                }
            }
            .navigationTitle("Aufräumer")
            .fileImporter(isPresented: $model.ordnerWaehlen, allowedContentTypes: [.folder]) { ergebnis in
                if case .success(let url) = ergebnis { model.ordnerGewaehlt(url) }
            }
            .task { await model.beimStart() }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch model.phase {
        case .start, .scannt:
            Color.clear
        case .uebersicht:
            UebersichtView(model: model)
        case .auswahl:
            AuswahlView(model: model)
        case .sichern:
            ICloudHinweisView(model: model)
        case .bestaetigen:
            BestaetigenView(model: model)
        case .bericht:
            BerichtView(model: model)
        case .lauf:
            Color.clear
        }
    }
}

private struct FortschrittOverlay: View {
    let prozent: Double
    let text: String
    let upload: Double

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: prozent)
                .progressViewStyle(.linear)
                .tint(.accentColor)
            Text(Formatierung.prozent(prozent))
                .font(.largeTitle.bold())
            if upload > 0 {
                Text("Hochladen: \(Formatierung.prozent(upload))")
                    .font(.title3)
            }
            Text(text)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }
}

struct UebersichtView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    speicherKarte
                    if let fehler = model.fehlerText {
                        Text(fehler).foregroundStyle(.red).font(.body)
                    }
                    Text("Aufräum-Vorschläge")
                        .font(.title2.bold())
                    ForEach(Kategorie.allCases, id: \.self) { kat in
                        kategorieZeile(kat)
                    }
                    ordnerZeile
                }
                .padding()
            }
            HauptButton(titel: "Auswahl prüfen", aktiv: model.scan != nil) {
                model.weiterVonUebersicht()
            }
        }
    }

    private var speicherKarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let s = model.speicher {
                Text("\(Formatierung.gigabytes(s.freiBytes)) frei")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("von \(Formatierung.gigabytes(s.gesamtBytes)) auf dem iPhone")
                    .font(.title3)
                if let g = s.groessteKategorie, g.bytes > 0 {
                    Text("Am meisten zum Aufräumen: \(g.name) (\(Formatierung.gigabytes(g.bytes)))")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Speicher wird gelesen …")
                    .font(.title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.accentColor.opacity(0.12))
        .cornerRadius(12)
    }

    private func kategorieZeile(_ kat: Kategorie) -> some View {
        let bytes = model.scan?.bytesJeKategorie[kat] ?? 0
        let anzahl = model.scan?.kategorien[kat]?.count ?? 0
        return HStack {
            VStack(alignment: .leading) {
                Text(kat.anzeigeName).font(.headline)
                Text(anzahl == 0 ? "Nichts gefunden" : "\(anzahl) Dateien")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(bytes > 0 ? Formatierung.gigabytes(bytes) : "—")
                .font(.title3.bold())
        }
        .padding(.vertical, 4)
    }

    private var ordnerZeile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sicherung").font(.headline)
            Text(model.iCloudOrdnerName.map { "iCloud Drive: \($0)" } ?? "Noch kein Ordner gewählt")
                .font(.body)
            Button("iCloud-Ordner wählen") { model.ordnerWaehlen = true }
        }
        .padding(.top, 8)
    }
}

struct AuswahlView: View {
    @ObservedObject var model: AufraeumerModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("Markierte Dateien: \(model.ausgewaehlt.count)")
                .font(.title3)
            Text("Freiwerdend ca. \(Formatierung.gigabytes(model.bytesAusgewaehlt()))")
                .font(.body)
            List {
                ForEach(gruppiert, id: \.kat) { block in
                    Section(block.kat.anzeigeName) {
                        ForEach(block.ids, id: \.self) { id in
                            zeile(id: id)
                        }
                    }
                }
            }
            HauptButton(titel: "Weiter") { model.weiterVonAuswahl() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Zurück") { model.phase = .uebersicht }
            }
        }
    }

    private struct Block {
        let kat: Kategorie
        let ids: [String]
    }

    private var gruppiert: [Block] {
        guard let scan = model.scan else { return [] }
        return Kategorie.allCases.compactMap { kat in
            let ids = scan.kategorien[kat]?.sorted() ?? []
            guard !ids.isEmpty else { return nil }
            return Block(kat: kat, ids: ids)
        }
    }

    private func zeile(id: String) -> some View {
        HStack {
            FotoVorschau(assetId: id)
                .frame(width: 56, height: 56)
                .cornerRadius(8)
            VStack(alignment: .leading) {
                Text(model.kandidat(id)?.name ?? "Foto")
                    .lineLimit(1)
                if let k = model.kandidat(id) {
                    Text(Formatierung.gigabytes(k.groesseBytes))
                        .font(.caption)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { model.ausgewaehlt.contains(id) },
                set: { an in
                    if an { model.ausgewaehlt.insert(id) } else { model.ausgewaehlt.remove(id) }
                }))
            .labelsHidden()
        }
    }
}

struct ICloudHinweisView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Vor dem Löschen sichern")
                .font(.title.bold())
            Text("Große Videos und alte Aufnahmen werden zuerst in deinen iCloud-Drive-Ordner kopiert. Gelöscht wird nur, was dort angekommen ist.")
                .multilineTextAlignment(.center)
                .padding()
            HauptButton(titel: "Weiter zur Bestätigung") { model.phase = .bestaetigen }
            Button("Zurück") { model.phase = .auswahl }
        }
        .padding()
    }
}

struct BestaetigenView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Letzte Bestätigung")
                .font(.title.bold())
            Text("\(model.ausgewaehlt.count) Dateien, ca. \(Formatierung.gigabytes(model.bytesAusgewaehlt()))")
                .font(.title2)
            Text("Danach fragt das iPhone noch einmal, ob du wirklich löschen willst.")
                .multilineTextAlignment(.center)
                .padding()
            if model.brauchtSicherung() {
                Text("Zuerst Sicherung nach iCloud Drive, dann Löschen.")
                    .font(.body)
            }
            HauptButton(titel: "Jetzt starten", aktiv: !model.ausgewaehlt.isEmpty) {
                model.phase = .lauf
                Task { await model.loeschenBestaetigt() }
            }
            Button("Zurück") { model.phase = .auswahl }
        }
        .padding()
    }
}

struct BerichtView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fertig")
                        .font(.largeTitle.bold())
                    if model.freigewordenerPlatz > 0 {
                        Text("Etwa \(Formatierung.gigabytes(model.freigewordenerPlatz)) mehr frei.")
                            .font(.title2)
                    } else if let s = model.speicherNachher {
                        Text("Aktuell \(Formatierung.gigabytes(s.freiBytes)) frei.")
                            .font(.title2)
                    }
                    if let e = model.ergebnis {
                        Text("Gelöscht: \(e.geloescht.count)")
                        if !e.nichtGeloescht.isEmpty {
                            Text("Nicht gelöscht: \(e.nichtGeloescht.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Wichtig: In der Fotos-App unter „Zuletzt gelöscht“ noch „Alle löschen“ tippen, damit der Speicher wirklich frei wird.")
                        .font(.body)
                        .padding(.top, 8)
                }
                .padding()
            }
            HauptButton(titel: "Fotos-App öffnen") { FotosAppOeffner.oeffnen() }
            HauptButton(titel: "Neu scannen") {
                model.ergebnis = nil
                Task { await model.scanStarten() }
            }
        }
    }
}

enum FotosAppOeffner {
    static func oeffnen() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
}
