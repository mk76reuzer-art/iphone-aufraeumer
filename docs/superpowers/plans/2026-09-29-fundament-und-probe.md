# Fundament und Probe — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein öffentliches Repo mit einer getesteten Sicherheits-Kernlogik (`AufraeumerKern`), einer automatischen Mac-Server-Pipeline, die eine installierbare `.ipa` baut, und einer Probe-App, die auf dem echten iPhone die zwei offenen Fragen beantwortet (Upload-Nachweis für iCloud Drive, PhotoKit-Sicht auf ausgeblendete Videos).

**Architecture:** Die Logik (Regeln, Duplikate, Zustandsautomat, Protokoll, Löschlauf) steckt in einem reinen Swift-Paket ohne PhotoKit und wird auf dem GitHub-macOS-Server per `swift test` geprüft. Die App (SwiftUI) liegt daneben und wird mit XcodeGen aus `project.yml` erzeugt. Windows baut nichts selbst: alle Builds laufen auf GitHub.

**Tech Stack:** Swift 5.9 (Paket-Tools 5.9), SwiftUI, PhotoKit, CryptoKit, XCTest, XcodeGen, GitHub Actions (`macos-latest`), `gh`, Sideloadly.

**Spec:** `docs/superpowers/specs/2026-09-29-iphone-aufraeumer-design.md`

## Global Constraints

- iOS-Mindestversion **17.0**; Paket-Plattformen `.iOS(.v17)` und `.macOS(.v13)`, `swift-tools-version:5.9`.
- Alle Texte in der App und in `ANLEITUNG.md` auf **Deutsch**.
- **Keine Netzwerkzugriffe, keine Fremdbibliotheken** (nur Apple-Frameworks: Foundation, SwiftUI, Photos, CryptoKit, UniformTypeIdentifiers).
- Repo ist **öffentlich**: keine persönlichen Daten, keine echten Dateinamen, keine Konto-, Mail- oder Schlüsselangaben, keine Fotos/Videos. Testdaten nur neutral (`IMG_A`, `IMG_B` …).
- Sicherheitsregeln 1–7 aus Abschnitt 5 der Spec sind unverrückbar: Löschen nur nach Auswahl und Bestätigung; bei Zweifel nie löschen; nie das letzte Exemplar einer Duplikatgruppe ohne Sicherung; „beabsichtigt“ im Protokoll vor dem Löschaufruf.
- Commits nur auf Zweig `entwicklung`; jede Commit-Nachricht endet mit der Zeile `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Keine schwere Last auf dem PC des Nutzers: es wird nichts lokal kompiliert (kein Swift auf Windows), Builds laufen auf GitHub; auf dem PC werden keine Cloud-Programme gestartet.
- Ein CI-Lauf dauert einige Minuten. Deshalb gilt je Aufgabe: Test **und** Umsetzung in einem Push, danach muss der Lauf grün sein. Bei Rot: Fehlermeldung lesen, beheben, erneut pushen.

## Review Focus

1. Datei mit unbekannter Größe (0) oder nur in iCloud vorhanden → wird nie angeboten und nie gelöscht (Task 2).
2. Zwei gleich große, aber verschiedene Dateien → **kein** Duplikat; zwei byte-gleiche Dateien mit unterschiedlicher gespeicherter Dauer → **doch** Duplikat (Task 3; an echten Daten beobachtet).
3. Nutzer wählt alle Exemplare einer Duplikatgruppe ohne Sicherung → das zu behaltende Exemplar bleibt (Task 6).
4. Upload wird nie fertig oder überschreitet die Wartezeit → nichts wird gelöscht (Task 6).
5. Dateinamen mit Semikolon, Anführungszeichen, Zeilenumbruch (auch `\r\n`), Umlauten und Emoji → Protokoll-CSV bleibt lesbar (Task 4).
6. Dieselbe Datei zweimal ausgewählt → wird nur einmal verarbeitet; iOS-Löschabfrage vom Nutzer abgelehnt → Protokoll zeigt „beabsichtigt“, dann „abgebrochen“, nichts gilt als gelöscht (Task 6).

---

## Datei-Übersicht

| Datei | Aufgabe |
|---|---|
| `Package.swift` | Paket `AufraeumerKern` mit Testziel |
| `Sources/AufraeumerKern/Version.swift` | Versionskonstante (Rauchtest) |
| `Sources/AufraeumerKern/Modell.swift` | `Kategorie`, `Modus`, `Kandidat` |
| `Sources/AufraeumerKern/Regeln.swift` | `Schwellen`, `Regeln` (Kategorien, Modus) |
| `Sources/AufraeumerKern/DuplikatFinder.swift` | `DuplikatGruppe`, `DuplikatFinder` |
| `Sources/AufraeumerKern/Protokoll.swift` | `Aktion`, `ProtokollEintrag`, `Protokoll` (JSON, CSV) |
| `Sources/AufraeumerKern/DateiAblauf.swift` | Zustandsautomat je Datei |
| `Sources/AufraeumerKern/Schnittstellen.swift` | `MedienBibliothek`, `Sicherung`, `Export`, `SicherungsBeleg`, `KopieInfo` |
| `Sources/AufraeumerKern/Loeschlauf.swift` | Ablaufsteuerung (sichern, prüfen, löschen, protokollieren) |
| `Tests/AufraeumerKernTests/*` | Tests je Baustein plus `TestHilfen.swift`, `Fakes.swift` |
| `project.yml` | XcodeGen-Beschreibung der App |
| `App/*` | Probe-App (SwiftUI) |
| `.github/workflows/ios.yml` | Tests, Build, `.ipa`-Artefakt |
| `README.md`, `ANLEITUNG.md` | Kurzbeschreibung und Installationsanleitung |

---

### Task 1: Gerüst, öffentliches Repo und CI-Tests

**Files:**
- Create: `Package.swift`, `Sources/AufraeumerKern/Version.swift`, `Tests/AufraeumerKernTests/VersionTests.swift`, `.gitignore`, `README.md`, `.github/workflows/ios.yml`
- Modify: `docs/superpowers/specs/2026-09-29-iphone-aufraeumer-design.md` (Personenbezug entfernen)

**Interfaces:**
- Produces: `Kern.version: String` (`"0.1.0"`); Paketziel `AufraeumerKern`; Testziel `AufraeumerKernTests`.

- [ ] **Step 1: Persönliche Angaben aus der Spec entfernen und den lokalen Commit neu schreiben**

Der lokale Commit `621cb80` trägt eine private Mail-Adresse im Autorenfeld; das Repo wird öffentlich. Zuerst die GitHub-Adresse ohne Klartext-Mail holen und als Autor setzen:

```bash
cd /c/iphone-aufraeumer
GH="/c/Program Files/GitHub CLI/gh.exe"
ID=$("$GH" api user --jq .id)
git config user.name "mk76reuzer-art"
git config user.email "${ID}+mk76reuzer-art@users.noreply.github.com"
git config user.email
```

Die Spec ist bereits von Namen und persönlichen Angaben bereinigt (Status „freigegeben zur Umsetzung“, Duplikate nur nach Größe und Prüfsumme). Prüfen, dass in `docs/` nichts Persönliches übrig ist (Vorname als Wort, Mail-Anbieter):

Run: `grep -rn -i -w "m[a]nu" docs/ ; grep -rn -i "g[m]ail\|h[o]tmail" docs/`
Expected: keine Ausgabe.

- [ ] **Step 2: Gerüstdateien anlegen**

`Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AufraeumerKern",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "AufraeumerKern", targets: ["AufraeumerKern"])
    ],
    targets: [
        .target(name: "AufraeumerKern"),
        .testTarget(name: "AufraeumerKernTests", dependencies: ["AufraeumerKern"])
    ]
)
```

`Sources/AufraeumerKern/Version.swift`:

```swift
public enum Kern {
    public static let version = "0.1.0"
}
```

`Tests/AufraeumerKernTests/VersionTests.swift`:

```swift
import XCTest
@testable import AufraeumerKern

final class VersionTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(Kern.version, "0.1.0")
    }
}
```

`.gitignore`:

```
.build/
.swiftpm/
*.xcodeproj/
App/Info.plist
out/
*.ipa
*.xcarchive
DerivedData/
.DS_Store
```

`README.md`:

```markdown
# iPhone-Aufräumer

Eine iPhone-App, die große und überflüssige Fotos und Videos findet, sie zuerst nach iCloud Drive
sichert und erst nach geprüfter Sicherung und ausdrücklicher Bestätigung löscht.

Status: in Entwicklung. Entwurf: `docs/superpowers/specs/`. Plan: `docs/superpowers/plans/`.

Gebaut wird auf GitHub (macOS-Server), installiert wird mit Sideloadly. Siehe `ANLEITUNG.md`.
```

`.github/workflows/ios.yml`:

```yaml
name: ios
on:
  push:
    branches: [entwicklung, main]
  workflow_dispatch:

jobs:
  kern-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Versionen
        run: xcodebuild -version && swift --version
      - name: Tests
        run: swift test
```

- [ ] **Step 3: Commit (alten Commit ersetzen, weil noch nichts veröffentlicht ist)**

```bash
git add -A
git commit --amend --reset-author -q -m "Entwurf, Plan und Gerüst: iPhone-Aufräumer" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git log --format='%h %an <%ae> %s' -1
```

Expected: Autor `mk76reuzer-art <…@users.noreply.github.com>`, keine private Mail-Adresse.

- [ ] **Step 4: Öffentliches Repo anlegen und pushen**

```bash
"$GH" repo create mk76reuzer-art/iphone-aufraeumer --public --source . --remote origin --description "iPhone-Aufräumer: große und überflüssige Fotos und Videos sicher sichern und löschen"
git push -u origin entwicklung
```

Expected: Repo angelegt, Zweig `entwicklung` hochgeladen.

- [ ] **Step 5: CI-Lauf beobachten**

```bash
"$GH" run list --branch entwicklung --limit 1 --json databaseId,status,conclusion
"$GH" run watch <ID> --exit-status
```

Expected: Lauf `kern-tests` erfolgreich; im Protokoll steht die Xcode-Version. Bei Rot: `"$GH" run view <ID> --log-failed` lesen und beheben.

---

### Task 2: Modell und Regeln

**Files:**
- Create: `Sources/AufraeumerKern/Modell.swift`, `Sources/AufraeumerKern/Regeln.swift`, `Tests/AufraeumerKernTests/TestHilfen.swift`, `Tests/AufraeumerKernTests/RegelnTests.swift`

**Interfaces:**
- Consumes: nichts.
- Produces:
  - `enum Kategorie: String, Codable, CaseIterable, Sendable { case grosseVideos, langeUnberuehrt, duplikate, alteScreenshots; var sichernNoetig: Bool }`
  - `enum Modus: Equatable, Sendable { case nurLoeschen, erstSichern }`
  - `struct Kandidat: Equatable, Codable, Sendable, Identifiable` mit `init(id:name:groesseBytes:aufnahme:dauerSekunden:istVideo:istScreenshot:istFavorit:istBearbeitet:inAlbum:istAusgeblendet:istLokalVorhanden:)`
  - `struct Schwellen: Equatable, Sendable { var grosseVideoBytes: Int64; var unberuehrtJahre: Int; var screenshotTage: Int }`
  - `Regeln.kategorien(fuer:jetzt:schwellen:kalender:) -> Set<Kategorie>`, `Regeln.modus(fuer:) -> Modus`

- [ ] **Step 1: Testhilfen und Tests schreiben**

`Tests/AufraeumerKernTests/TestHilfen.swift`:

```swift
import Foundation
@testable import AufraeumerKern

enum FehlerT: Error { case boom }

enum T {
    static var kal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    /// 2026-09-21T14:13:20Z
    static let jetzt = Date(timeIntervalSince1970: 1_790_000_000)
    static func tageher(_ n: Int) -> Date { kal.date(byAdding: .day, value: -n, to: jetzt)! }
    static func jahreher(_ n: Int) -> Date { kal.date(byAdding: .year, value: -n, to: jetzt)! }

    static func k(_ id: String = "A", groesse: Int64 = 1_000, aufnahme: Date? = nil,
                  video: Bool = false, screenshot: Bool = false, favorit: Bool = false,
                  bearbeitet: Bool = false, album: Bool = false, ausgeblendet: Bool = false,
                  lokal: Bool = true, dauer: Double? = nil, name: String? = nil) -> Kandidat {
        Kandidat(id: id, name: name ?? "IMG_\(id).MP4", groesseBytes: groesse,
                 aufnahme: aufnahme ?? tageher(1), dauerSekunden: dauer, istVideo: video,
                 istScreenshot: screenshot, istFavorit: favorit, istBearbeitet: bearbeitet,
                 inAlbum: album, istAusgeblendet: ausgeblendet, istLokalVorhanden: lokal)
    }
}
```

`Tests/AufraeumerKernTests/RegelnTests.swift`:

```swift
import XCTest
@testable import AufraeumerKern

final class RegelnTests: XCTestCase {
    private func kat(_ k: Kandidat, _ s: Schwellen = Schwellen()) -> Set<Kategorie> {
        Regeln.kategorien(fuer: k, jetzt: T.jetzt, schwellen: s, kalender: T.kal)
    }

    func testGrossesVideoAbSchwelle() {
        XCTAssertEqual(kat(T.k("A", groesse: 60_000_000, video: true)), [.grosseVideos])
        XCTAssertEqual(kat(T.k("B", groesse: 50_000_000, video: true)), [.grosseVideos])
        XCTAssertTrue(kat(T.k("C", groesse: 49_999_999, video: true)).isEmpty)
    }

    func testFotoIstNieGrossesVideo() {
        XCTAssertTrue(kat(T.k("A", groesse: 900_000_000, video: false)).isEmpty)
    }

    func testUnbekannteGroesseOderNurCloudWirdNieAngeboten() {
        XCTAssertTrue(kat(T.k("A", groesse: 0, aufnahme: T.jahreher(5), video: true)).isEmpty)
        XCTAssertTrue(kat(T.k("B", groesse: 900_000_000, aufnahme: T.jahreher(5), video: true, lokal: false)).isEmpty)
    }

    func testScreenshotErstNachNeunzigTagen() {
        XCTAssertEqual(kat(T.k("A", aufnahme: T.tageher(91), screenshot: true)), [.alteScreenshots])
        XCTAssertTrue(kat(T.k("B", aufnahme: T.tageher(90), screenshot: true)).isEmpty)
        XCTAssertTrue(kat(T.k("C", aufnahme: T.tageher(89), screenshot: true)).isEmpty)
    }

    func testLangeUnberuehrtBrauchtAlleBedingungen() {
        XCTAssertEqual(kat(T.k("A", aufnahme: T.jahreher(3))), [.langeUnberuehrt])
        XCTAssertTrue(kat(T.k("B", aufnahme: T.jahreher(1))).isEmpty)
        XCTAssertTrue(kat(T.k("C", aufnahme: T.jahreher(3), favorit: true)).isEmpty)
        XCTAssertTrue(kat(T.k("D", aufnahme: T.jahreher(3), bearbeitet: true)).isEmpty)
        XCTAssertTrue(kat(T.k("E", aufnahme: T.jahreher(3), album: true)).isEmpty)
    }

    func testMehrereKategorienUndModus() {
        let k = kat(T.k("A", groesse: 60_000_000, aufnahme: T.jahreher(3), video: true))
        XCTAssertEqual(k, [.grosseVideos, .langeUnberuehrt])
        XCTAssertEqual(Regeln.modus(fuer: k), .erstSichern)
        XCTAssertEqual(Regeln.modus(fuer: [.alteScreenshots]), .nurLoeschen)
        XCTAssertEqual(Regeln.modus(fuer: [.duplikate]), .nurLoeschen)
        XCTAssertEqual(Regeln.modus(fuer: [.alteScreenshots, .langeUnberuehrt]), .erstSichern)
        XCTAssertEqual(Regeln.modus(fuer: []), .erstSichern)
    }

    func testEigeneSchwellen() {
        var s = Schwellen()
        s.grosseVideoBytes = 10
        XCTAssertEqual(kat(T.k("A", groesse: 10, video: true), s), [.grosseVideos])
    }

    func testSichernNoetigJeKategorie() {
        XCTAssertTrue(Kategorie.grosseVideos.sichernNoetig)
        XCTAssertTrue(Kategorie.langeUnberuehrt.sichernNoetig)
        XCTAssertFalse(Kategorie.duplikate.sichernNoetig)
        XCTAssertFalse(Kategorie.alteScreenshots.sichernNoetig)
    }
}
```

- [ ] **Step 2: Umsetzung schreiben**

`Sources/AufraeumerKern/Modell.swift`:

```swift
import Foundation

public enum Kategorie: String, Codable, CaseIterable, Sendable {
    case grosseVideos, langeUnberuehrt, duplikate, alteScreenshots

    /// Kategorien, deren Dateien vor dem Löschen zuerst gesichert werden müssen.
    public var sichernNoetig: Bool {
        self == .grosseVideos || self == .langeUnberuehrt
    }
}

public enum Modus: Equatable, Sendable {
    case nurLoeschen
    case erstSichern
}

public struct Kandidat: Equatable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    /// Lokal belegte Größe in Bytes; 0 bedeutet unbekannt.
    public let groesseBytes: Int64
    public let aufnahme: Date
    public let dauerSekunden: Double?
    public let istVideo: Bool
    public let istScreenshot: Bool
    public let istFavorit: Bool
    public let istBearbeitet: Bool
    public let inAlbum: Bool
    public let istAusgeblendet: Bool
    public let istLokalVorhanden: Bool

    public init(id: String, name: String, groesseBytes: Int64, aufnahme: Date,
                dauerSekunden: Double?, istVideo: Bool, istScreenshot: Bool,
                istFavorit: Bool, istBearbeitet: Bool, inAlbum: Bool,
                istAusgeblendet: Bool, istLokalVorhanden: Bool) {
        self.id = id
        self.name = name
        self.groesseBytes = groesseBytes
        self.aufnahme = aufnahme
        self.dauerSekunden = dauerSekunden
        self.istVideo = istVideo
        self.istScreenshot = istScreenshot
        self.istFavorit = istFavorit
        self.istBearbeitet = istBearbeitet
        self.inAlbum = inAlbum
        self.istAusgeblendet = istAusgeblendet
        self.istLokalVorhanden = istLokalVorhanden
    }
}
```

`Sources/AufraeumerKern/Regeln.swift`:

```swift
import Foundation

public struct Schwellen: Equatable, Sendable {
    public var grosseVideoBytes: Int64 = 50_000_000
    public var unberuehrtJahre: Int = 2
    public var screenshotTage: Int = 90
    public init() {}
}

public enum Regeln {
    /// Ordnet einen Kandidaten den Kategorien zu. `.duplikate` entscheidet der `DuplikatFinder`.
    public static func kategorien(fuer k: Kandidat, jetzt: Date,
                                  schwellen: Schwellen = Schwellen(),
                                  kalender: Calendar = .current) -> Set<Kategorie> {
        guard k.istLokalVorhanden, k.groesseBytes > 0 else { return [] }
        var ergebnis = Set<Kategorie>()

        if k.istVideo && k.groesseBytes >= schwellen.grosseVideoBytes {
            ergebnis.insert(.grosseVideos)
        }
        if k.istScreenshot,
           let grenze = kalender.date(byAdding: .day, value: -schwellen.screenshotTage, to: jetzt),
           k.aufnahme < grenze {
            ergebnis.insert(.alteScreenshots)
        }
        if !k.istFavorit, !k.istBearbeitet, !k.inAlbum,
           let grenze = kalender.date(byAdding: .year, value: -schwellen.unberuehrtJahre, to: jetzt),
           k.aufnahme < grenze {
            ergebnis.insert(.langeUnberuehrt)
        }
        return ergebnis
    }

    /// Im Zweifel wird gesichert: sobald eine Kategorie Sicherung verlangt (oder keine bekannt ist).
    public static func modus(fuer kategorien: Set<Kategorie>) -> Modus {
        if kategorien.isEmpty || kategorien.contains(where: { $0.sichernNoetig }) {
            return .erstSichern
        }
        return .nurLoeschen
    }
}
```

- [ ] **Step 3: Commit, pushen, CI grün abwarten**

```bash
git add -A
git commit -q -m "Modell und Regeln mit Tests" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git push
"$GH" run list --branch entwicklung --limit 1 --json databaseId,status,conclusion
"$GH" run watch <ID> --exit-status
```

Expected: Lauf grün, alle `RegelnTests` bestanden. Bei Rot: `"$GH" run view <ID> --log-failed`, beheben, erneut pushen.

---

### Task 3: Duplikate finden

**Files:**
- Create: `Sources/AufraeumerKern/DuplikatFinder.swift`, `Tests/AufraeumerKernTests/DuplikatFinderTests.swift`

**Interfaces:**
- Consumes: `Kandidat` (Task 2).
- Produces: `struct DuplikatGruppe: Equatable, Sendable { let behalten: String; let loeschbar: [String]; var alleIds: [String]; init(behalten:loeschbar:) }` und `DuplikatFinder.gruppen(aus: [Kandidat], pruefsumme: (String) throws -> String) rethrows -> [DuplikatGruppe]`.

- [ ] **Step 1: Tests schreiben**

`Tests/AufraeumerKernTests/DuplikatFinderTests.swift`:

```swift
import XCTest
@testable import AufraeumerKern

final class DuplikatFinderTests: XCTestCase {
    private func summen(_ m: [String: String]) -> (String) throws -> String {
        { id in m[id] ?? "einzigartig-\(id)" }
    }

    func testGleicheGroesseUndSummeBildenGruppeAeltestesBleibt() throws {
        let a = T.k("A", groesse: 500, aufnahme: T.tageher(10), video: true)
        let b = T.k("B", groesse: 500, aufnahme: T.tageher(5), video: true)
        let g = try DuplikatFinder.gruppen(aus: [b, a], pruefsumme: summen(["A": "x", "B": "x"]))
        XCTAssertEqual(g, [DuplikatGruppe(behalten: "A", loeschbar: ["B"])])
        XCTAssertEqual(g[0].alleIds, ["A", "B"])
    }

    func testGleicheGroesseAberAndereSummeIstKeinDuplikat() throws {
        let a = T.k("A", groesse: 500)
        let b = T.k("B", groesse: 500)
        let g = try DuplikatFinder.gruppen(aus: [a, b], pruefsumme: summen(["A": "x", "B": "y"]))
        XCTAssertTrue(g.isEmpty)
    }

    func testUnterschiedlicheGespeicherteDauerStehtDerErkennungNichtImWeg() throws {
        // An echten Daten beobachtet: byte-gleiche Dateien, aber verschiedene gespeicherte Dauer.
        let a = T.k("A", groesse: 800_000, aufnahme: T.tageher(9), video: true, dauer: 3234.2)
        let b = T.k("B", groesse: 800_000, aufnahme: T.tageher(9), video: true, dauer: 222.4)
        let g = try DuplikatFinder.gruppen(aus: [a, b], pruefsumme: summen(["A": "x", "B": "x"]))
        XCTAssertEqual(g.count, 1)
    }

    func testFavoritWirdBehaltenAuchWennJuenger() throws {
        let a = T.k("A", groesse: 500, aufnahme: T.tageher(10))
        let b = T.k("B", groesse: 500, aufnahme: T.tageher(1), favorit: true)
        let g = try DuplikatFinder.gruppen(aus: [a, b], pruefsumme: summen(["A": "x", "B": "x"]))
        XCTAssertEqual(g, [DuplikatGruppe(behalten: "B", loeschbar: ["A"])])
    }

    func testDreiKopienErgebenEineGruppe() throws {
        let ks = ["C", "A", "B"].enumerated().map { i, id in T.k(id, groesse: 500, aufnahme: T.tageher(10 - i)) }
        let g = try DuplikatFinder.gruppen(aus: ks, pruefsumme: summen(["A": "x", "B": "x", "C": "x"]))
        XCTAssertEqual(g.count, 1)
        XCTAssertEqual(g[0].alleIds.count, 3)
        XCTAssertEqual(g[0].loeschbar.count, 2)
        XCTAssertFalse(g[0].loeschbar.contains(g[0].behalten))
    }

    func testUngueltigeWerdenIgnoriert() throws {
        let a = T.k("A", groesse: 0)
        let b = T.k("B", groesse: 0)
        let c = T.k("C", groesse: 500, lokal: false)
        let d = T.k("D", groesse: 500, lokal: false)
        let g = try DuplikatFinder.gruppen(aus: [a, b, c, d], pruefsumme: { _ in "x" })
        XCTAssertTrue(g.isEmpty)
    }

    func testPruefsummeNurFuerGleichGrosse() throws {
        var aufrufe = 0
        let ks = [T.k("A", groesse: 1), T.k("B", groesse: 2), T.k("C", groesse: 3)]
        _ = try DuplikatFinder.gruppen(aus: ks, pruefsumme: { id in aufrufe += 1; return id })
        XCTAssertEqual(aufrufe, 0)
    }

    func testFehlerBeimBildenDerPruefsummeWirdWeitergegeben() {
        let ks = [T.k("A", groesse: 5), T.k("B", groesse: 5)]
        XCTAssertThrowsError(try DuplikatFinder.gruppen(aus: ks, pruefsumme: { _ in throw FehlerT.boom }))
    }
}
```

- [ ] **Step 2: Umsetzung schreiben**

`Sources/AufraeumerKern/DuplikatFinder.swift`:

```swift
import Foundation

public struct DuplikatGruppe: Equatable, Sendable {
    /// Dieses Exemplar bleibt erhalten.
    public let behalten: String
    public let loeschbar: [String]
    public var alleIds: [String] { [behalten] + loeschbar }

    public init(behalten: String, loeschbar: [String]) {
        self.behalten = behalten
        self.loeschbar = loeschbar
    }
}

public enum DuplikatFinder {
    /// Gruppiert zuerst nach Größe (billig), bildet nur für gleich große Dateien die Prüfsumme
    /// und fasst Dateien mit gleicher Prüfsumme zusammen. Die gespeicherte Dauer wird nicht verglichen.
    public static func gruppen(aus kandidaten: [Kandidat],
                               pruefsumme: (String) throws -> String) rethrows -> [DuplikatGruppe] {
        let tauglich = kandidaten.filter { $0.istLokalVorhanden && $0.groesseBytes > 0 }
        let nachGroesse = Dictionary(grouping: tauglich, by: { $0.groesseBytes })
        var ergebnis: [DuplikatGruppe] = []

        for (_, gleichGross) in nachGroesse where gleichGross.count >= 2 {
            var nachSumme: [String: [Kandidat]] = [:]
            for k in gleichGross {
                let summe = try pruefsumme(k.id)
                nachSumme[summe, default: []].append(k)
            }
            for (_, gleich) in nachSumme where gleich.count >= 2 {
                let sortiert = gleich.sorted { a, b in
                    if a.istFavorit != b.istFavorit { return a.istFavorit }
                    if a.aufnahme != b.aufnahme { return a.aufnahme < b.aufnahme }
                    return a.id < b.id
                }
                ergebnis.append(DuplikatGruppe(
                    behalten: sortiert[0].id,
                    loeschbar: sortiert.dropFirst().map(\.id).sorted()))
            }
        }
        return ergebnis.sorted { $0.behalten < $1.behalten }
    }
}
```

- [ ] **Step 3: Commit, pushen, CI grün abwarten**

```bash
git add -A
git commit -q -m "Duplikate: Gruppen nach Größe und Prüfsumme, immer ein Exemplar behalten" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git push
"$GH" run list --branch entwicklung --limit 1 --json databaseId,status,conclusion
"$GH" run watch <ID> --exit-status
```

Expected: Lauf grün.

---

### Task 4: Protokoll (JSON und CSV)

**Files:**
- Create: `Sources/AufraeumerKern/Protokoll.swift`, `Tests/AufraeumerKernTests/ProtokollTests.swift`

**Interfaces:**
- Produces:
  - `enum Aktion: String, Codable, Sendable { case beabsichtigt, geloescht, abgebrochen, gesichert }`
  - `struct ProtokollEintrag: Codable, Equatable, Sendable { zeit: Date; id: String; name: String; groesseBytes: Int64; aktion: Aktion; grund: String?; init(zeit:id:name:groesseBytes:aktion:grund:) }`
  - `struct Protokoll: Codable, Equatable, Sendable { init(); private(set) var eintraege: [ProtokollEintrag]; mutating func hinzufuegen(_:); func json() throws -> Data; static func aus(json: Data) throws -> Protokoll; func csv() -> String }`

- [ ] **Step 1: Tests schreiben**

`Tests/AufraeumerKernTests/ProtokollTests.swift`:

```swift
import XCTest
@testable import AufraeumerKern

final class ProtokollTests: XCTestCase {
    private let t = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21T14:13:20Z

    private func e(_ name: String, _ a: Aktion = .geloescht, grund: String? = nil) -> ProtokollEintrag {
        ProtokollEintrag(zeit: t, id: "id1", name: name, groesseBytes: 123, aktion: a, grund: grund)
    }

    func testLeeresProtokollHatNurKopfzeile() {
        XCTAssertEqual(Protokoll().csv(), "Zeit;ID;Name;Groesse_Bytes;Aktion;Grund")
    }

    func testEinfacheZeile() {
        var p = Protokoll()
        p.hinzufuegen(e("IMG_A.MP4"))
        let zeilen = p.csv().components(separatedBy: "\n")
        XCTAssertEqual(zeilen.count, 2)
        XCTAssertEqual(zeilen[1], "2026-09-21T14:13:20Z;id1;IMG_A.MP4;123;geloescht;")
    }

    func testSonderzeichenWerdenMaskiert() {
        var p = Protokoll()
        p.hinzufuegen(e("Urlaub; \"Sommer\"\nTeil 2 äöü 🎬.MP4", .abgebrochen, grund: "Zeile1\r\nZeile2"))
        let csv = p.csv()
        XCTAssertTrue(csv.contains("\"Urlaub; \"\"Sommer\"\"\nTeil 2 äöü 🎬.MP4\""))
        XCTAssertTrue(csv.contains("\"Zeile1\r\nZeile2\""))
    }

    func testUmlauteUndEmojiOhneSonderzeichenBleibenUnmaskiert() {
        var p = Protokoll()
        p.hinzufuegen(e("Größe äöü 🎬.MP4"))
        XCTAssertTrue(p.csv().contains(";Größe äöü 🎬.MP4;"))
    }

    func testJsonRundreiseErhaeltReihenfolgeUndWerte() throws {
        var p = Protokoll()
        p.hinzufuegen(e("A.MP4", .beabsichtigt))
        p.hinzufuegen(e("B.MP4", .abgebrochen, grund: "Upload nicht rechtzeitig fertig"))
        let q = try Protokoll.aus(json: try p.json())
        XCTAssertEqual(p, q)
        XCTAssertEqual(q.eintraege.map(\.name), ["A.MP4", "B.MP4"])
        XCTAssertNil(q.eintraege[0].grund)
    }
}
```

- [ ] **Step 2: Umsetzung schreiben**

`Sources/AufraeumerKern/Protokoll.swift`:

```swift
import Foundation

public enum Aktion: String, Codable, Sendable {
    case beabsichtigt, geloescht, abgebrochen, gesichert
}

public struct ProtokollEintrag: Codable, Equatable, Sendable {
    public let zeit: Date
    public let id: String
    public let name: String
    public let groesseBytes: Int64
    public let aktion: Aktion
    public let grund: String?

    public init(zeit: Date, id: String, name: String, groesseBytes: Int64,
                aktion: Aktion, grund: String?) {
        self.zeit = zeit
        self.id = id
        self.name = name
        self.groesseBytes = groesseBytes
        self.aktion = aktion
        self.grund = grund
    }
}

public struct Protokoll: Codable, Equatable, Sendable {
    public private(set) var eintraege: [ProtokollEintrag] = []

    public init() {}

    public mutating func hinzufuegen(_ eintrag: ProtokollEintrag) {
        eintraege.append(eintrag)
    }

    public func json() throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    public static func aus(json: Data) throws -> Protokoll {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(Protokoll.self, from: json)
    }

    public func csv() -> String {
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime]
        var zeilen = ["Zeit;ID;Name;Groesse_Bytes;Aktion;Grund"]
        for e in eintraege {
            let felder = [format.string(from: e.zeit), e.id, e.name, String(e.groesseBytes),
                          e.aktion.rawValue, e.grund ?? ""]
            zeilen.append(felder.map(Protokoll.feld).joined(separator: ";"))
        }
        return zeilen.joined(separator: "\n")
    }

    /// Hinweis: `\r\n` ist in Swift ein einzelnes Zeichen, deshalb wird über Unicode-Skalare geprüft.
    static func feld(_ s: String) -> String {
        let braucht = s.unicodeScalars.contains { $0 == ";" || $0 == "\"" || $0 == "\n" || $0 == "\r" }
        guard braucht else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
```

- [ ] **Step 3: Commit, pushen, CI grün abwarten**

```bash
git add -A
git commit -q -m "Protokoll mit JSON- und CSV-Ausgabe, sichere Maskierung" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git push
"$GH" run list --branch entwicklung --limit 1 --json databaseId,status,conclusion
"$GH" run watch <ID> --exit-status
```

Expected: Lauf grün.

---

### Task 5: Zustandsautomat je Datei

**Files:**
- Create: `Sources/AufraeumerKern/DateiAblauf.swift`, `Tests/AufraeumerKernTests/DateiAblaufTests.swift`

**Interfaces:**
- Consumes: `Kandidat`, `Modus` (Task 2).
- Produces:
  - `enum Zustand: Equatable, Sendable { case gefunden, ausgewaehlt, kopiert, geprueft, hochgeladen, freigegeben, geloescht, abgebrochen(String) }`
  - `enum AblaufFehler: Error, Equatable { case unerlaubterUebergang(von: String, nach: String), groesseUngleich, pruefsummeUngleich, favoritOhneBestaetigung }`
  - `struct DateiAblauf: Sendable { init(kandidat: Kandidat, modus: Modus); let kandidat: Kandidat; let modus: Modus; private(set) var zustand: Zustand; var loeschenErlaubt: Bool; var istEnde: Bool; mutating func auswaehlen() throws; mutating func kopiert(bytes: Int64, pruefsumme: String) throws; mutating func pruefen(originalBytes: Int64, originalPruefsumme: String) throws; mutating func hochgeladen() throws; mutating func freigeben(favoritBestaetigt: Bool) throws; mutating func geloescht() throws; mutating func abbrechen(grund: String) throws }`

- [ ] **Step 1: Tests schreiben**

`Tests/AufraeumerKernTests/DateiAblaufTests.swift`:

```swift
import XCTest
@testable import AufraeumerKern

final class DateiAblaufTests: XCTestCase {
    private func sichern(favorit: Bool = false) -> DateiAblauf {
        DateiAblauf(kandidat: T.k("A", video: true, favorit: favorit), modus: .erstSichern)
    }

    func testVollerWegMitSicherungErlaubtLoeschenErstAmEnde() throws {
        var a = sichern()
        XCTAssertFalse(a.loeschenErlaubt)
        try a.auswaehlen()
        try a.kopiert(bytes: 1000, pruefsumme: "s")
        XCTAssertFalse(a.loeschenErlaubt)
        try a.pruefen(originalBytes: 1000, originalPruefsumme: "s")
        XCTAssertEqual(a.zustand, .geprueft)
        XCTAssertFalse(a.loeschenErlaubt)
        try a.hochgeladen()
        XCTAssertFalse(a.loeschenErlaubt)
        try a.freigeben(favoritBestaetigt: false)
        XCTAssertTrue(a.loeschenErlaubt)
        try a.geloescht()
        XCTAssertEqual(a.zustand, .geloescht)
        XCTAssertTrue(a.istEnde)
    }

    func testNurLoeschenBrauchtKeineSicherungsstufen() throws {
        var a = DateiAblauf(kandidat: T.k("A", screenshot: true), modus: .nurLoeschen)
        try a.auswaehlen()
        try a.freigeben(favoritBestaetigt: false)
        XCTAssertTrue(a.loeschenErlaubt)
        try a.geloescht()
    }

    func testStufenKoennenNichtUebersprungenWerden() throws {
        var a = sichern()
        XCTAssertThrowsError(try a.freigeben(favoritBestaetigt: false))
        try a.auswaehlen()
        XCTAssertThrowsError(try a.freigeben(favoritBestaetigt: false))
        XCTAssertThrowsError(try a.hochgeladen())
        XCTAssertThrowsError(try a.geloescht())
        XCTAssertFalse(a.loeschenErlaubt)
    }

    func testNurLoeschenDarfNichtKopieren() throws {
        var a = DateiAblauf(kandidat: T.k("A"), modus: .nurLoeschen)
        try a.auswaehlen()
        XCTAssertThrowsError(try a.kopiert(bytes: 1, pruefsumme: "s"))
    }

    func testFalschePruefsummeBrichtAbUndSperrtLoeschen() throws {
        var a = sichern()
        try a.auswaehlen()
        try a.kopiert(bytes: 1000, pruefsumme: "kopie")
        XCTAssertThrowsError(try a.pruefen(originalBytes: 1000, originalPruefsumme: "original")) {
            XCTAssertEqual($0 as? AblaufFehler, .pruefsummeUngleich)
        }
        if case .abgebrochen = a.zustand {} else { XCTFail("Zustand sollte abgebrochen sein") }
        XCTAssertFalse(a.loeschenErlaubt)
        XCTAssertThrowsError(try a.hochgeladen())
        XCTAssertThrowsError(try a.freigeben(favoritBestaetigt: true))
    }

    func testFalscheGroesseBrichtAb() throws {
        var a = sichern()
        try a.auswaehlen()
        try a.kopiert(bytes: 999, pruefsumme: "s")
        XCTAssertThrowsError(try a.pruefen(originalBytes: 1000, originalPruefsumme: "s")) {
            XCTAssertEqual($0 as? AblaufFehler, .groesseUngleich)
        }
        XCTAssertFalse(a.loeschenErlaubt)
    }

    func testFavoritBrauchtAusdruecklicheBestaetigung() throws {
        var a = sichern(favorit: true)
        try a.auswaehlen()
        try a.kopiert(bytes: 1000, pruefsumme: "s")
        try a.pruefen(originalBytes: 1000, originalPruefsumme: "s")
        try a.hochgeladen()
        XCTAssertThrowsError(try a.freigeben(favoritBestaetigt: false)) {
            XCTAssertEqual($0 as? AblaufFehler, .favoritOhneBestaetigung)
        }
        XCTAssertFalse(a.loeschenErlaubt)
        XCTAssertEqual(a.zustand, .hochgeladen)
        try a.freigeben(favoritBestaetigt: true)
        XCTAssertTrue(a.loeschenErlaubt)
    }

    func testAbbrechenSperrtAlleWeiterenSchritteAberNichtNachDemLoeschen() throws {
        var a = sichern()
        try a.auswaehlen()
        try a.abbrechen(grund: "Nutzer hat es sich anders überlegt")
        XCTAssertEqual(a.zustand, .abgebrochen("Nutzer hat es sich anders überlegt"))
        XCTAssertThrowsError(try a.kopiert(bytes: 1, pruefsumme: "s"))
        XCTAssertThrowsError(try a.abbrechen(grund: "nochmal"))

        var b = DateiAblauf(kandidat: T.k("B"), modus: .nurLoeschen)
        try b.auswaehlen()
        try b.freigeben(favoritBestaetigt: false)
        try b.geloescht()
        XCTAssertThrowsError(try b.abbrechen(grund: "zu spät"))
        XCTAssertEqual(b.zustand, .geloescht)
    }

    func testGeloeschtNurAusFreigegeben() throws {
        var a = DateiAblauf(kandidat: T.k("A"), modus: .nurLoeschen)
        XCTAssertThrowsError(try a.geloescht())
        try a.auswaehlen()
        XCTAssertThrowsError(try a.geloescht())
    }
}
```

- [ ] **Step 2: Umsetzung schreiben**

`Sources/AufraeumerKern/DateiAblauf.swift`:

```swift
import Foundation

public enum Zustand: Equatable, Sendable {
    case gefunden, ausgewaehlt, kopiert, geprueft, hochgeladen, freigegeben, geloescht
    case abgebrochen(String)
}

public enum AblaufFehler: Error, Equatable {
    case unerlaubterUebergang(von: String, nach: String)
    case groesseUngleich
    case pruefsummeUngleich
    case favoritOhneBestaetigung
}

/// Zustandsautomat für genau eine Datei. Löschen ist nur im Zustand `freigegeben` erlaubt,
/// und dahin führt nur der vollständige Weg.
public struct DateiAblauf: Sendable {
    public let kandidat: Kandidat
    public let modus: Modus
    public private(set) var zustand: Zustand = .gefunden
    private var kopie: (bytes: Int64, pruefsumme: String)?

    public init(kandidat: Kandidat, modus: Modus) {
        self.kandidat = kandidat
        self.modus = modus
    }

    public var loeschenErlaubt: Bool { zustand == .freigegeben }

    public var istEnde: Bool {
        switch zustand {
        case .geloescht, .abgebrochen: return true
        default: return false
        }
    }

    private func unerlaubt(_ nach: String) -> AblaufFehler {
        .unerlaubterUebergang(von: "\(zustand)", nach: nach)
    }

    private mutating func uebergang(erlaubtVon erlaubt: [Zustand], nach neu: Zustand) throws {
        guard erlaubt.contains(zustand) else { throw unerlaubt("\(neu)") }
        zustand = neu
    }

    public mutating func auswaehlen() throws {
        try uebergang(erlaubtVon: [.gefunden], nach: .ausgewaehlt)
    }

    public mutating func kopiert(bytes: Int64, pruefsumme: String) throws {
        guard modus == .erstSichern else { throw unerlaubt("kopiert (Modus nurLoeschen)") }
        try uebergang(erlaubtVon: [.ausgewaehlt], nach: .kopiert)
        kopie = (bytes, pruefsumme)
    }

    public mutating func pruefen(originalBytes: Int64, originalPruefsumme: String) throws {
        guard zustand == .kopiert, let kopie = kopie else { throw unerlaubt("geprueft") }
        if kopie.bytes != originalBytes {
            zustand = .abgebrochen("Größe der Kopie stimmt nicht")
            throw AblaufFehler.groesseUngleich
        }
        if kopie.pruefsumme != originalPruefsumme {
            zustand = .abgebrochen("Prüfsumme der Kopie stimmt nicht")
            throw AblaufFehler.pruefsummeUngleich
        }
        zustand = .geprueft
    }

    public mutating func hochgeladen() throws {
        try uebergang(erlaubtVon: [.geprueft], nach: .hochgeladen)
    }

    public mutating func freigeben(favoritBestaetigt: Bool) throws {
        let vorher: Zustand = (modus == .erstSichern) ? .hochgeladen : .ausgewaehlt
        guard zustand == vorher else { throw unerlaubt("freigegeben") }
        if kandidat.istFavorit && !favoritBestaetigt { throw AblaufFehler.favoritOhneBestaetigung }
        zustand = .freigegeben
    }

    public mutating func geloescht() throws {
        try uebergang(erlaubtVon: [.freigegeben], nach: .geloescht)
    }

    public mutating func abbrechen(grund: String) throws {
        guard !istEnde else { throw unerlaubt("abgebrochen") }
        zustand = .abgebrochen(grund)
    }
}
```

- [ ] **Step 3: Commit, pushen, CI grün abwarten**

```bash
git add -A
git commit -q -m "Zustandsautomat je Datei: Löschen nur nach vollständigem, geprüftem Weg" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git push
"$GH" run list --branch entwicklung --limit 1 --json databaseId,status,conclusion
"$GH" run watch <ID> --exit-status
```

Expected: Lauf grün.

---

### Task 6: Schnittstellen und Löschlauf

**Files:**
- Create: `Sources/AufraeumerKern/Schnittstellen.swift`, `Sources/AufraeumerKern/Loeschlauf.swift`, `Tests/AufraeumerKernTests/Fakes.swift`, `Tests/AufraeumerKernTests/LoeschlaufTests.swift`

**Interfaces:**
- Consumes: `Kandidat`, `Modus` (Task 2), `DuplikatGruppe` (Task 3), `Protokoll`, `ProtokollEintrag`, `Aktion` (Task 4), `DateiAblauf`, `AblaufFehler` (Task 5).
- Produces:
  - `struct Export: Sendable { datei: URL; bytes: Int64; pruefsumme: String; init(datei:bytes:pruefsumme:) }`
  - `struct SicherungsBeleg: Hashable, Sendable { kennung: String; init(kennung:) }`
  - `struct KopieInfo: Sendable { bytes: Int64; pruefsumme: String; init(bytes:pruefsumme:) }`
  - `protocol MedienBibliothek: Sendable { func exportieren(id: String) async throws -> Export; func loeschen(ids: [String]) async throws }`
  - `protocol Sicherung: Sendable { func ablegen(_ export: Export, name: String) async throws -> SicherungsBeleg; func kopieLesen(_ beleg: SicherungsBeleg) async throws -> KopieInfo; func istHochgeladen(_ beleg: SicherungsBeleg) async throws -> Bool }`
  - `struct Auswahl: Sendable { kandidat: Kandidat; modus: Modus; favoritBestaetigt: Bool; init(kandidat:modus:favoritBestaetigt:) }`
  - `struct LoeschlaufErgebnis: Sendable { geloescht: [String]; nichtGeloescht: [String: String]; protokoll: Protokoll }`
  - `enum LoeschlaufFehler: Error, Equatable { case uploadZeitueberschreitung }`
  - `final class Loeschlauf: Sendable { init(bibliothek: any MedienBibliothek, sicherung: any Sicherung, wartezeit: TimeInterval = 600, pollIntervall: TimeInterval = 2, jetzt: @escaping @Sendable () -> Date = { Date() }, aufEintrag: (@Sendable (ProtokollEintrag) -> Void)? = nil); func ausfuehren(auswahl: [Auswahl], gruppen: [DuplikatGruppe], bestaetigt: Bool) async -> LoeschlaufErgebnis }`

- [ ] **Step 1: Fakes und Tests schreiben**

`Tests/AufraeumerKernTests/Fakes.swift`:

```swift
import Foundation
@testable import AufraeumerKern

enum FakeFehler: Error { case export, ablegen, nutzerAbbruch }

/// Thread-sichere Ereignisliste, damit die Reihenfolge der Aufrufe geprüft werden kann.
final class Ereignisse: @unchecked Sendable {
    private let lock = NSLock()
    private var _liste: [String] = []
    func add(_ s: String) { lock.lock(); _liste.append(s); lock.unlock() }
    var liste: [String] { lock.lock(); defer { lock.unlock() }; return _liste }
    func index(_ s: String) -> Int? { liste.firstIndex(of: s) }
    func enthaeltPraefix(_ p: String) -> Bool { liste.contains { $0.hasPrefix(p) } }
}

final class FakeBibliothek: MedienBibliothek, @unchecked Sendable {
    let log: Ereignisse
    var exportFehlerFuer: Set<String> = []
    var loeschFehler: Error?
    init(log: Ereignisse) { self.log = log }

    func exportieren(id: String) async throws -> Export {
        if exportFehlerFuer.contains(id) { throw FakeFehler.export }
        log.add("export:\(id)")
        return Export(datei: URL(fileURLWithPath: "/nicht-vorhanden/\(id)"), bytes: 1000, pruefsumme: "sum-\(id)")
    }

    func loeschen(ids: [String]) async throws {
        log.add("loeschen:\(ids.joined(separator: ","))")
        if let f = loeschFehler { throw f }
    }
}

final class FakeSicherung: Sicherung, @unchecked Sendable {
    var kopieBytesAbweichung: Int64 = 0
    var kopieSummeVerfaelscht: Set<String> = []
    /// Nach wie vielen Nachfragen „hochgeladen“ gemeldet wird; `Int.max` = nie.
    var hochgeladenNach = 1
    private var nachfragen: [String: Int] = [:]

    func ablegen(_ export: Export, name: String) async throws -> SicherungsBeleg {
        SicherungsBeleg(kennung: export.pruefsumme)
    }

    func kopieLesen(_ beleg: SicherungsBeleg) async throws -> KopieInfo {
        KopieInfo(bytes: 1000 + kopieBytesAbweichung,
                  pruefsumme: kopieSummeVerfaelscht.contains(beleg.kennung) ? "verfaelscht" : beleg.kennung)
    }

    func istHochgeladen(_ beleg: SicherungsBeleg) async throws -> Bool {
        nachfragen[beleg.kennung, default: 0] += 1
        return nachfragen[beleg.kennung]! >= hochgeladenNach
    }
}
```

`Tests/AufraeumerKernTests/LoeschlaufTests.swift`:

```swift
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

    private func lauf(aufEintrag: (@Sendable (ProtokollEintrag) -> Void)? = nil) -> Loeschlauf {
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
        XCTAssertLessThan(vorher!, loeschen!)
        XCTAssertLessThan(loeschen!, log.index("protokoll:geloescht:A")!)
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
}
```

- [ ] **Step 2: Umsetzung schreiben**

`Sources/AufraeumerKern/Schnittstellen.swift`:

```swift
import Foundation

public struct Export: Sendable {
    public let datei: URL
    public let bytes: Int64
    public let pruefsumme: String
    public init(datei: URL, bytes: Int64, pruefsumme: String) {
        self.datei = datei
        self.bytes = bytes
        self.pruefsumme = pruefsumme
    }
}

public struct SicherungsBeleg: Hashable, Sendable {
    public let kennung: String
    public init(kennung: String) { self.kennung = kennung }
}

public struct KopieInfo: Sendable {
    public let bytes: Int64
    public let pruefsumme: String
    public init(bytes: Int64, pruefsumme: String) {
        self.bytes = bytes
        self.pruefsumme = pruefsumme
    }
}

/// Zugriff auf die Mediathek (in der App über PhotoKit umgesetzt).
public protocol MedienBibliothek: Sendable {
    /// Schreibt das Original in eine temporäre Datei und liefert Größe und SHA-256.
    func exportieren(id: String) async throws -> Export
    /// Löscht in einem Zug; wirft, wenn der Nutzer die iOS-Abfrage ablehnt oder das Löschen scheitert.
    func loeschen(ids: [String]) async throws
}

/// Ablage in der Cloud (in der App: ein iCloud-Drive-Ordner).
public protocol Sicherung: Sendable {
    func ablegen(_ export: Export, name: String) async throws -> SicherungsBeleg
    /// Liest die abgelegte Kopie erneut und liefert deren Größe und SHA-256.
    func kopieLesen(_ beleg: SicherungsBeleg) async throws -> KopieInfo
    func istHochgeladen(_ beleg: SicherungsBeleg) async throws -> Bool
}
```

`Sources/AufraeumerKern/Loeschlauf.swift`:

```swift
import Foundation

public struct Auswahl: Sendable {
    public let kandidat: Kandidat
    public let modus: Modus
    public let favoritBestaetigt: Bool
    public init(kandidat: Kandidat, modus: Modus, favoritBestaetigt: Bool) {
        self.kandidat = kandidat
        self.modus = modus
        self.favoritBestaetigt = favoritBestaetigt
    }
}

public struct LoeschlaufErgebnis: Sendable {
    public let geloescht: [String]
    /// Kennung → Grund, warum nicht gelöscht wurde.
    public let nichtGeloescht: [String: String]
    public let protokoll: Protokoll
}

public enum LoeschlaufFehler: Error, Equatable {
    case uploadZeitueberschreitung
}

/// Steuert den ganzen Ablauf. Sicherheitsprinzip: Jede Unsicherheit führt zu „nicht löschen“.
public final class Loeschlauf: Sendable {
    private let bibliothek: any MedienBibliothek
    private let sicherung: any Sicherung
    private let wartezeit: TimeInterval
    private let pollIntervall: TimeInterval
    private let jetzt: @Sendable () -> Date
    private let aufEintrag: (@Sendable (ProtokollEintrag) -> Void)?

    public init(bibliothek: any MedienBibliothek, sicherung: any Sicherung,
                wartezeit: TimeInterval = 600, pollIntervall: TimeInterval = 2,
                jetzt: @escaping @Sendable () -> Date = { Date() },
                aufEintrag: (@Sendable (ProtokollEintrag) -> Void)? = nil) {
        self.bibliothek = bibliothek
        self.sicherung = sicherung
        self.wartezeit = wartezeit
        self.pollIntervall = pollIntervall
        self.jetzt = jetzt
        self.aufEintrag = aufEintrag
    }

    public func ausfuehren(auswahl: [Auswahl], gruppen: [DuplikatGruppe],
                           bestaetigt: Bool) async -> LoeschlaufErgebnis {
        var protokoll = Protokoll()
        var nicht: [String: String] = [:]
        let jetzt = self.jetzt
        let aufEintrag = self.aufEintrag

        func notiere(_ k: Kandidat, _ a: Aktion, _ grund: String? = nil) {
            let e = ProtokollEintrag(zeit: jetzt(), id: k.id, name: k.name,
                                     groesseBytes: k.groesseBytes, aktion: a, grund: grund)
            protokoll.hinzufuegen(e)
            aufEintrag?(e)
        }

        // Dieselbe Datei nur einmal verarbeiten.
        var gesehen = Set<String>()
        let einzeln = auswahl.filter { gesehen.insert($0.kandidat.id).inserted }

        guard bestaetigt else {
            for a in einzeln {
                nicht[a.kandidat.id] = "Keine Bestätigung"
                notiere(a.kandidat, .abgebrochen, "Keine Bestätigung")
            }
            return LoeschlaufErgebnis(geloescht: [], nichtGeloescht: nicht, protokoll: protokoll)
        }

        // Stufe 1: je Datei sichern und prüfen (nur im Modus erstSichern), dann freigeben.
        var abl: [String: DateiAblauf] = [:]
        for a in einzeln {
            let k = a.kandidat
            var ablauf = DateiAblauf(kandidat: k, modus: a.modus)
            do {
                try ablauf.auswaehlen()
                if a.modus == .erstSichern {
                    let export = try await bibliothek.exportieren(id: k.id)
                    defer { try? FileManager.default.removeItem(at: export.datei) }
                    let beleg = try await sicherung.ablegen(export, name: k.name)
                    let kopie = try await sicherung.kopieLesen(beleg)
                    try ablauf.kopiert(bytes: kopie.bytes, pruefsumme: kopie.pruefsumme)
                    try ablauf.pruefen(originalBytes: export.bytes, originalPruefsumme: export.pruefsumme)
                    try await warteAufUpload(beleg)
                    try ablauf.hochgeladen()
                    notiere(k, .gesichert)
                }
                try ablauf.freigeben(favoritBestaetigt: a.favoritBestaetigt)
            } catch {
                let grund = Loeschlauf.beschreibe(error)
                try? ablauf.abbrechen(grund: grund)
                nicht[k.id] = grund
                notiere(k, .abgebrochen, grund)
            }
            abl[k.id] = ablauf
        }

        // Stufe 2: Kandidaten für das Löschen bestimmen.
        var zuLoeschen = einzeln.map(\.kandidat.id).filter { abl[$0]?.loeschenErlaubt == true }

        // Nie das letzte Exemplar einer Duplikatgruppe löschen, wenn keine geprüfte Sicherung existiert.
        let loeschSet = Set(zuLoeschen)
        for g in gruppen where g.alleIds.allSatisfy({ loeschSet.contains($0) }) {
            let hatSicherung = g.alleIds.contains { abl[$0]?.modus == .erstSichern }
            if !hatSicherung, let behalten = abl[g.behalten] {
                zuLoeschen.removeAll { $0 == g.behalten }
                let grund = "Letztes Exemplar einer Duplikatgruppe bleibt erhalten"
                nicht[g.behalten] = grund
                notiere(behalten.kandidat, .abgebrochen, grund)
            }
        }

        guard !zuLoeschen.isEmpty else {
            return LoeschlaufErgebnis(geloescht: [], nichtGeloescht: nicht, protokoll: protokoll)
        }

        // Stufe 3: erst „beabsichtigt“ festhalten, dann löschen, dann Ergebnis festhalten.
        for id in zuLoeschen { if let a = abl[id] { notiere(a.kandidat, .beabsichtigt) } }
        do {
            try await bibliothek.loeschen(ids: zuLoeschen)
            for id in zuLoeschen {
                _ = try? abl[id]?.geloescht()
                if let a = abl[id] { notiere(a.kandidat, .geloescht) }
            }
            return LoeschlaufErgebnis(geloescht: zuLoeschen, nichtGeloescht: nicht, protokoll: protokoll)
        } catch {
            let grund = "Löschen nicht ausgeführt: \(Loeschlauf.beschreibe(error))"
            for id in zuLoeschen {
                nicht[id] = grund
                if let a = abl[id] { notiere(a.kandidat, .abgebrochen, grund) }
            }
            return LoeschlaufErgebnis(geloescht: [], nichtGeloescht: nicht, protokoll: protokoll)
        }
    }

    private func warteAufUpload(_ beleg: SicherungsBeleg) async throws {
        let ende = Date().addingTimeInterval(wartezeit)
        while true {
            if try await sicherung.istHochgeladen(beleg) { return }
            if Date() >= ende { throw LoeschlaufFehler.uploadZeitueberschreitung }
            try await Task.sleep(nanoseconds: UInt64(pollIntervall * 1_000_000_000))
        }
    }

    static func beschreibe(_ fehler: Error) -> String {
        if let a = fehler as? AblaufFehler {
            switch a {
            case .groesseUngleich: return "Größe der Kopie stimmt nicht"
            case .pruefsummeUngleich: return "Prüfsumme der Kopie stimmt nicht"
            case .favoritOhneBestaetigung: return "Favorit ohne ausdrückliche Bestätigung"
            case .unerlaubterUebergang(let von, let nach): return "Unerlaubter Übergang \(von) → \(nach)"
            }
        }
        if let l = fehler as? LoeschlaufFehler, l == .uploadZeitueberschreitung {
            return "Upload nicht rechtzeitig fertig"
        }
        return "Fehler: \(fehler.localizedDescription)"
    }
}
```

- [ ] **Step 3: Commit, pushen, CI grün abwarten**

```bash
git add -A
git commit -q -m "Löschlauf: sichern, prüfen, Duplikatschutz, Protokoll vor dem Löschen" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git push
"$GH" run list --branch entwicklung --limit 1 --json databaseId,status,conclusion
"$GH" run watch <ID> --exit-status
```

Expected: Lauf grün, alle `LoeschlaufTests` bestanden. Falls Swift eine Nebenläufigkeits- oder Typwarnung als Fehler meldet, die Meldung lesen und minimal beheben (Verhalten und Tests bleiben unverändert).

---

### Task 7: Probe-App und `.ipa`-Pipeline

**Files:**
- Create: `project.yml`, `App/AufraeumerApp.swift`, `App/ProbeView.swift`, `App/MediathekProbe.swift`, `App/ICloudProbe.swift`
- Modify: `.github/workflows/ios.yml`

**Interfaces:**
- Consumes: Paket `AufraeumerKern` (nur eingebunden; die Probe nutzt es noch nicht).
- Produces: GitHub-Artefakt `Aufraeumer-ipa` (`Aufraeumer.ipa`, unsigniert).

- [ ] **Step 1: XcodeGen-Beschreibung**

`project.yml`:

```yaml
name: Aufraeumer
options:
  bundleIdPrefix: com.mk76reuzer
  deploymentTarget:
    iOS: "17.0"
packages:
  AufraeumerKern:
    path: .
targets:
  Aufraeumer:
    type: application
    platform: iOS
    sources: [App]
    dependencies:
      - package: AufraeumerKern
        product: AufraeumerKern
    info:
      path: App/Info.plist
      properties:
        CFBundleDisplayName: Aufräumer
        NSPhotoLibraryUsageDescription: "Der Aufräumer zeigt dir große und überflüssige Fotos und Videos und löscht nur, was du ausdrücklich bestätigst."
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.mk76reuzer.aufraeumer
        SWIFT_VERSION: "5.9"
        TARGETED_DEVICE_FAMILY: "1"
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
```

- [ ] **Step 2: Probe-App schreiben**

`App/AufraeumerApp.swift`:

```swift
import SwiftUI

@main
struct AufraeumerApp: App {
    var body: some Scene {
        WindowGroup {
            ProbeView()
        }
    }
}
```

`App/MediathekProbe.swift`:

```swift
import Foundation
import Photos

/// Nur lesend: zählt, was PhotoKit sieht, auch ausgeblendete Objekte, und die größten Videos.
enum MediathekProbe {
    static func lauf(_ ausgabe: @escaping @MainActor (String) -> Void) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await ausgabe("Foto-Zugriff: \(status.rawValue) (3 = voll, 4 = eingeschränkt)")
        guard status == .authorized else {
            await ausgabe("Kein Vollzugriff, Abbruch.")
            return
        }

        let optionen = PHFetchOptions()
        optionen.includeHiddenAssets = true
        let alle = PHAsset.fetchAssets(with: optionen)

        var ausgeblendet = 0, videos = 0, lokaleVideos = 0, screenshots = 0
        var lokalGesamt: Int64 = 0
        var groesste: [(mb: Double, ausgeblendet: Bool, lokal: Bool, name: String)] = []

        alle.enumerateObjects { asset, _, _ in
            if asset.isHidden { ausgeblendet += 1 }
            if asset.mediaSubtypes.contains(.photoScreenshot) { screenshots += 1 }
            guard asset.mediaType == .video else { return }
            videos += 1
            let ressourcen = PHAssetResource.assetResources(for: asset)
            guard let haupt = ressourcen.first(where: { $0.type == .video || $0.type == .fullSizeVideo })
                    ?? ressourcen.first else { return }
            var groesse: Int64 = 0
            var lokal = false
            // Schlüssel-Werte sind nicht offiziell dokumentiert; vorher prüfen, um Abstürze zu vermeiden.
            if haupt.responds(to: NSSelectorFromString("fileSize")),
               let n = haupt.value(forKey: "fileSize") as? NSNumber { groesse = n.int64Value }
            if haupt.responds(to: NSSelectorFromString("locallyAvailable")),
               let n = haupt.value(forKey: "locallyAvailable") as? NSNumber { lokal = n.boolValue }
            if lokal { lokaleVideos += 1; lokalGesamt += groesse }
            groesste.append((Double(groesse) / 1_000_000, asset.isHidden, lokal, haupt.originalFilename))
        }

        await ausgabe("Einträge gesamt: \(alle.count), davon ausgeblendet: \(ausgeblendet)")
        await ausgabe("Screenshots: \(screenshots)")
        await ausgabe("Videos: \(videos), davon lokal vorhanden: \(lokaleVideos)")
        await ausgabe("Lokale Videos zusammen: \(Int(Double(lokalGesamt) / 1_000_000)) MB")
        for v in groesste.sorted(by: { $0.mb > $1.mb }).prefix(5) {
            await ausgabe("  \(Int(v.mb)) MB | ausgeblendet=\(v.ausgeblendet) | lokal=\(v.lokal) | \(v.name)")
        }

        let werte = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        if let frei = werte?.volumeAvailableCapacityForImportantUsage, let gesamt = werte?.volumeTotalCapacity {
            await ausgabe("Speicher: \(frei / 1_000_000_000) GB frei von \(gesamt / 1_000_000_000) GB")
        }
    }
}
```

`App/ICloudProbe.swift`:

```swift
import Foundation
import CryptoKit

/// Schreibt eine 5-MB-Testdatei in einen vom Nutzer gewählten iCloud-Drive-Ordner und beobachtet,
/// ob iOS den Upload-Status („hochgeladen“) für diese Datei meldet.
enum ICloudProbe {
    static func lauf(ordner: URL, ausgabe: @escaping @MainActor (String) -> Void) async {
        let zugriff = ordner.startAccessingSecurityScopedResource()
        defer { if zugriff { ordner.stopAccessingSecurityScopedResource() } }
        await ausgabe("Ordner: \(ordner.lastPathComponent) (Zugriff: \(zugriff))")

        var bytes = [UInt8](repeating: 0, count: 5_000_000)
        let anzahl = bytes.count
        guard SecRandomCopyBytes(kSecRandomDefault, anzahl, &bytes) == errSecSuccess else {
            await ausgabe("Zufallsdaten fehlgeschlagen.")
            return
        }
        let daten = Data(bytes)
        let summe = SHA256.hash(data: daten).map { String(format: "%02x", $0) }.joined()
        let ziel = ordner.appendingPathComponent("aufraeumer-probe-\(Int(Date().timeIntervalSince1970)).bin")

        var koordinatorFehler: NSError?
        var schreibFehler: Error?
        NSFileCoordinator().coordinate(writingItemAt: ziel, options: .forReplacing,
                                       error: &koordinatorFehler) { url in
            do { try daten.write(to: url, options: .atomic) } catch { schreibFehler = error }
        }
        if let fehler = koordinatorFehler ?? (schreibFehler as NSError?) {
            await ausgabe("Schreiben fehlgeschlagen: \(fehler.localizedDescription)")
            return
        }
        await ausgabe("Geschrieben: \(daten.count) Bytes, SHA-256 \(summe.prefix(12))…")

        let start = Date()
        var hochgeladen = false
        var letzte = ""
        while Date().timeIntervalSince(start) < 180 {
            let w = try? ziel.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemIsUploadedKey,
                                                       .ubiquitousItemIsUploadingKey, .ubiquitousItemUploadingErrorKey])
            let zeile = "ubiquitär=\(String(describing: w?.isUbiquitousItem)) "
                + "hochgeladen=\(String(describing: w?.ubiquitousItemIsUploaded)) "
                + "lädt=\(String(describing: w?.ubiquitousItemIsUploading)) "
                + "fehler=\(String(describing: w?.ubiquitousItemUploadingError?.localizedDescription))"
            if zeile != letzte {
                await ausgabe("+\(Int(Date().timeIntervalSince(start))) s: \(zeile)")
                letzte = zeile
            }
            if w?.ubiquitousItemIsUploaded == true { hochgeladen = true; break }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        if let gelesen = try? Data(contentsOf: ziel) {
            let summe2 = SHA256.hash(data: gelesen).map { String(format: "%02x", $0) }.joined()
            await ausgabe("Erneut gelesen: \(gelesen.count) Bytes, Prüfsumme gleich: \(summe2 == summe)")
        } else {
            await ausgabe("Kopie konnte nicht erneut gelesen werden.")
        }
        await ausgabe(hochgeladen
            ? "ERGEBNIS: Upload-Nachweis funktioniert."
            : "ERGEBNIS: Kein Upload-Nachweis innerhalb von 180 s.")
        await ausgabe("Bitte die Datei \(ziel.lastPathComponent) (5 MB) danach in der Dateien-App löschen.")
    }
}
```

`App/ProbeView.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ProbeView: View {
    @State private var bericht: [String] = ["Bereit."]
    @State private var ordnerWaehlen = false
    @State private var laeuft = false

    var body: some View {
        NavigationStack {
            List {
                Section("Schritt 1: Mediathek (nur lesen)") {
                    Button("Mediathek zählen") { starteMediathek() }
                        .disabled(laeuft)
                }
                Section("Schritt 2: iCloud-Drive-Upload") {
                    Button("Ordner wählen und Testdatei senden") { ordnerWaehlen = true }
                        .disabled(laeuft)
                }
                Section("Ergebnis") {
                    ForEach(Array(bericht.enumerated()), id: \.offset) { _, zeile in
                        Text(zeile).font(.footnote.monospaced()).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Aufräumer – Probe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: bericht.joined(separator: "\n"))
                }
            }
            .fileImporter(isPresented: $ordnerWaehlen, allowedContentTypes: [.folder]) { ergebnis in
                switch ergebnis {
                case .success(let url): starteICloud(url)
                case .failure(let fehler): zeige("Ordnerwahl fehlgeschlagen: \(fehler.localizedDescription)")
                }
            }
        }
    }

    @MainActor private func zeige(_ text: String) { bericht.append(text) }

    @MainActor private func starteMediathek() {
        laeuft = true
        Task {
            await MediathekProbe.lauf { zeige($0) }
            laeuft = false
        }
    }

    @MainActor private func starteICloud(_ url: URL) {
        laeuft = true
        Task {
            await ICloudProbe.lauf(ordner: url) { zeige($0) }
            laeuft = false
        }
    }
}
```

- [ ] **Step 3: Pipeline um Bau und `.ipa` erweitern**

`.github/workflows/ios.yml` vollständig ersetzen:

```yaml
name: ios
on:
  push:
    branches: [entwicklung, main]
  workflow_dispatch:

jobs:
  kern-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Versionen
        run: xcodebuild -version && swift --version
      - name: Tests
        run: swift test

  ipa:
    needs: kern-tests
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: XcodeGen installieren
        run: brew install xcodegen
      - name: Projekt erzeugen
        run: xcodegen generate
      - name: Bauen (ohne Signatur)
        run: |
          xcodebuild -project Aufraeumer.xcodeproj -scheme Aufraeumer \
            -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
            -archivePath build/Aufraeumer.xcarchive \
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
            archive
      - name: IPA packen
        run: |
          ls build/Aufraeumer.xcarchive/Products/Applications
          mkdir -p Payload
          cp -R build/Aufraeumer.xcarchive/Products/Applications/Aufraeumer.app Payload/
          zip -qr Aufraeumer.ipa Payload
          ls -l Aufraeumer.ipa
      - uses: actions/upload-artifact@v4
        with:
          name: Aufraeumer-ipa
          path: Aufraeumer.ipa
          retention-days: 14
```

- [ ] **Step 4: Commit, pushen, CI grün abwarten**

```bash
git add -A
git commit -q -m "Probe-App und Pipeline für die unsignierte IPA" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git push
"$GH" run list --branch entwicklung --limit 1 --json databaseId,status,conclusion
"$GH" run watch <ID> --exit-status
```

Expected: beide Jobs grün, Artefakt `Aufraeumer-ipa` vorhanden. Häufige Fehler und Behebung: unbekanntes API in einer Probe-Datei → Compilerzeile im Protokoll lesen und die Zeile anpassen; Scheme-Name weicht ab → `xcodebuild -list -project Aufraeumer.xcodeproj` als Zusatzschritt ausgeben und `-scheme` anpassen.

---

### Task 8: IPA holen, installieren, Ergebnis festhalten

**Files:**
- Create: `ANLEITUNG.md`, `docs/probe-ergebnis.md`

**Interfaces:**
- Consumes: Artefakt `Aufraeumer-ipa` (Task 7).
- Produces: `docs/probe-ergebnis.md` mit den Antworten auf die zwei Fragen; Entscheidung über den Weiterbau.

- [ ] **Step 1: IPA herunterladen (auf dem PC nur eine 1-Datei-Übertragung)**

```bash
mkdir -p out
"$GH" run download <ID> -n Aufraeumer-ipa -D out
ls -l out
```

Expected: `out/Aufraeumer.ipa` (ein paar MB).

- [ ] **Step 2: Anleitung für den Nutzer schreiben**

`ANLEITUNG.md`:

```markdown
# Installation der Probe (einmalig, ca. 5 Minuten)

1. iPhone per USB anschließen, entsperren, „Vertrauen“ bestätigen.
2. Sideloadly öffnen, `Aufraeumer.ipa` hineinziehen, deine Apple-ID selbst eintragen, „Start“.
3. Am iPhone: Einstellungen → Datenschutz & Sicherheit → **Entwicklermodus** einschalten (Neustart).
4. Einstellungen → Allgemein → VPN & Geräteverwaltung → deine Apple-ID → **Vertrauen**.
5. App „Aufräumer“ öffnen: erst „Mediathek zählen“ (Foto-Zugriff auf **Alle Fotos** erlauben),
   dann „Ordner wählen und Testdatei senden“ (einen Ordner in iCloud Drive wählen).
6. Oben rechts „Teilen“ → „Kopieren“ und den Text in den Chat einfügen.

Die Installation gilt 7 Tage. Sie löscht nichts. Die Testdatei (5 MB) danach in der Dateien-App löschen.
```

- [ ] **Step 3: Nutzer-Schritt abwarten, Ergebnis auswerten**

Der Nutzer installiert und liefert den kopierten Bericht. Auswerten und in `docs/probe-ergebnis.md` festhalten (ohne Dateinamen und persönliche Angaben, nur Zahlen und Ja/Nein):

```markdown
# Ergebnis der Probe

- Foto-Zugriff Vollzugriff möglich: ja/nein
- Ausgeblendete Objekte für PhotoKit sichtbar: ja/nein (Anzahl)
- Videos lokal vorhanden / gesamt: X / Y; größtes lokales Video: Z MB
- iCloud-Drive-Upload-Nachweis (`ubiquitousItemIsUploaded`) meldet „hochgeladen“: ja/nein, nach N Sekunden
- Kopie erneut lesbar, Prüfsumme gleich: ja/nein
- Entscheidung: Upload-Nachweis trägt → weiter mit M1. Sonst: manuelle Bestätigung je Lauf einplanen.
```

- [ ] **Step 4: Commit**

```bash
git add ANLEITUNG.md docs/probe-ergebnis.md
git commit -q -m "Anleitung und Ergebnis der Probe" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git push
```

Expected: Push erfolgreich, CI grün.

---

## Selbstprüfung (durchgeführt)

**Abdeckung der Spec:** Abschnitt 4 (Kategorien) → Task 2 und 3; Abschnitt 5 (Regeln 1–7) → Task 5 und 6 (Regel 1 „Bestätigung“ in `Loeschlauf.bestaetigt`, Regel 2 in `DateiAblauf`, Regel 3 Duplikatschutz, Regel 4 `beabsichtigt` vor Löschaufruf, Regel 5 Fehlerfall → nicht löschen, Regel 6 Favoritenbestätigung, Regel 7 kein automatisches Löschen: es gibt keinen Auslöser außer `ausfuehren`); Abschnitt 6 Kern-Bausteine → Task 2–6; Abschnitt 8 (Bau, Sideloadly) → Task 7 und 8; Abschnitt 10 M0 → Task 7 und 8. **Nicht in diesem Plan** (bewusst, eigene Pläne nach dem Probe-Ergebnis): `PhotoKitBibliothek`, `ICloudSicherung`, Face-ID-Sperre, Bildschirme (M1–M4).

**Platzhalter:** keine. Die einzigen offenen Werte (`<ID>` der CI-Läufe, Ergebnisse der Probe) entstehen zur Laufzeit.

**Typkonsistenz:** `Kandidat`-Init-Reihenfolge in `TestHilfen.T.k` entspricht `Modell.swift`; `DateiAblauf`-Methoden (`kopiert`, `pruefen`, `hochgeladen`, `freigeben`, `geloescht`, `abbrechen`) sind in Task 5 definiert und in Task 6 unverändert verwendet; `Export`, `KopieInfo`, `SicherungsBeleg` sind in `Schnittstellen.swift` (Task 6) definiert und von `Fakes.swift` genutzt.

**Review Focus:** jede der sechs Zeilen hat einen benannten Test (Task 2: `testUnbekannteGroesseOderNurCloudWirdNieAngeboten`; Task 3: `testGleicheGroesseAberAndereSummeIstKeinDuplikat`, `testUnterschiedlicheGespeicherteDauerStehtDerErkennungNichtImWeg`; Task 4: `testSonderzeichenWerdenMaskiert`; Task 6: `testAlleExemplareEinerDuplikatgruppeOhneSicherungBehaeltEines`, `testUploadNieFertigDannWirdNichtGeloescht`, `testDieselbeDateiZweimalAusgewaehltWirdEinmalVerarbeitet`, `testAbgelehnteLoeschabfrageProtokolliertBeabsichtigtDannAbgebrochen`).
