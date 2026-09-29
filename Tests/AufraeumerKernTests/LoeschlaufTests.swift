import XCTest
@testable import AufraeumerKern

final class LoeschlaufTests: XCTestCase {
    private var log: Ereignisse!
    private var bib: FakeBibliothek!
    private var sich: FakeSicherung!

    override func setUp() {
        log = Ereignisse()
        bib = FakeBibliothek(log: log)
        sich = FakeSicherung()
    }

    private func lauf(aufEintrag: (@Sendable (ProtokollEintrag) async throws -> Void)? = nil) -> Loeschlauf {
        Loeschlauf(bibliothek: bib, sicherung: sich, wartezeit: 0.05, pollIntervall: 0.005,
                   jetzt: { T.jetzt }, aufEintrag: aufEintrag)
    }

    private func sichern(_ id: String, favorit: Bool = false, bestaetigt: Bool = false) -> Auswahl {
        Auswahl(kandidat: T.k(id, video: true, favorit: favorit), modus: .erstSichern, favoritBestaetigt: bestaetigt)
    }

    private func nurLoeschen(_ id: String) -> Auswahl {
        Auswahl(kandidat: T.k(id, screenshot: true), modus: .nurLoeschen, favoritBestaetigt: false)
    }

    private func aktionen(_ e: LoeschlaufErgebnis) -> [String] {
        e.protokoll.eintraege.map { "\($0.aktion.rawValue):\($0.id)" }
    }

    func testErstSichernLoeschtNachVollstaendigerPruefungUndProtokolliertInRichtigerReihenfolge() async {
        let e = await lauf().ausfuehren(auswahl: [sichern("A"), sichern("B")], gruppen: [], bestaetigt: true)
        XCTAssertEqual(e.geloescht, ["A", "B"])
        XCTAssertTrue(e.nichtGeloescht.isEmpty)
        XCTAssertEqual(log.liste, ["export:A", "export:B", "loeschen:A,B"])
        XCTAssertEqual(aktionen(e), ["gesichert:A", "gesichert:B", "beabsichtigt:A", "beabsichtigt:B",
                                     "geloescht:A", "geloescht:B"])
    }

    func testOhneBestaetigungWirdNichtsGetan() async {
        let e = await lauf().ausfuehren(auswahl: [sichern("A"), nurLoeschen("B")], gruppen: [], bestaetigt: false)
        XCTAssertTrue(e.geloescht.isEmpty)
        XCTAssertEqual(Set(e.nichtGeloescht.keys), ["A", "B"])
        XCTAssertTrue(log.liste.isEmpty)
    }

    func testBeabsichtigtWirdVorDemLoeschaufrufNotiert() async {
        let ereignisse = log!
        let l = lauf(aufEintrag: { ereignisse.add("protokoll:\($0.aktion.rawValue):\($0.id)") })
        _ = await l.ausfuehren(auswahl: [nurLoeschen("A")], gruppen: [], bestaetigt: true)
        let vorher = log.index("protokoll:beabsichtigt:A")
        let loeschen = log.index("loeschen:A")
        XCTAssertNotNil(vorher)
        XCTAssertNotNil(loeschen)
        XCTAssertLessThan(vorher ?? Int.max, loeschen ?? 0)
        XCTAssertLessThan(loeschen ?? Int.max, log.index("protokoll:geloescht:A") ?? 0)
    }

    func testUploadNieFertigDannWirdNichtGeloescht() async {
        sich.hochgeladenNach = Int.max
        let e = await lauf().ausfuehren(auswahl: [sichern("A")], gruppen: [], bestaetigt: true)
        XCTAssertTrue(e.geloescht.isEmpty)
        XCTAssertEqual(e.nichtGeloescht["A"], "Upload nicht rechtzeitig fertig")
        XCTAssertFalse(log.enthaeltPraefix("loeschen:"))
        XCTAssertEqual(aktionen(e), ["abgebrochen:A"])
    }

    func testFalschePruefsummeUndFalscheGroesseVerhindernLoeschen() async {
        sich.kopieSummeVerfaelscht = ["sum-A"]
        var e = await lauf().ausfuehren(auswahl: [sichern("A")], gruppen: [], bestaetigt: true)
        XCTAssertEqual(e.nichtGeloescht["A"], "Prüfsumme der Kopie stimmt nicht")

        sich.kopieSummeVerfaelscht = []
        sich.kopieBytesAbweichung = -1
        e = await lauf().ausfuehren(auswahl: [sichern("B")], gruppen: [], bestaetigt: true)
        XCTAssertEqual(e.nichtGeloescht["B"], "Größe der Kopie stimmt nicht")
        XCTAssertFalse(log.enthaeltPraefix("loeschen:"))
    }

    func testExportFehlerBetrifftNurDieseDatei() async {
        bib.exportFehlerFuer = ["A"]
        let e = await lauf().ausfuehren(auswahl: [sichern("A"), sichern("B")], gruppen: [], bestaetigt: true)
        XCTAssertEqual(e.geloescht, ["B"])
        XCTAssertNotNil(e.nichtGeloescht["A"])
        XCTAssertEqual(log.liste.last, "loeschen:B")
    }

    func testAbgelehnteLoeschabfrageProtokolliertBeabsichtigtDannAbgebrochen() async {
        bib.loeschFehler = FakeFehler.nutzerAbbruch
        let e = await lauf().ausfuehren(auswahl: [nurLoeschen("A"), nurLoeschen("B")], gruppen: [], bestaetigt: true)
        XCTAssertTrue(e.geloescht.isEmpty)
        XCTAssertEqual(Set(e.nichtGeloescht.keys), ["A", "B"])
        XCTAssertEqual(aktionen(e), ["beabsichtigt:A", "beabsichtigt:B", "abgebrochen:A", "abgebrochen:B"])
    }

    func testAlleExemplareEinerDuplikatgruppeOhneSicherungBehaeltEines() async {
        let gruppe = DuplikatGruppe(behalten: "A", loeschbar: ["B", "C"])
        let e = await lauf().ausfuehren(auswahl: [nurLoeschen("A"), nurLoeschen("B"), nurLoeschen("C")],
                                        gruppen: [gruppe], bestaetigt: true)
        XCTAssertEqual(e.geloescht, ["B", "C"])
        XCTAssertEqual(e.nichtGeloescht["A"], "Letztes Exemplar einer Duplikatgruppe bleibt erhalten")
        XCTAssertEqual(log.liste, ["loeschen:B,C"])
    }

    func testDuplikatgruppeMitVerifizierterSicherungDarfKomplettGeloeschtWerden() async {
        let gruppe = DuplikatGruppe(behalten: "A", loeschbar: ["B"])
        let e = await lauf().ausfuehren(auswahl: [sichern("A"), nurLoeschen("B")], gruppen: [gruppe], bestaetigt: true)
        XCTAssertEqual(e.geloescht, ["A", "B"])
    }

    func testTeilAuswahlEinerGruppeLoeschtNormal() async {
        let gruppe = DuplikatGruppe(behalten: "A", loeschbar: ["B", "C"])
        let e = await lauf().ausfuehren(auswahl: [nurLoeschen("B"), nurLoeschen("C")], gruppen: [gruppe], bestaetigt: true)
        XCTAssertEqual(e.geloescht, ["B", "C"])
    }

    func testDieselbeDateiZweimalAusgewaehltWirdEinmalVerarbeitet() async {
        let e = await lauf().ausfuehren(auswahl: [sichern("A"), sichern("A")], gruppen: [], bestaetigt: true)
        XCTAssertEqual(e.geloescht, ["A"])
        XCTAssertEqual(log.liste, ["export:A", "loeschen:A"])
    }

    func testFavoritOhneBestaetigungWirdNichtGeloescht() async {
        var e = await lauf().ausfuehren(auswahl: [sichern("A", favorit: true)], gruppen: [], bestaetigt: true)
        XCTAssertTrue(e.geloescht.isEmpty)
        XCTAssertEqual(e.nichtGeloescht["A"], "Favorit ohne ausdrückliche Bestätigung")
        XCTAssertFalse(log.enthaeltPraefix("loeschen:"))

        e = await lauf().ausfuehren(auswahl: [sichern("B", favorit: true, bestaetigt: true)], gruppen: [], bestaetigt: true)
        XCTAssertEqual(e.geloescht, ["B"])
    }

    func testNurLoeschenBrauchtKeinenExport() async {
        let e = await lauf().ausfuehren(auswahl: [nurLoeschen("A")], gruppen: [], bestaetigt: true)
        XCTAssertEqual(e.geloescht, ["A"])
        XCTAssertFalse(log.enthaeltPraefix("export:"))
    }

    func testWennNichtsFreigegebenWirdIstDieBibliothekNieAufgerufen() async {
        sich.hochgeladenNach = Int.max
        _ = await lauf().ausfuehren(auswahl: [sichern("A"), sichern("B")], gruppen: [], bestaetigt: true)
        XCTAssertFalse(log.enthaeltPraefix("loeschen:"))
    }

    // MARK: Nachbesserungen nach der Endprüfung

    func testVeralteteGruppeOhneNachbarnSchuetztTrotzdemDasBehalteneExemplar() async {
        let gruppe = DuplikatGruppe(behalten: "A", loeschbar: ["B", "C"])
        let e = await lauf().ausfuehren(auswahl: [nurLoeschen("A")], gruppen: [gruppe], bestaetigt: true)
        XCTAssertTrue(e.geloescht.isEmpty)
        XCTAssertEqual(e.nichtGeloescht["A"], "Letztes Exemplar einer Duplikatgruppe bleibt erhalten")
        XCTAssertFalse(log.enthaeltPraefix("loeschen:"))
    }

    func testBehaltenesExemplarOhneEigeneSicherungBleibtAuchWennAnderesMitgliedGesichertIst() async {
        let gruppe = DuplikatGruppe(behalten: "A", loeschbar: ["B"])
        let e = await lauf().ausfuehren(auswahl: [nurLoeschen("A"), sichern("B")], gruppen: [gruppe], bestaetigt: true)
        XCTAssertEqual(e.geloescht, ["B"])
        XCTAssertEqual(e.nichtGeloescht["A"], "Letztes Exemplar einer Duplikatgruppe bleibt erhalten")
    }

    func testWiderspruechlicheDoppelteAuswahlNimmtDenSichererenModus() async {
        let a1 = Auswahl(kandidat: T.k("A", video: true), modus: .nurLoeschen, favoritBestaetigt: false)
        let a2 = Auswahl(kandidat: T.k("A", video: true), modus: .erstSichern, favoritBestaetigt: false)
        let e = await lauf().ausfuehren(auswahl: [a1, a2], gruppen: [], bestaetigt: true)
        XCTAssertEqual(e.geloescht, ["A"])
        XCTAssertEqual(log.liste, ["export:A", "loeschen:A"])
    }

    func testWiderspruechlicheFavoritenBestaetigungGiltNurWennAlleBestaetigen() async {
        let k = T.k("A", video: true, favorit: true)
        let a1 = Auswahl(kandidat: k, modus: .erstSichern, favoritBestaetigt: true)
        let a2 = Auswahl(kandidat: k, modus: .erstSichern, favoritBestaetigt: false)
        let e = await lauf().ausfuehren(auswahl: [a1, a2], gruppen: [], bestaetigt: true)
        XCTAssertTrue(e.geloescht.isEmpty)
        XCTAssertEqual(e.nichtGeloescht["A"], "Favorit ohne ausdrückliche Bestätigung")
    }

    func testNichtLokaleOderGroessenloseDateienWerdenNieGeloescht() async {
        let nurCloud = Auswahl(kandidat: T.k("A", screenshot: true, lokal: false), modus: .nurLoeschen, favoritBestaetigt: false)
        let ohneGroesse = Auswahl(kandidat: T.k("B", groesse: 0, screenshot: true), modus: .nurLoeschen, favoritBestaetigt: false)
        let e = await lauf().ausfuehren(auswahl: [nurCloud, ohneGroesse], gruppen: [], bestaetigt: true)
        XCTAssertTrue(e.geloescht.isEmpty)
        XCTAssertEqual(e.nichtGeloescht["A"], "Datei nicht lokal vorhanden oder Größe unbekannt")
        XCTAssertEqual(e.nichtGeloescht["B"], "Datei nicht lokal vorhanden oder Größe unbekannt")
        XCTAssertFalse(log.enthaeltPraefix("loeschen:"))
    }

    func testLeererOderAbweichenderExportVerhindertLoeschen() async {
        bib.exportBytes = 0
        var e = await lauf().ausfuehren(auswahl: [sichern("A")], gruppen: [], bestaetigt: true)
        XCTAssertEqual(e.nichtGeloescht["A"], "Export ist leer")
        bib.exportBytes = 999
        e = await lauf().ausfuehren(auswahl: [sichern("B")], gruppen: [], bestaetigt: true)
        XCTAssertEqual(e.nichtGeloescht["B"], "Größe des Exports weicht vom Original ab")
        XCTAssertFalse(log.enthaeltPraefix("loeschen:"))
    }

    func testAbgebrochenerTaskLoeschtNichts() async {
        let l = lauf()
        let auswahl = [nurLoeschen("A")]
        let t = Task { () -> LoeschlaufErgebnis in
            while !Task.isCancelled { await Task.yield() }
            return await l.ausfuehren(auswahl: auswahl, gruppen: [], bestaetigt: true)
        }
        t.cancel()
        let e = await t.value
        XCTAssertTrue(e.geloescht.isEmpty)
        XCTAssertEqual(e.nichtGeloescht["A"], "Vorgang abgebrochen")
        XCTAssertFalse(log.enthaeltPraefix("loeschen:"))
    }

    func testSchreibfehlerBeimBeabsichtigtVerhindertDasLoeschen() async {
        let l = lauf(aufEintrag: { e in if e.aktion == .beabsichtigt { throw FakeFehler.ablegen } })
        let e = await l.ausfuehren(auswahl: [nurLoeschen("A")], gruppen: [], bestaetigt: true)
        XCTAssertTrue(e.geloescht.isEmpty)
        XCTAssertEqual(e.nichtGeloescht["A"], "Protokoll konnte nicht geschrieben werden")
        XCTAssertFalse(log.enthaeltPraefix("loeschen:"))
    }
}
