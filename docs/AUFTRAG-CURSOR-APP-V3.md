# Auftrag an Cursor: hochwertige Aufräum-App (Version 0.3), die wirklich Speicher freimacht

Ordner: `C:\iphone-aufraeumer`, Zweig `entwicklung`. Grundlage: Version 0.2.0 (`docs\ERGEBNIS.md`), Spec unter
`docs/superpowers/specs/`. Den Kern (`AufraeumerKern`, 57 Tests) weiterverwenden.

## Rückmeldung des Nutzers zu 0.2.0

„Keine Ahnung, wie mir die App jetzt Speicherplatz bringen soll. Bei Schritt 2, iCloud-Drive-Upload, kann ich nicht
wirklich einen Ordner auswählen. Oder sonst irgendetwas.“ Er will eine hochwertige App. Er ist kein Techniker,
hat wenig freien Speicher auf seinem iPhone 14 Pro Max und installiert mit Sideloadly und kostenloser Apple-ID.

## Erst prüfen, dann bauen (Schritt 1, schriftlich in `docs\PLAN-V3.md`)

- Mit kostenloser Apple-ID gibt es keine iCloud-Berechtigung (kein eigener iCloud-Container, keine App Groups).
  Belege mit Quelle, ob die Sicherung in 0.2.0 deshalb nicht funktioniert. Sicherung darf nur Wege nutzen, die ohne
  Zusatzberechtigung gehen.
- Kläre und belege: Ist iCloud-Fotos eingeschaltet, löscht Löschen auch in der Cloud, und echter Platz entsteht erst
  nach dem Leeren von „Zuletzt gelöscht“. Die App muss das erkennen oder erfragen und klar erklären.
- Plane jeden Bildschirm in einem Satz: was der Nutzer sieht, welcher eine Hauptknopf, was danach passiert.

## Was Version 0.3 können muss

1. **Klarer Weg in vier Schritten**, oben immer sichtbar: Prüfen, Auswählen, Sichern, Löschen. Auf jedem Schritt steht
   in einem Satz, was er bringt, zum Beispiel „Das macht etwa 4,2 GB frei.“
2. **Sichern mit Ordnerwahl, die funktioniert:** Apples Ordnerauswahl der Dateien-App (Dokumentauswahl im Export-Modus).
   Damit kann der Nutzer iCloud Drive, „Auf meinem iPhone“, OneDrive oder einen USB-Stick wählen. Der gewählte Ordner
   wird gemerkt (Lesezeichen). Fortschritt pro Datei und gesamt in Prozent und Restzeit. Nach dem Kopieren wird jede
   Datei nach Größe geprüft. Erst was nachweislich gesichert ist, darf gelöscht werden. Sichern ist für Doppelte,
   Serienbilder und Bildschirmfotos abwählbar.
3. **Videos verkleinern** (größter Hebel): große Videos in HEVC 1080p neu speichern, Original danach löschen. Vorher
   anzeigen, wie viel das spart. Neue Datei behält Aufnahmedatum und Ort.
4. **Löschen** nur über die Fotos-Schnittstelle mit Apples Bestätigung. Danach eine Erfolgsseite mit „X GB frei
   geworden“ und einer bebilderten Kurzanleitung, wie man „Zuletzt gelöscht“ leert. Freier Speicher vorher und nachher.
5. **Tipps-Seite** für das, was eine App nicht selbst darf, jeweils mit Weg in den Einstellungen in einfachen Worten:
   „iPhone-Speicher optimieren“ bei iCloud-Fotos, ungenutzte Apps auslagern, große Anhänge in Nachrichten.
6. **Qualität:** deutsche Texte ohne Fachwörter, große Schaltflächen, ein Hauptknopf je Bildschirm, nie ein toter
   Knopf, jeder Fehler mit Grund und nächstem Schritt, Abbrechen jederzeit möglich ohne Datenverlust.

## Prüfen

- Neue Tests für jede neue Regel; alle Tests grün über GitHub Actions.
- Simulator-Lauf im CI mit Testfotos, der jeden Bildschirm fotografiert. Die Bildschirmfotos selbst ansehen und
  korrigieren, was unklar, abgeschnitten oder englisch ist. Ablage unter `docs\screenshots-v3\`.

## Grenzen

- Repo ist öffentlich: keine Namen, Mails oder Fotos des Nutzers ins Repo. Testfotos nur selbst erzeugte.
- Pushen in dieses Repo ist für diesen Auftrag erlaubt, ohne Anmeldefenster:
  `git -c credential.helper= -c "credential.helper=!gh auth git-credential" push`
  Baufehler selbst aus `gh run view <ID> --log-failed` lesen und beheben.

## Abschluss

- Vor jedem Schritt eine Zeile „Schritt N von M: …“ an `docs\STAND.md` anhängen.
- 0.2.0 als `out\Aufraeumer.0.2.0.ipa` sichern, die neue als `out\Aufraeumer.ipa` ablegen (Heimserver Anschluss 8098).
- `docs\ERGEBNIS.md` höchstens zehn Zeilen, dazu eine Kurzanleitung für den Nutzer in fünf Sätzen.
- Zum Schluss leere Datei `docs\APP-V3-FERTIG.md`.
