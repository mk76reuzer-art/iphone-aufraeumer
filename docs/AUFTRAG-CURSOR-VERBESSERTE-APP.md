# Auftrag an Cursor: eine wirklich brauchbare iPhone-Aufräum-App bauen

Ordner: `C:\iphone-aufraeumer` (Swift, Zweig `entwicklung`). Vor allem zuerst lesen:
`docs/superpowers/specs/2026-09-29-iphone-aufraeumer-design.md` (Spec) und
`docs/superpowers/plans/2026-09-29-fundament-und-probe.md` (bisheriger Plan).

## Ausgangslage

Die bisherige IPA (`out\Aufraeumer.ipa`, 29.09.2026) ist nur eine Probe. Der Nutzer hat sie ausprobiert und sagt:
„Keine Ahnung, ob die App nicht funktioniert oder einfach schlecht aufgebaut ist.“ Er will jetzt eine verbesserte,
fertig benutzbare App. Er hat wenig freien Speicher auf seinem iPhone 14 Pro Max und ist kein Techniker.

## Was die App können muss

1. Beim Start sofort zeigen, wie voll das iPhone ist und was am meisten Platz frisst, in großen, klaren Zahlen.
2. Aufräum-Vorschläge in Gruppen, jede mit Größe in GB: große Videos, doppelte Fotos, sehr ähnliche Serienbilder,
   Bildschirmfotos, alte Aufnahmen. Vorschaubilder, alles vorausgewählt nur, wo es sicher ist.
3. Vor dem Löschen eine Sicherung nach iCloud Drive (so mit dem Nutzer vereinbart, nicht Google, nicht OneDrive),
   mit echtem Fortschritt in Prozent. Gelöscht wird nur, was nachweislich gesichert ist.
4. Löschen nur über die Fotos-Schnittstelle von Apple, also mit Apples eigener Bestätigung. Nichts ohne Bestätigung.
   Danach anzeigen, wie viel Platz frei geworden ist, und daran erinnern, „Zuletzt gelöscht“ zu leeren.
5. Oberfläche komplett auf Deutsch, ohne Fachwörter, große Schaltflächen, ein Hauptknopf je Bildschirm.
   Jede Wartezeit mit Fortschritt; jeder Fehler mit klarer Meldung, was passiert ist und was man tun kann.
6. Den vorhandenen Kern (`AufraeumerKern`: Regeln, Duplikate, Zustandsautomat, Protokoll, Löschlauf, 53 Tests)
   weiterverwenden, nicht wegwerfen. Bestehende Tests bleiben grün, neue Funktionen bekommen neue Tests.

## Grenzen

- Das Repo ist öffentlich: keine Namen, Mails, Dateinamen oder Fotos des Nutzers ins Repo.
  Git-Autor ist die GitHub-noreply-Adresse.
- Kein Mac auf diesem PC. Gebaut und getestet wird über GitHub Actions. Pushen darfst du für diesen Auftrag in dieses
  Repo, und zwar ohne Anmeldefenster:
  `git -c credential.helper= -c "credential.helper=!gh auth git-credential" push`
  (Hilfsskript: `.superpowers\pushwatch.ps1 -Nachricht "..."`, committet, pusht und wartet auf CI.)
- Baufehler selbst aus dem CI-Protokoll lesen (`gh run view <ID> --log-failed`) und beheben.

## Fortschritt und Abschluss

- Vor jedem Schritt eine Zeile „Schritt N von M: …“ an `docs\STAND.md` anhängen.
- Die fertige IPA aus dem CI holen. Die alte Probe als `out\Aufraeumer.probe.ipa` sichern, die neue als
  `out\Aufraeumer.ipa` ablegen. Diese Datei liefert der Heimserver auf Anschluss 8098 direkt aus.
- `docs\ERGEBNIS.md` mit höchstens zehn Zeilen: was die App jetzt kann, Testergebnis, Größe der IPA, was offen ist.
- Zum Schluss leere Datei `docs\VERBESSERTE-APP-FERTIG.md`.
