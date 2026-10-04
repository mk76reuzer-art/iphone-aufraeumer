# Plan Version 0.3

Stand: 04.10.2026. Grundlage: Nutzer-Feedback zu 0.2.0 (Ordnerwahl funktioniert nicht, unklarer Nutzen).

## Kostenlose Apple-ID und Sicherung in 0.2.0

Mit einer kostenlosen Apple-ID signiert Xcode nur über das **Personal Team**. Dieses Team hat **keinen Zugang zu Certificates, Identifiers & Profiles** und kann **keine iCloud-Container** für die App anlegen oder verwalten. Quellen: [Apple QA1915 (Personal Team)](https://developer.apple.com/library/archive/qa/qa1915/_index.html), [Apple Developer Hilfe – Zugriff nach Kontotyp](https://developer.apple.com/help/account/access/resolving-access-issues/) (Spalte „Registered for free“ ohne Identifiers), [CloudKit erfordert bezahltes Programm](https://stackoverflow.com/questions/41899206/using-cloudkit-with-a-free-apple-account).

Version 0.2.0 nutzt **keinen** App-eigenen iCloud-Container, sondern kopiert in einen vom Nutzer in der **Dateien-App** gewählten Ordner (`ICloudSicherung` + Lesezeichen in `UserDefaults`). Das ist grundsätzlich ohne Entwicklerkonto möglich.

Das Problem war die **Ordnerauswahl**: `fileImporter` mit `.folder` ist auf dem iPhone oft unzuverlässig (kein klarer Pfad zu iCloud Drive, On My iPhone, Drittanbieter). Zusätzlich muss nach der Ordnerwahl `startAccessingSecurityScopedResource` gesetzt werden (iOS kennt kein macOS-`withSecurityScope` beim Lesezeichen). Die Upload-Warteschleife (`ubiquitousItemIsUploaded`) blockiert bei Ordnern **auf dem Gerät** unnötig.

**0.3:** Ordner über `UIDocumentPickerViewController` (Dateien-App), Lesezeichen mit Security-Scope, nach Größenprüf der Kopie gilt lokale Ablage als fertig; nur echte iCloud-Drive-Dateien warten weiter auf Upload.

## iCloud-Fotos, Löschen und „Zuletzt gelöscht“

Wenn **iCloud-Fotos** aktiv ist, entfernt Löschen in der Mediathek das Objekt auch aus iCloud und von verknüpften Geräten (vgl. Design-Spec Abschnitt 3). Die App kann den Schalter nicht auslesen; 0.3 **fragt einmalig** und erklärt die Folge.

Gelöschte Medien landen 30 Tage unter **Zuletzt gelöscht**. **Freier Speicher auf dem iPhone** entsteht erst nach „Alle löschen“ dort (ebenfalls Spec Abschnitt 3). Die App zeigt vorher/nachher freien Speicher und eine **bebilderte Kurzanleitung** auf der Erfolgsseite.

## Bildschirme (je ein Satz)

| Schritt | Nutzer sieht | Hauptknopf | Danach |
| --- | --- | --- | --- |
| 1 Prüfen | Freier Speicher, vier-Schritte-Leiste, Vorschläge mit Größen, optional Videos verkleinern | „Auswählen“ | Auswahl mit vorausgewählten sicheren Dateien |
| 2 Auswählen | Liste mit Vorschau, Summe „macht etwa X frei“, Sicherungs-Optionen für Doppelte/Serien/Screenshots | „Weiter“ | Sichern oder direkt Löschen-Bestätigung |
| 3 Sichern | Gewählter Ordner, Fortschritt in Prozent und Restzeit, Dateiname | „Weiter zum Löschen“ | Bestätigungsseite |
| 4 Löschen | Zusammenfassung, Hinweis iCloud-Fotos | „Jetzt löschen“ | iOS-Abfrage, dann Erfolgsseite |
| Erfolg | „X frei geworden“, Speicher vorher/nachher, Anleitung Zuletzt gelöscht | „Fotos-App öffnen“ | Nutzer leert Papierkorb |
| Tipps | Drei System-Hebel mit einfachen Wegen in die Einstellungen | „Zurück“ | Übersicht |

## Technik kurz

- Kern 0.3.0: `SicherungsOptionen`, `VideoSparSchaetzung` (Tests).
- App: `OrdnerAuswahl`, verbesserte `OrdnerSicherung`, `VideoVerkleinerer` (HEVC 1080p, Datum/Ort), `SchrittLeiste`, `TippsView`.
- CI: UI-Tests mit Fixture-Daten, Screenshots nach `docs/screenshots-v3/`.
