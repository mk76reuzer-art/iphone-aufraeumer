# Vorrang-Auftrag an Grok: Die App muss nachweislich Speicherplatz freimachen

Der Nutzer, wörtlich und sehr verärgert: „Ich kann damit immer noch keinen Speicherplatz gewinnen.“ Schöne Oberfläche reicht nicht. Der einzige Maßstab ist: **Nach dem ersten Öffnen hat der Nutzer in höchstens zwei Minuten nachweislich Gigabytes frei, gemessen am freien iPhone-Speicher vorher und nachher.**

## Punkt 0: belegte Hauptursache, zuerst beheben

Der Nutzer hat ein Bildschirmvideo geschickt, Stand der IPA vom 04.10. um 23:48. Zu sehen ist „15 GB frei von 119 GB“. **Jede Gruppe zeigt „Nichts gefunden“, auch Bildschirmfotos.** Unter Auswählen steht „Markiert: 0“, und „Weiter“ bleibt grau. Eine Fehlermeldung zum Fotozugriff gibt es nicht. Der Zugriff ist also erteilt, und der Scan lief.

Ursache im Code, `App\PhotoKitBibliothek.swift` Zeile 79 und 80:
`res.responds(to: NSSelectorFromString("locallyAvailable"))`

Der Getter der privaten Eigenschaft heißt vermutlich `isLocallyAvailable`. Die Prüfung mit `responds(to:)` ist deshalb immer falsch, und `lokal` bleibt bei jedem Foto `false`. Die Folge:

- `MediathekScanner.swift` Zeile 57 setzt die Größe auf 0.
- `Regeln.kategorien` gibt in Zeile 15 sofort `[]` zurück, weil `guard k.istLokalVorhanden, k.groesseBytes > 0`.
- So wird nie etwas gefunden.

Behebe das robust:

- Prüfe beide Selektoren (`isLocallyAvailable` und `locallyAvailable`). KVC nie ohne Prüfung aufrufen, sonst gibt es eine NSUnknownKeyException.
- Lässt sich nicht feststellen, ob ein Foto auf dem iPhone liegt, gilt es als vorhanden, mit der echten `fileSize`.
- Bildschirmfotos, Doppelte und Serien werden immer gezählt und angezeigt. Ob ein Foto nur in iCloud liegt, steht als Hinweis dabei und schließt es nicht aus.
- Zeigt das Prüfen bei einer Mediathek mit Fotos trotzdem null Treffer, ist das ein Fehler. Dann muss die App das sagen und den Speicher-Bericht anbieten, statt still „Nichts gefunden“ zu zeigen.

**Beweis im CI:** `scripts\simulator-bilder.sh` darfst du ändern, `.github/workflows` nicht. Spiel im Simulator mit `xcrun simctl addmedia` Testbilder ein, darunter ein Bildschirmfoto, zwei gleiche Bilder und ein Video über der Schwelle für große Videos. Der UI-Lauf muss zeigen, dass „Prüfen“ sie findet. Leg das Bildschirmfoto davon als Beleg ab. Ohne diesen Beleg gilt der Auftrag als nicht erledigt.

## Erst die Ursache finden (schriftlich in `docs\WARUM-KEIN-PLATZ.md`)

Geh jeden Weg durch, auf dem ein Nutzer mit vollem iPhone 14 Pro Max, Sideloadly und kostenloser Apple-ID heute keinen Platz gewinnt. Belege jeden Punkt am Code und mit Quellen. Mindestens diese:

1. Die Sicherung ist Pflicht und scheitert, zum Beispiel am Ordnerzugriff, an fehlendem Platz für die Kopie oder an einem langsamen Hochladen. Dann wird nichts gelöscht.
2. Gelöschtes landet in „Zuletzt gelöscht“. Freier Platz entsteht erst nach dem Leeren, und die App sagt das nicht deutlich genug.
3. Bei eingeschaltetem iCloud-Fotos mit „iPhone-Speicher optimieren“ liegen auf dem iPhone nur kleine Vorschauen. Löschen bringt dann fast nichts und löscht zugleich in der Cloud.
4. Die Regeln finden zu wenig, weil die großen Brocken nicht dabei sind: lange Videos, große Videos, Live-Fotos, RAW und ProRAW, Bildschirmaufnahmen als Video, WhatsApp-Videos in den Fotos.
5. Der größte Teil des Speichers liegt gar nicht in Fotos, sondern in Apps, Nachrichten oder Systemdaten. Darauf hat die App keinen Zugriff.

## Dann umbauen

1. **Startseite „Speicher-Bilanz“:**
   - Freier Speicher, belegter Speicher, Größe der Fotomediathek auf dem iPhone (lokal, mit `PHAssetResource`), davon Videos.
   - Dazu ein ehrlicher Satz, zum Beispiel: „Fotos und Videos belegen 38 GB. Davon kann diese App etwa 21 GB freimachen.“ Oder: „Deine Fotos belegen nur 4 GB. Der meiste Platz liegt in Apps und Nachrichten. So räumst du dort auf: …“
2. **Größte Brocken zuerst:** eine nach Größe sortierte Liste der größten Videos und Dateien mit Vorschau und Größe. Antippen heißt auswählen. Ein Hauptknopf: „X GB freimachen“.
3. **Sicherung freiwillig:** Sie wird empfohlen und bleibt anwählbar, ist aber keine Pflicht. Ohne Sicherung kommt eine klare Warnung mit einem Bestätigungsknopf. Doppelte, Bildschirmfotos und Serienbilder ohne Sicherung, wie bisher.
4. **Nach dem Löschen:**
   - Erst den freien Speicher messen. Hat er sich nicht verändert, sofort sagen: „Jetzt noch Zuletzt gelöscht leeren, dann sind die X GB frei.“
   - Ein Knopf öffnet die Fotos-App (`photos-redirect://`). Dazu eine bebilderte Drei-Schritte-Anleitung.
   - Kommt der Nutzer zurück, wieder messen und den Erfolg zeigen.
5. **iCloud-Fotos:** Die Frage bleibt. Ist es an, wird zuerst „iPhone-Speicher optimieren“ empfohlen, mit Weg und Hinweis, dass Löschen auch in der Cloud löscht.
6. **Knopf „Speicher-Bericht kopieren“:** ein Text ohne Dateinamen und Personendaten. Inhalt: freier Speicher, Mediathek-Größe, Anzahl und Größe je Gruppe, iCloud-Antwort, letzter Lauf mit Fehlern. So kann der Nutzer ihn Claude schicken.
7. Alles andere aus 0.3 bleibt erhalten.

## Prüfen und abliefern

- Neue Regeln mit Tests. Der CI-Lauf muss grün sein. Warte selbst mit `gh run watch <ID> -R mk76reuzer-art/iphone-aufraeumer --exit-status`. Ist er rot, behebe es und wiederhole das, bis er grün ist.
- Bildschirmfotos ansehen, Unklares korrigieren.
- `.github/workflows` nicht ändern. Pushen nur mit `git -c credential.helper= -c "credential.helper=!gh auth git-credential" push`. Das Repo ist öffentlich: keine Personendaten.
- IPA aus dem grünen Lauf als `out\Aufraeumer.ipa` ablegen, die Version auf 0.4.0 setzen und `docs\ERGEBNIS.md` erneuern.
- Zum Schluss die leere Datei `docs\APP-V4-FERTIG.md`.
