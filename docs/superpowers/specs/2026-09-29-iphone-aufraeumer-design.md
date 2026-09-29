# iPhone-Aufräumer — Entwurf

Stand: 29.09.2026 · Status: freigegeben zur Umsetzung

## 1. Ziel

Eine iPhone-App, die Speicher **zuverlässig und sicher** freiräumt, ohne dass etwas
heimlich oder versehentlich verloren geht. Auslöser: Große Videos lagen in einem Album,
das von einem PC aus nicht sichtbar und per USB nicht sauber löschbar ist.

**Erfolg heißt:**

- Große und überflüssige Fotos/Videos werden gefunden, mit der wirklich lokal belegten Größe.
- „Noch Nützliches“ wird zuerst nach iCloud Drive gesichert, die Kopie wird geprüft, erst dann
  wird gelöscht.
- Es wird nie ohne ausdrückliche Bestätigung gelöscht, und jede Löschung steht in einem Protokoll.
- Bei jedem Fehler oder Zweifel bleibt alles, wie es ist.

## 2. Vereinbarungen (vom Nutzer bestätigt)

- Sicherungsziel: **iCloud Drive**.
- Repo: `mk76reuzer-art/iphone-aufraeumer`, **öffentlich** (kostenlose Mac-Builds). Nur Quellcode,
  keine Schlüssel, keine persönlichen Daten.
- Bedienung und Texte auf Deutsch.
- Keine Hilfs-Agenten; die Arbeit erfolgt in diesem Gespräch.

## 3. Grenzen von iOS (gelten für jede App)

- Aufgeräumt werden können nur: die Fotomediathek (mit Vollzugriff), Ordner, die der Nutzer der App
  freigibt, und die App selbst. **Nicht** möglich: Systemdaten, Caches anderer Apps, andere Apps löschen.
- Löschen aus der Mediathek fragt iOS **immer** selbst noch einmal ab.
- Gelöschtes landet 30 Tage in „Zuletzt gelöscht“. Der Platz wird **erst nach dem Leeren** frei. Die App
  kann das nicht selbst tun, nur daran erinnern und die Foto-App öffnen.
- iOS gibt Apps keine Ansehen-Zahlen. „Lange unbenutzt“ bedeutet hier: Aufnahmedatum alt, nie bearbeitet,
  kein Favorit, in keinem Album.
- Bei aktiven iCloud-Fotos gilt Löschen auch in iCloud und auf allen Geräten.

## 4. Kategorien

| Kategorie | Regel | Standard |
|---|---|---|
| Große Videos | lokal belegt ab 50 MB (einstellbar) | sichern, dann löschen |
| Lange unberührt | älter als 2 Jahre (einstellbar), nie bearbeitet, kein Favorit, in keinem Album | sichern, dann löschen |
| Duplikate | gleiche Größe, dann gleiche Prüfsumme (die gespeicherte Dauer wird nicht verglichen); **ein Exemplar bleibt immer** | nur löschen |
| Alte Screenshots | älter als 90 Tage (einstellbar) | nur löschen |

Nur **lokal vorhandene** Originale zählen. Was nur in iCloud liegt, wird nicht angeboten (Löschen würde
nichts freigeben). Das ausgeblendete Album wird nur nach Face ID sichtbar und einbezogen.
„Nur löschen“ lässt sich pro Lauf auf „sichern, dann löschen“ umstellen, umgekehrt nicht ohne eine
zusätzliche Bestätigung („Danach sind diese Dateien weg“).

## 5. Ablauf und Sicherheitsstufen

Pro Datei: `gefunden → ausgewählt → kopiert → geprüft → hochgeladen → freigegeben → gelöscht`
(bei „nur löschen“ entfallen kopiert bis hochgeladen).

Unverrückbare Regeln (jede wird per Test abgesichert):

1. Löschen nur nach Auswahl **und** Bestätigung auf dem Bestätigungsbildschirm (Vorschau, Größe,
   Datum, Hinweis auf iCloud-Fotos), danach folgt die iOS-Abfrage.
2. Für „sichern, dann löschen“ ist nur eine Datei löschbar, deren Zustand `hochgeladen` ist und deren
   Kopie dieselbe Größe und Prüfsumme hat.
3. In einer Duplikatgruppe wird nie das letzte Exemplar gelöscht.
4. Vor jedem Löschaufruf schreibt die App einen Protokolleintrag „beabsichtigt“, nach Erfolg „gelöscht“.
   So ist nach einem Abbruch klar, was passiert ist.
5. Jeder Fehler, jede Zeitüberschreitung, fehlende Berechtigung oder Unsicherheit → nicht löschen und
   Grund anzeigen.
6. Favoriten und Album-Zugehörigkeit werden als Warnung angezeigt, Favoriten sind nicht vorausgewählt.
7. Die App löscht nie von selbst oder im Hintergrund.

## 6. Bausteine

Zwei Teile, damit die Logik ohne iPhone testbar bleibt:

**`AufraeumerKern`** (Swift-Paket, ohne PhotoKit, läuft auf jedem Mac-Server):

- `Kandidat`, `Kategorie`, `Zustand`: Datenmodell.
- `Ablauf`: der Zustandsautomat mit den Regeln aus Abschnitt 5.
- `DuplikatFinder`: Gruppenbildung nach Größe, dann Prüfsumme.
- `Regeln`: Schwellen und Kategorienzuordnung.
- `Protokoll`: Einträge, Speicherformat (JSON und CSV).
- Schnittstellen `MedienBibliothek` (laden, Original exportieren mit Prüfsumme, löschen) und
  `Sicherung` (ablegen, Beleg, „hochgeladen?“).

**`App`** (SwiftUI, iOS 17+):

- `PhotoKitBibliothek`: setzt `MedienBibliothek` um; Größen über die Ressourcen der Assets; ausgeblendete
  Objekte nur mit Face-ID-Freigabe.
- `ICloudSicherung`: setzt `Sicherung` um. Ziel ist ein vom Nutzer einmal gewählter iCloud-Drive-Ordner
  (Ordnerauswahl, gespeicherte Lesezeichen). Fortschritt und Nachweis über
  `ubiquitousItemIsUploaded`.
- `SpeicherAnzeige`: frei/belegt über `volumeAvailableCapacityForImportantUsage`.
- Bildschirme: Übersicht → Auswahl → Sichern → Bestätigen → Bericht.
- Bericht enthält „Noch im Papierkorb“ mit Knopf zur Foto-App.

Keine Netzwerkzugriffe, keine Fremdbibliotheken, keine Statistik.

## 7. Bedienung (für Laien)

Ein Schließen-Zeichen verwirft nie etwas. Wo eine falsche Wahl möglich wäre, gibt es keine freie Eingabe,
nur Auswahllisten. Bei Problemen wählt die App den sicheren Weg selbst (nicht löschen) und sagt in
einem Satz warum. Eine kurze `ANLEITUNG.md` mit den drei nötigen Sätzen liegt bei.

## 8. Bau und Auslieferung

- Projekt wird mit **XcodeGen** (`project.yml`) beschrieben, das `.xcodeproj` entsteht auf dem Server.
- GitHub Actions auf macOS: `swift test` für `AufraeumerKern`, dann unsignierte `.ipa` als Artefakt.
- Ich hole die `.ipa` mit `gh`, der Nutzer installiert sie mit **Sideloadly** und der eigenen Apple-ID
  (Eingabe der Apple-ID nur durch den Nutzer).
- Ohne Entwicklerkonto: 7 Tage gültig, danach erneut signieren; höchstens 3 solcher Apps gleichzeitig.
- Fehlersuche ohne Mac: Absturzprotokolle und Systemmeldungen des iPhones per USB.

## 9. Tests

- Automatisch (auf dem Server): Zustandsautomat (jede Regel aus Abschnitt 5, auch die verbotenen
  Übergänge), Duplikatgruppen (nie die letzte löschen), Schwellen, Protokollformat.
- Auf dem iPhone: zuerst Probelauf ohne Löschen, dann ein Löschen einer einzelnen, bewusst gewählten
  Testdatei, erst danach echte Läufe.

## 10. Reihenfolge

| Stufe | Inhalt | Ergebnis |
|---|---|---|
| M0 Probe | Pipeline (XcodeGen, Server-Build, `.ipa`, Sideloadly) plus Mini-App: Testdatei nach iCloud Drive schreiben und `ubiquitousItemIsUploaded` beobachten; zählen, was PhotoKit sieht (auch ausgeblendet) und die größte Videogröße | Antwort, ob die Upload-Prüfung ohne Entwicklerkonto trägt |
| M1 Anzeigen | Scanner und Übersicht, nur lesen | Liste stimmt mit der Foto-App überein |
| M2 Sichern | Export, Prüfsumme, Upload-Nachweis | Testdatei prüfbar in iCloud Drive |
| M3 Löschen | Bestätigung, iOS-Abfrage, Protokoll | Einzelne Testdatei sicher gelöscht |
| M4 Feinschliff | Duplikate, Screenshots, Einstellungen, Anleitung | Nutzbar im Alltag |

## 11. Risiken und offene Punkte

- **Upload-Nachweis ohne Entwicklerkonto** ist erwartet, aber unbewiesen. M0 klärt das. Fällt er aus,
  bleibt „Sichern“ mit manueller Bestätigung je Lauf („Alle Dateien im Ordner zeigen kein Wolken-
  oder Fortschrittssymbol“), und Löschen bleibt sonst gesperrt.
- iCloud-Speicher: Die App kann den freien iCloud-Platz nicht abfragen. Bleibt der Upload aus, gilt
  Regel 5 (nicht löschen).
- Zugriff auf ausgeblendete Objekte per PhotoKit ist erwartet und wird in M0 geprüft.
- Gratis-Signatur: 7 Tage Laufzeit und 3-Apps-Grenze; ein bezahltes Entwicklerkonto würde beides beheben.
- Die installierte Xcode-Version auf dem Server kann sich ändern; der Workflow gibt sie aus und
  wird bei Bedarf angepasst.
