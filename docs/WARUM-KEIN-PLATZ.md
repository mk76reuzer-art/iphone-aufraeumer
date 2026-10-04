# Warum bisher kein Platz frei wurde

Stand 05.10.2026. Gemessen am Bildschirmvideo der IPA vom 04.10. um 23:48: 15 GB frei von 119 GB, jede Gruppe „Nichts gefunden“, auch Bildschirmfotos, unter Auswählen „Markiert: 0“, Weiter grau, keine Meldung zum Fotozugriff. Der Zugriff war erteilt, der Scan lief.

## Die Hauptursache

Die App hat jedes Foto für nicht auf dem iPhone liegend gehalten.

In `PhotoKitBibliothek` wurde nur der Selektor `locallyAvailable` geprüft. Der private Getter heißt auf dem Gerät `isLocallyAvailable`. `responds(to:)` war deshalb falsch, der Wert blieb falsch, und `value(forKey:)` wurde nicht aufgerufen. Das ist richtig so, denn ein Aufruf ohne Prüfung wirft eine Ausnahme.

Danach setzte der Scanner die Größe auf 0 und `istLokalVorhanden` auf falsch. `Regeln.kategorien` brach sofort mit einer leeren Liste ab, sobald das Foto nicht als lokal galt oder die Größe 0 war. Doppelte und Serien filterten dieselben Bedingungen. Deshalb stand überall „Nichts gefunden“, obwohl Bildschirmfotos da waren.

Ab 0.4.0 werden beide Selektoren geprüft, und Schlüssel nur nach `responds(to:)` gelesen. Lässt sich nicht feststellen, ob die Datei auf dem iPhone liegt, gilt sie als vorhanden, mit der echten `fileSize`. Bildschirmfotos, Doppelte und Serien werden gezählt. Nur-iCloud bleibt sichtbar und ist als Hinweis markiert, zählt aber nicht in die Gigabytes, die der Knopf freimachen will. Findet das Prüfen bei einer Mediathek mit Einträgen trotzdem keine Größe, sagt die App das und bietet den Speicher-Bericht an.

## Fünf weitere Wege, auf denen heute kein Platz frei wird

### 1. Die Sicherung war Pflicht und ist oft gescheitert

Große Videos und alte Aufnahmen verlangten den Modus „erst sichern“. `SicherungsOptionen` hat das fest eingestellt. `Loeschlauf` kopiert in diesem Modus zuerst, prüft die Größe und wartet bis zu 600 Sekunden auf das Hochladen (`warteAufUpload`). Erst danach darf gelöscht werden. Schlägt ein Schritt fehl, bleibt die Datei liegen.

Drei typische Abbrüche:

Der Ordner lässt sich nicht öffnen. `ICloudSicherung` bricht ab, wenn `startAccessingSecurityScopedResource` falsch ist (`OrdnerFehler.keinZugriff`). Eine kostenlose Apple-ID signiert nur über das Personal Team. Das Team kann keinen eigenen iCloud-Container für die App anlegen. Quellen: [Apple QA1915](https://developer.apple.com/library/archive/qa/qa1915/_index.html), [Zugriff nach Kontotyp](https://developer.apple.com/help/account/access/resolving-access-issues/). Die App kopiert deshalb nur in einen Ordner, den der Nutzer in der Dateien-App wählt.

Auf dem vollen iPhone fehlt der Platz für die Kopie. Der Export wirft `DateiKopieFehler.zuWenigPlatz`, wenn das System `NSFileWriteOutOfSpaceError` meldet. Dann wird nicht gelöscht. Wer 15 GB frei hat und ein großes Video kopieren will, scheitert oft genau daran.

Das Hochladen in die Cloud ist langsam oder kommt nicht an. Nach 600 Sekunden wirft der Lauf „Upload nicht rechtzeitig fertig“. Auch dann wird nichts gelöscht.

Sideloadly mit kostenloser Apple-ID hält eine App etwa sieben Tage und erlaubt höchstens drei solche Apps. Quelle: [Sideloadly](https://sideloadly.io/). Das ändert nichts am Speicher, erklärt aber, warum ein bezahlter iCloud-Container für diese App nicht zur Verfügung steht.

Ab 0.4.0 ist die Sicherung empfohlen und abwählbar. Ohne Sicherung gibt es eine klare Warnung und den Knopf „Ohne Sicherung löschen“. Doppelte, Bildschirmfotos und Serien bleiben ohne Sicherung, wie bisher.

### 2. Gelöschtes liegt in Zuletzt gelöscht

`PhotoKitBibliothek.loeschen` ruft nur `PHAssetChangeRequest.deleteAssets` auf. Das verschiebt die Dateien in das Album Zuletzt gelöscht. Frei wird der Speicher erst, wenn dieses Album geleert wird, in der Regel nach 30 Tagen oder nach „Alle löschen“. Quellen: [Fotos löschen, Apple Support](https://support.apple.com/de-de/104967), [iCloud-Fotos](https://support.apple.com/de-de/108782).

Die alte Erfolgsseite zeigte den Unterschied vorher und nachher, sagte aber nicht den Satz, den man in dem Moment braucht. Ab 0.4.0 misst die App den freien Speicher direkt nach dem Löschen. Hat er sich nicht verändert, steht da: „Jetzt noch Zuletzt gelöscht leeren, dann sind die X GB frei.“ Ein Knopf öffnet die Fotos-App über `photos-redirect://`. Drei bebilderte Schritte erklären den Weg. Kommt man zurück, wird erneut gemessen.

### 3. iCloud-Fotos mit iPhone-Speicher optimieren

Ist „iPhone-Speicher optimieren“ an, liegen auf dem iPhone kleine Vorschauen. Die großen Originale liegen in iCloud. Quelle: [Speicher für Fotos verwalten](https://support.apple.com/de-de/105061) und [iCloud-Fotos, Speicher optimieren](https://support.apple.com/de-de/108782).

Löschen entfernt dann fast keinen Gerätespeicher und löscht das Foto zugleich in der Cloud und auf den anderen Geräten. Die App kann den Schalter nicht auslesen. Sie fragt einmal. Sagt der Nutzer ja, kommt zuerst der Weg zu „iPhone-Speicher optimieren“, plus der Hinweis, dass Löschen auch die Cloud trifft.

### 4. Die Regeln haben die großen Brocken verfehlt

Bisher gab es große Videos ab 50 MB, Aufnahmen, die zwei Jahre unberührt sind, Doppelte, Serien und Bildschirmfotos erst nach 90 Tagen. Nicht dabei waren lange Videos unter 50 MB, Live-Fotos, RAW und ProRAW, Bildschirmaufnahmen und WhatsApp-Videos in der Fotomediathek (`VID-…-WA….mp4` und Dateien mit WhatsApp im Namen).

Dazu kam die falsche Lokal-Erkennung: selbst ein altes Bildschirmfoto fiel heraus, weil die Größe auf 0 gesetzt wurde.

Ab 0.4.0 zählen diese Gruppen mit. Bildschirmfotos zählen immer, nicht erst nach 90 Tagen. Tests stehen in `RegelnTests` und `SerienFinderTests`.

### 5. Der meiste Speicher liegt oft gar nicht in Fotos

Die App darf nur die Fotomediathek lesen und darüber löschen. Die Berechtigung steht in `NSPhotoLibraryUsageDescription`. Es gibt keinen Zugriff auf andere Apps, auf Nachrichten oder auf Systemdaten. Was dort liegt, kann diese App nicht löschen. Quelle: [Apple, Speicher prüfen](https://support.apple.com/de-de/105061).

Die Startseite sagt das, wenn die Fotos nur wenig vom belegten Speicher ausmachen, und verweist auf die Tipps: iPhone-Speicher optimieren, selten genutzte Apps auslagern, große Anhänge in Nachrichten.

## Was der Nutzer danach sehen soll

Die Startseite heißt Speicher-Bilanz. Sie zeigt freien Speicher, belegten Speicher und die Größe der Fotos und Videos, die wirklich auf dem iPhone liegen, davon die Videos. Darunter die größten Dateien, antippen wählt aus, ein Knopf „X GB freimachen“. Der Speicher-Bericht enthält Zahlen und Gruppen, keine Dateinamen und keine Personendaten.
