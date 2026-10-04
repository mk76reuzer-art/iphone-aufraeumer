import SwiftUI
import UIKit
import Combine
import AufraeumerKern

struct StartView: View {
    @StateObject private var model = AufraeumerModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                inhalt
                if model.phase == .scannt || model.phase == .lauf {
                    FortschrittOverlay(model: model)
                }
            }
            .navigationTitle("Aufräumen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if model.phase == .uebersicht || model.phase == .auswahl {
                        Button("Tipps") { model.tippsAnzeigen = true }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if model.phase == .auswahl || model.phase == .sichern || model.phase == .bestaetigen {
                        Button("Abbrechen") { model.abbrechenOhneVerlust() }
                    }
                }
            }
            .navigationDestination(isPresented: $model.tippsAnzeigen) { TippsView() }
            .sheet(isPresented: $model.ordnerWaehlen) {
                OrdnerAuswahl(istAktiv: $model.ordnerWaehlen, startOrdner: model.startOrdner,
                              onGewaehlt: { model.ordnerGewaehlt($0) },
                              onAbbruch: { model.ordnerAbbruch() })
            }
            .sheet(isPresented: $model.iCloudFotosFrageOffen) {
                ICloudFotosFrageSheet { model.iCloudAntwort($0) }
            }
            .sheet(isPresented: $model.zeigeVideoVerkleinern) {
                VideoVerkleinernSheet(model: model)
            }
            .task { await model.beimStart() }
            .onChange(of: scenePhase) { neu in
                guard neu == .active else { return }
                if model.phase == .bericht {
                    model.erneutMessen()
                }
                if model.fehlerIstZugriff && model.phase == .uebersicht {
                    Task { await model.scanStarten() }
                }
            }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch model.phase {
        case .start, .scannt, .lauf:
            Color(.systemBackground)
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
        }
    }
}

private struct FortschrittOverlay: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 18) {
            SchrittLeiste(aktuell: model.aktuellerSchritt(), nutzenSatz: model.nutzenSatz(fuer: model.aktuellerSchritt()))
            Spacer()
            ProgressView(value: model.phase == .scannt ? model.scanFortschritt : model.laufFortschritt)
                .progressViewStyle(.linear)
            Text(Formatierung.prozent(model.phase == .scannt ? model.scanFortschritt : model.laufFortschritt))
                .font(.system(size: 56, weight: .bold, design: .rounded))
            if model.phase == .lauf {
                Text(model.laufSchrittText).font(.title3)
                if model.laufDateiGesamt > 0 {
                    Text("Datei \(model.laufDateiIndex) von \(model.laufDateiGesamt)")
                        .font(.title3)
                }
                if !model.laufText.isEmpty {
                    Text(model.laufText).font(.body).multilineTextAlignment(.center)
                }
                if !model.laufRestzeitText.isEmpty {
                    Text(model.laufRestzeitText).font(.body).foregroundStyle(.secondary)
                }
            } else {
                Text(model.scanText).font(.title3).multilineTextAlignment(.center)
            }
            Spacer()
            Button("Abbrechen") { model.abbrechenLauf() }
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .buttonStyle(.bordered)
                .padding(.horizontal)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .bildschirm(model.phase == .scannt ? "bildschirm-scan" : "bildschirm-lauf")
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            model.objectWillChange.send()
        }
    }
}

struct UebersichtView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 0) {
            SchrittLeiste(aktuell: .pruefen, nutzenSatz: model.fehlerIstZugriff
                          ? "Ohne Fotos geht das Aufräumen nicht."
                          : model.nutzenSatz(fuer: .pruefen))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    speicherKarte
                    if let fehler = model.fehlerText {
                        HinweisKasten(text: fehler, warnung: true)
                            .bildschirm(model.fehlerIstZugriff ? "bildschirm-fehler" : "hinweis-kasten")
                    }
                    if let hinweis = model.scan?.hinweis {
                        HinweisKasten(text: hinweis, warnung: false)
                    }
                    if let scan = model.scan, scan.anzahlNurCloud > 0 {
                        HinweisKasten(text: "\(scan.anzahlNurCloud) Dateien liegen nur in iCloud. Sie stehen in der Liste mit einem Hinweis. Löschen macht auf dem iPhone fast nichts frei und löscht sie auch in der Cloud.", warnung: false)
                    }
                    videoBlock
                    if model.scan != nil && !model.fehlerIstZugriff && !model.pruefungLeerTrotzMedien {
                        Text("Größte Dateien").font(.title2.bold())
                        Text("Antippen wählt aus. Die größten stehen oben.")
                            .font(.body)
                        ForEach(model.groessteBrocken()) { k in
                            brockenZeile(k)
                        }
                        if !model.gruppenZeilen().isEmpty {
                            Text("Gruppen").font(.title3.bold())
                            ForEach(model.gruppenZeilen()) { zeile in
                                Text("\(zeile.kat.anzeigeName): \(zeile.anzahl) Dateien, \(Formatierung.gigabytes(zeile.bytes))")
                                    .font(.body)
                            }
                        }
                    }
                    if model.berichtKopiert {
                        Text("Bericht ist kopiert. Du kannst ihn jetzt schicken.")
                            .font(.body)
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    hauptknopf
                    if !model.fehlerIstZugriff && !model.pruefungLeerTrotzMedien {
                        Button("Speicher-Bericht kopieren") { model.berichtKopieren() }
                            .font(.body)
                            .padding(.bottom, 8)
                    }
                }
                .background(Color(.systemBackground))
            }
        }
        .bildschirm("bildschirm-uebersicht")
    }

    private var speicherKarte: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.fehlerIstZugriff {
                Text("Fotos sind gesperrt")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Tippe unten auf Einstellungen öffnen und wähle Alle Fotos.")
                    .font(.title3)
                if let s = model.speicher {
                    Text("\(Formatierung.gigabytes(s.freiBytes)) von \(Formatierung.gigabytes(s.gesamtBytes)) sind frei.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } else if let s = model.speicher {
                Text("\(Formatierung.gigabytes(s.freiBytes)) frei")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Belegt sind \(Formatierung.gigabytes(s.belegtBytes)) von \(Formatierung.gigabytes(s.gesamtBytes)).")
                    .font(.body)
                if let scan = model.scan {
                    Text("Fotos und Videos auf dem iPhone: \(Formatierung.gigabytes(scan.mediathekLokalBytes)), davon Videos \(Formatierung.gigabytes(scan.videoLokalBytes)).")
                        .font(.body)
                }
                Text(model.bilanzSatz())
                    .font(.body)
            } else {
                Text(model.bilanzSatz())
                    .font(.title3)
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
            VStack(alignment: .leading, spacing: 6) {
                Text("Videos verkleinern, etwa \(Formatierung.gigabytes(spare)) weniger")
                    .font(.headline)
                Text("Das Original bleibt, bis du die Frage bestätigst.")
                    .font(.body)
                Button("Videos verkleinern") { model.zeigeVideoVerkleinern = true }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.green.opacity(0.12))
            .cornerRadius(12)
        }
    }

    private func brockenZeile(_ k: Kandidat) -> some View {
        HStack(spacing: 12) {
            FotoVorschau(assetId: k.id)
                .frame(width: 56, height: 56)
                .cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(k.name).font(.headline).lineLimit(1)
                Text(groesseText(k))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if k.nurInCloud {
                    Text("Nur in iCloud. Löschen macht hier fast nichts frei und löscht auch in der Cloud.")
                        .font(.subheadline)
                }
            }
            Spacer()
            if !k.nurInCloud && Regeln.bringtPlatz(k) {
                Image(systemName: model.ausgewaehlt.contains(k.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !k.nurInCloud, Regeln.bringtPlatz(k) else { return }
            if model.ausgewaehlt.contains(k.id) {
                model.ausgewaehlt.remove(k.id)
            } else {
                model.ausgewaehlt.insert(k.id)
            }
        }
        .padding(.vertical, 4)
    }

    private func groesseText(_ k: Kandidat) -> String {
        var teile = [Formatierung.gigabytes(k.groesseBytes)]
        if k.istFavorit { teile.append("Favorit") }
        return teile.joined(separator: ", ")
    }

    @ViewBuilder
    private var hauptknopf: some View {
        if model.fehlerIstZugriff {
            HauptButton(titel: "Einstellungen öffnen") { EinstellungenOeffner.appEinstellungen() }
        } else if model.scan == nil {
            HauptButton(titel: "Erneut versuchen") { Task { await model.scanStarten() } }
        } else if model.pruefungLeerTrotzMedien {
            HauptButton(titel: "Speicher-Bericht kopieren") { model.berichtKopieren() }
        } else if model.bytesAusgewaehlt() > 0 {
            HauptButton(titel: "\(Formatierung.gigabytes(model.bytesAusgewaehlt())) freimachen") {
                model.weiterVonAuswahl()
            }
            .accessibilityIdentifier("knopf-freimachen")
        } else if model.groessteBrocken().isEmpty {
            HauptButton(titel: "Tipps ansehen") { model.tippsAnzeigen = true }
        } else {
            HauptButton(titel: "Dateien antippen", aktiv: false) {}
        }
    }
}

struct AuswahlView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 0) {
            SchrittLeiste(aktuell: .auswaehlen, nutzenSatz: model.nutzenSatz(fuer: .auswaehlen))
            List {
                Section {
                    Text("Doppelte, Serien und Bildschirmfotos werden ohne Kopie gelöscht. Große Dateien sichert die App nur, wenn du es eingeschaltet lässt.")
                        .font(.body)
                    Toggle("Große Dateien vorher sichern", isOn: sicherungBinding(\.grosseSichern))
                    Toggle("Doppelte auch sichern", isOn: sicherungBinding(\.duplikateSichern))
                    Toggle("Serienbilder auch sichern", isOn: sicherungBinding(\.serienSichern))
                    Toggle("Bildschirmfotos auch sichern", isOn: sicherungBinding(\.screenshotsSichern))
                }
                ForEach(model.auswahlBloecke()) { block in
                    Section(block.kat.anzeigeName) {
                        ForEach(block.ids, id: \.self) { id in
                            zeile(id: id)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HauptButton(titel: "Weiter", aktiv: !model.ausgewaehlt.isEmpty) {
                    model.weiterVonAuswahl()
                }
                .background(Color(.systemBackground))
            }
        }
        .bildschirm("bildschirm-auswahl")
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

    private func zeile(id: String) -> some View {
        HStack(spacing: 12) {
            FotoVorschau(assetId: id)
                .frame(width: 56, height: 56)
                .cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.kandidat(id)?.name ?? "Foto").lineLimit(1)
                if let k = model.kandidat(id) {
                    Text(k.istFavorit ? "\(Formatierung.gigabytes(k.groesseBytes)), Favorit" : Formatierung.gigabytes(k.groesseBytes))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("Auswählen", isOn: Binding(
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
        VStack(alignment: .leading, spacing: 16) {
            SchrittLeiste(aktuell: .sichern, nutzenSatz: model.nutzenSatz(fuer: .sichern))
            if let fehler = model.fehlerText {
                HinweisKasten(text: fehler, warnung: true).padding(.horizontal)
            }
            if model.hatSicherungsordner {
                Text("Ordner ist gewählt")
                    .font(.title.bold())
                    .padding(.horizontal)
                Text(model.sicherOrdnerName ?? "")
                    .font(.title3)
                    .padding(.horizontal)
                Text("Die Kopien liegen im Ordner Aufräumer-Sicherung. Die Sicherung ist empfohlen, aber keine Pflicht.")
                    .font(.body)
                    .padding(.horizontal)
                Spacer()
                Button("Anderen Ordner wählen") { model.ordnerWaehlen = true }
                    .font(.body)
                    .frame(maxWidth: .infinity)
                Button("Ohne Sicherung fortfahren") { model.ohneSicherungWeiter() }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                HauptButton(titel: "Weiter zum Löschen") { model.weiterVonSichern() }
            } else {
                Text("Sicherung ist freiwillig")
                    .font(.title.bold())
                    .padding(.horizontal)
                Text("Empfohlen, aber keine Pflicht. Ohne Ordner gibt es keine Kopie. Gelöschtes liegt dann 30 Tage unter Zuletzt gelöscht.")
                    .font(.body)
                    .padding(.horizontal)
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Tippe auf Ordner wählen.")
                    Text("2. Tippe links auf iCloud Drive, Auf meinem iPhone, OneDrive oder deinen Stick.")
                    Text("3. Öffne den Ordner, in den kopiert werden soll.")
                    Text("4. Tippe oben rechts auf Öffnen.")
                }
                .font(.title3)
                .padding(.horizontal)
                Spacer()
                Button("Ohne Sicherung fortfahren") { model.ohneSicherungWeiter() }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                HauptButton(titel: "Ordner wählen") { model.ordnerWaehlen = true }
            }
        }
        .padding(.bottom, 4)
        .bildschirm("bildschirm-sichern")
    }
}

struct BestaetigenView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SchrittLeiste(aktuell: .loeschen, nutzenSatz: model.nutzenSatz(fuer: .loeschen))
            Text("Wirklich löschen?")
                .font(.title.bold())
                .padding(.horizontal)
            Text("\(model.ausgewaehlt.count) Dateien, etwa \(Formatierung.gigabytes(model.bytesAusgewaehlt())).")
                .font(.title2)
                .padding(.horizontal)
            if ICloudFotosSpeicher.nutzerSagtAktiv {
                Text("Mit iCloud-Fotos verschwinden die Dateien auch aus der Cloud und von deinen anderen Geräten.")
                    .font(.body)
                    .padding(.horizontal)
            }
            if model.verzichtetAufEmpfohleneSicherung {
                Text("Ohne Sicherung. Es gibt keine Kopie. Gelöschtes bleibt 30 Tage unter Zuletzt gelöscht, danach ist es weg.")
                    .font(.title3)
                    .padding(.horizontal)
            }
            Text("Das iPhone fragt danach noch einmal. Wenn du ablehnst, bleibt alles.")
                .font(.body)
                .padding(.horizontal)
            if model.favoritenInAuswahl > 0 {
                Toggle("Favoriten trotzdem löschen", isOn: $model.favoritenTrotzdem)
                    .padding(.horizontal)
                Text(model.favoritenTrotzdem
                     ? "Die markierten Favoriten werden mitgelöscht."
                     : "Nimm die Favoriten aus der Auswahl oder schalte den Schalter ein.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            Spacer()
            Button("Zurück") {
                model.phase = model.brauchtSicherung() ? .sichern : .auswahl
            }
            .font(.body)
            .frame(maxWidth: .infinity)
            HauptButton(
                titel: model.verzichtetAufEmpfohleneSicherung ? "Ohne Sicherung löschen" : "Jetzt löschen",
                aktiv: model.loeschenBereit
            ) {
                model.loeschenBestaetigt()
            }
        }
        .bildschirm("bildschirm-loeschen")
    }
}

struct BerichtView: View {
    @ObservedObject var model: AufraeumerModel

    var body: some View {
        VStack(spacing: 0) {
            SchrittLeiste(aktuell: .loeschen, nutzenSatz: "Fertig. So holst du den Speicher zurück.")
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Geschafft")
                        .font(.largeTitle.bold())
                    if model.laufAbgebrochen && (model.ergebnis?.geloescht.isEmpty ?? true) {
                        Text("Abgebrochen. Es wurde nichts gelöscht. Was schon kopiert wurde, liegt im Sicherungsordner.")
                            .font(.title3)
                    } else if model.freigewordenerPlatz > 0 {
                        Text("\(Formatierung.gigabytes(model.freigewordenerPlatz)) frei geworden.")
                            .font(.title.bold())
                    } else if model.erwarteteFreigabe() > 0 && model.speicherUnveraendert {
                        Text("Jetzt noch Zuletzt gelöscht leeren, dann sind die \(Formatierung.gigabytes(model.erwarteteFreigabe())) frei.")
                            .font(.title3)
                    } else if model.erwarteteFreigabe() > 0 {
                        Text("Etwa \(Formatierung.gigabytes(model.erwarteteFreigabe())) werden frei, sobald du Zuletzt gelöscht leerst.")
                            .font(.title3)
                    }
                    if model.berichtKopiert {
                        Text("Bericht ist kopiert. Du kannst ihn jetzt schicken.")
                            .font(.body)
                    }
                    if let nach = model.speicherNachher {
                        Text("Vorher \(Formatierung.gigabytes(model.freiVorher)) frei, jetzt \(Formatierung.gigabytes(nach.freiBytes)) frei.")
                            .font(.body)
                    }
                    if model.berichtArt == .nurVideosVerkleinern {
                        Text("Die kleinere Fassung bleibt in Fotos. Die große liegt in Zuletzt gelöscht.")
                            .font(.body)
                    }
                    if let e = model.ergebnis {
                        let wort = model.berichtArt == .nurVideosVerkleinern ? "Verkleinert" : "Entfernt"
                        Text("\(wort): \(e.geloescht.count)")
                        if let grund = e.nichtGeloescht.values.first {
                            Text("\(e.nichtGeloescht.count) nicht erledigt. \(grund)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let fehler = model.fehlerText {
                        HinweisKasten(text: fehler, warnung: true)
                    }
                    ZuletztGeloeschtAnleitung()
                }
                .padding()
            }
            Button("Speicher-Bericht kopieren") { model.berichtKopieren() }
                .font(.body)
                .frame(maxWidth: .infinity)
            Button("Neu prüfen") {
                model.ergebnis = nil
                model.fehlerText = nil
                Task { await model.scanStarten() }
            }
            .font(.body)
            .frame(maxWidth: .infinity)
            HauptButton(titel: "Fotos-App öffnen") { FotosAppOeffner.oeffnen() }
        }
        .bildschirm("bildschirm-bericht")
    }
}

struct VideoVerkleinernSheet: View {
    @ObservedObject var model: AufraeumerModel
    @Environment(\.dismiss) private var dismiss
    @State private var auswahl: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    if let hinweis = platzHinweis {
                        HinweisKasten(text: hinweis, warnung: true)
                    } else {
                        Text("Geschätzt \(Formatierung.gigabytes(gewaehlteErsparnis())) weniger. Datum und Ort bleiben erhalten.")
                    }
                    ForEach(model.grosseVideoKandidaten(), id: \.id) { k in
                        Toggle(isOn: Binding(
                            get: { auswahl.contains(k.id) },
                            set: { an in if an { auswahl.insert(k.id) } else { auswahl.remove(k.id) } }
                        )) {
                            VStack(alignment: .leading) {
                                Text(k.name)
                                Text("\(Formatierung.gigabytes(k.groesseBytes)), spart etwa \(Formatierung.gigabytes(model.ersparnis(fuer: k)))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                HauptButton(titel: "Jetzt verkleinern", aktiv: !auswahl.isEmpty && platzHinweis == nil) {
                    let ids = auswahl
                    dismiss()
                    model.videosVerkleinernStarten(ids: ids)
                }
            }
            .navigationTitle("Videos verkleinern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onAppear { auswahl = Set(model.grosseVideoKandidaten().map(\.id)) }
            .bildschirm("bildschirm-videos")
        }
    }

    private var platzHinweis: String? {
        let liste = model.grosseVideoKandidaten().filter { auswahl.contains($0.id) }
        let basis = liste.isEmpty ? model.grosseVideoKandidaten() : liste
        return VideoVerkleinerer.platzHinweis(kandidaten: basis, frei: SpeicherAnzeige.lesen()?.freiBytes)
    }

    private func gewaehlteErsparnis() -> Int64 {
        model.grosseVideoKandidaten().filter { auswahl.contains($0.id) }.reduce(0) {
            $0 + model.ersparnis(fuer: $1)
        }
    }
}

struct HinweisKasten: View {
    let text: String
    var warnung: Bool

    var body: some View {
        Text(text)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background((warnung ? Color.red : Color.orange).opacity(0.12))
            .cornerRadius(12)
    }
}

enum FotosAppOeffner {
    static func oeffnen() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
}
