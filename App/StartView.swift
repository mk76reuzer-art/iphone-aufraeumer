import SwiftUI
import UIKit
import AufraeumerKern

struct StartView: View {
    @StateObject private var model = AufraeumerModel()
    @State private var tippsOffen = false

    var body: some View {
        NavigationStack {
            ZStack {
                inhalt
                if model.phase == .scannt || model.phase == .lauf {
                    FortschrittOverlay(model: model)
                }
            }
            .navigationTitle("Aufräumen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if model.phase == .uebersicht || model.phase == .auswahl {
                        Button("Tipps") { tippsOffen = true }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if model.phase != .scannt && model.phase != .lauf && model.phase != .start {
                        Button("Abbrechen") { model.abbrechenOhneVerlust() }
                    }
                }
            }
            .navigationDestination(isPresented: $tippsOffen) { TippsView() }
            .sheet(isPresented: $model.ordnerWaehlen) {
                OrdnerAuswahl(istAktiv: $model.ordnerWaehlen,
                              onGewaehlt: { model.ordnerGewaehlt($0) },
                              onAbbruch: { model.ordnerAbbruch() })
            }
            .sheet(isPresented: $model.iCloudFotosFrageOffen) {
                ICloudFotosFrageSheet(erledigt: .constant(true))
            }
            .sheet(isPresented: $model.zeigeVideoVerkleinern) {
                VideoVerkleinernSheet(model: model)
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
            SichernView(model: model)
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
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 16) {
            if model.phase == .lauf {
                SchrittLeiste(aktuell: model.aktuellerSchritt(), nutzenSatz: model.nutzenSatz(fuer: model.aktuellerSchritt()))
            }
            ProgressView(value: model.phase == .scannt ? model.scanFortschritt : model.laufFortschritt)
                .progressViewStyle(.linear)
                .tint(.accentColor)
            Text(Formatierung.prozent(model.phase == .scannt ? model.scanFortschritt : model.laufFortschritt))
                .font(.largeTitle.bold())
            if model.uploadProzent > 0 {
                Text("In die Cloud: \(Formatierung.prozent(model.uploadProzent))")
                    .font(.title3)
            }
            if model.phase == .lauf && model.laufDateiGesamt > 0 {
                Text("Datei \(model.laufDateiIndex) von \(model.laufDateiGesamt)")
                    .font(.body)
                if !model.laufRestzeitText.isEmpty {
                    Text(model.laufRestzeitText).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text(model.phase == .scannt ? model.scanText : model.laufText)
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
            SchrittLeiste(aktuell: .pruefen, nutzenSatz: model.nutzenSatz(fuer: .pruefen))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    speicherKarte
                    if let fehler = model.fehlerText {
                        Text(fehler).foregroundStyle(.red).font(.body)
                    }
                    videoBlock
                    Text("Aufräum-Vorschläge")
                        .font(.title2.bold())
                    ForEach(Kategorie.allCases, id: \.self) { kat in
                        kategorieZeile(kat)
                    }
                }
                .padding()
            }
            HauptButton(titel: "Auswählen", aktiv: model.scan != nil) {
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
                    Text("Am meisten Platz: \(g.name) (\(Formatierung.gigabytes(g.bytes)))")
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
        .accessibilityIdentifier("speicher-karte")
    }

    @ViewBuilder
    private var videoBlock: some View {
        let spare = model.geschaetzteVideoErsparnis()
        if spare > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Videos verkleinern").font(.headline)
                Text("Große Videos in kleinere Qualität umwandeln – geschätzt \(Formatierung.gigabytes(spare)) weniger.")
                    .font(.body)
                Button("Videos ansehen") { model.zeigeVideoVerkleinern = true }
                    .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
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
}

struct AuswahlView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 0) {
            SchrittLeiste(aktuell: .auswaehlen, nutzenSatz: model.nutzenSatz(fuer: .auswaehlen))
            List {
                sicherungsOptionen
                Section("Deine Auswahl") {
                    Text("Markiert: \(model.ausgewaehlt.count)")
                    ForEach(gruppiert, id: \.kat) { block in
                        Section(block.kat.anzeigeName) {
                            ForEach(block.ids, id: \.self) { id in
                                zeile(id: id)
                            }
                        }
                    }
                }
            }
            HauptButton(titel: "Weiter", aktiv: !model.ausgewaehlt.isEmpty) {
                model.weiterVonAuswahl()
            }
        }
    }

    private func sicherungBinding(_ keyPath: WritableKeyPath<SicherungsOptionen, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.sicherungsOptionen[keyPath: keyPath] },
            set: { neu in
                var o = model.sicherungsOptionen
                o[keyPath: keyPath] = neu
                model.sicherungsOptionen = o
            })
    }

    private var sicherungsOptionen: some View {
        Section("Sicherung (optional)") {
            Text("Doppelte, Serien und Bildschirmfotos brauchen normalerweise keine Kopie. Du kannst es trotzdem einschalten.")
                .font(.footnote)
            Toggle("Doppelte auch sichern", isOn: sicherungBinding(\.duplikateSichern))
            Toggle("Serienbilder auch sichern", isOn: sicherungBinding(\.serienSichern))
            Toggle("Bildschirmfotos auch sichern", isOn: sicherungBinding(\.screenshotsSichern))
        }
    }

    private struct Block {
        let kat: Kategorie
        let ids: [String]
    }

    private var gruppiert: [Block] {
        guard let scan = model.scan else { return [] }
        return Kategorie.allCases.compactMap { kat in
            let ids = (scan.kategorien[kat] ?? []).sorted()
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

struct SichernView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 16) {
            SchrittLeiste(aktuell: .sichern, nutzenSatz: model.nutzenSatz(fuer: .sichern))
            Text("Sicherungsordner")
                .font(.title.bold())
            Text(model.sicherOrdnerName.map { "Gewählt: \($0)" } ?? "Noch kein Ordner")
                .font(.title3)
            Text("Tippe unten, um in der Dateien-App einen Ordner zu wählen – zum Beispiel iCloud Drive, Auf meinem iPhone oder einen Stick.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Ordner wählen") { model.ordnerWaehlen = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer()
            HauptButton(titel: "Weiter zum Löschen", aktiv: model.hatSicherungsordner) {
                model.weiterVonSichern()
            }
        }
        .padding()
    }
}

struct BestaetigenView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 16) {
            SchrittLeiste(aktuell: .loeschen, nutzenSatz: model.nutzenSatz(fuer: .loeschen))
            Text("Letzte Bestätigung")
                .font(.title.bold())
            Text("\(model.ausgewaehlt.count) Dateien, etwa \(Formatierung.gigabytes(model.bytesAusgewaehlt()))")
                .font(.title2)
            if ICloudFotosSpeicher.nutzerSagtAktiv {
                Text("Mit iCloud-Fotos werden die Dateien auch aus der Cloud entfernt.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Text("Danach fragt das iPhone noch einmal, ob du wirklich löschen willst.")
                .multilineTextAlignment(.center)
                .padding()
            HauptButton(titel: "Jetzt löschen", aktiv: !model.ausgewaehlt.isEmpty) {
                Task { await model.loeschenBestaetigt() }
            }
            Button("Zurück") { model.phase = model.brauchtSicherung() ? .sichern : .auswahl }
        }
        .padding()
    }
}

struct BerichtView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 16) {
            SchrittLeiste(aktuell: .loeschen, nutzenSatz: "Fertig – so holst du den Speicher zurück.")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Geschafft")
                        .font(.largeTitle.bold())
                    if model.freigewordenerPlatz > 0 {
                        Text("\(Formatierung.gigabytes(model.freigewordenerPlatz)) frei geworden.")
                            .font(.title2)
                    }
                    if let vor = model.speicher, let nach = model.speicherNachher {
                        Text("Vorher \(Formatierung.gigabytes(vor.freiBytes)) frei, jetzt \(Formatierung.gigabytes(nach.freiBytes)) frei.")
                            .font(.body)
                    }
                    if let e = model.ergebnis {
                        Text("Entfernt: \(e.geloescht.count)")
                        if !e.nichtGeloescht.isEmpty {
                            Text("\(e.nichtGeloescht.count) konnten nicht gelöscht werden.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    ZuletztGeloeschtAnleitung()
                }
                .padding()
            }
            HauptButton(titel: "Fotos-App öffnen") { FotosAppOeffner.oeffnen() }
            HauptButton(titel: "Neu prüfen") {
                model.ergebnis = nil
                Task { await model.scanStarten() }
            }
        }
    }
}

struct VideoVerkleinernSheet: View {
    @ObservedObject var model: AufraeumerModel
    @Environment(\.dismiss) private var dismiss
    @State private var auswahl: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Text("Geschätzte Ersparnis: \(Formatierung.gigabytes(model.geschaetzteVideoErsparnis()))")
                ForEach(model.grosseVideoKandidaten(), id: \.id) { k in
                    Toggle(isOn: Binding(
                        get: { auswahl.contains(k.id) },
                        set: { an in if an { auswahl.insert(k.id) } else { auswahl.remove(k.id) } }
                    )) {
                        VStack(alignment: .leading) {
                            Text(k.name)
                            Text(Formatierung.gigabytes(k.groesseBytes)).font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Videos verkleinern")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HauptButton(titel: "Verkleinern starten", aktiv: !auswahl.isEmpty) {
                    dismiss()
                    Task { await model.videosVerkleinernStarten(ids: auswahl) }
                }
            }
            .onAppear {
                auswahl = Set(model.grosseVideoKandidaten().map(\.id))
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
