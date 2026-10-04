# Prüfung Version 0.3

Stand vor der Nacharbeit: der gemeldete Lauf 37237412181 hatte 62 Kerntests und eine IPA. Die Oberfläche war da, mehrere Zusagen aus dem Auftrag waren nur halb oder gar nicht erfüllt.

## Befund

Vier Schritte oben: erledigt. Der Nutzen-Satz war halb, weil eine Datei in zwei Gruppen doppelt in die Summe einging und die Zahl mit Punkt statt Komma erschien.

Ordnerwahl: halb. Die Dateien-App wurde geöffnet, der Zugriff auf den Ordner endete aber, bevor die Kopie geprüft wurde. Das Lesezeichen wurde ohne gültigen Zugriff gespeichert. Der Fortschritt zählte Dateien erst nach dem Hochladen, nicht während des Kopierens. Die Prüfung lud jede Datei komplett in den Arbeitsspeicher. Auf einem vollen iPhone kann das scheitern oder die App beenden. Die Schalter für Doppelte, Serien und Bildschirmfotos wirkten im Kern, in der App aber nicht, weil diese Gruppen bei der Entscheidung fehlten.

Videos verkleinern: halb. Kleinere Qualität, Datum und Ort waren im Code. Die Schätzung davor auch. Das Original wurde erst nach einer zweiten vollen Kopie gelöscht. Lehnte man die Frage ab, blieb die kleine Fassung zusätzlich liegen. Eine Prüfung, ob genug Platz frei ist, fehlte. Die Fehlermeldung sagte Video(s).

Löschen nur über die Fotos-Schnittstelle: erledigt. Die Erfolgsseite zeigte vorher und nachher, hatte aber zwei gleich starke Knöpfe. Die Anleitung zu Zuletzt gelöscht war klein.

Tipps: halb. Die Wege standen im Text. Die Knöpfe nutzten eine Adresse, die das iPhone bei fremden Apps nicht öffnet. Ein toter Knopf.

Qualität: halb. Abbrechen während des Laufs ging nicht. Ein Favorit ließ sich ankreuzen und scheiterte danach ohne Extra-Frage. Nach einem fehlgeschlagenen Prüfen war Auswählen tot. Nicht jeder Fehler nannte den nächsten Schritt.

Tests: die neuen Kernregeln waren dünn geprüft. Simulator-Bilder fehlten. Der Ablauf dafür lag nur als Entwurf unter docs, nicht im echten Workflow. Bildschirmfotos konnten deshalb nicht angesehen werden.

iCloud-Fotos: erledigt als einmalige Frage. Auslesen des Schalters geht nicht, das steht im Plan mit Quellen.

Sicherung mit kostenloser Apple-ID: der Plan belegt, dass ein eigenes iCloud-Fach mit dem persönlichen Team nicht geht. Version 0.3 nutzt deshalb nur einen Ordner, den man in der Dateien-App selbst wählt.

## Nacharbeit in diesem Stand

Der Ordnerzugriff bleibt bestehen, bis die Sicherung endet. Die Kopie wird in Stücken geschrieben und per Prüfsumme verglichen, ohne die ganze Datei in den Speicher zu laden. Doppelte, die nicht geprüft werden können, weil zu wenig Platz frei ist, werden ausgelassen und benannt.

Der Lauf meldet Kopieren, Prüfen, Cloud und Löschen. Abbrechen ist auf dem Fortschritt möglich. Bis zum Löschen wird nichts gelöscht.

Videos werden kleiner gespeichert und das Original in demselben Schritt entfernt. Lehnt man ab, bleibt nur das Original. Fehlt Platz, sagt die App wie viel fehlt und was zu tun ist.

Die Summe zählt jede Datei einmal. Die Zahlen nutzen ein Komma. Je Bildschirm gibt es einen Hauptknopf. Fehler nennen den nächsten Schritt. Favoriten brauchen einen eigenen Schalter. Tipps haben keine toten Knöpfe mehr, nur den Weg in einfachen Sätzen.

Neue Tests: Prüfsumme in Stücken, Kopie, Summe ohne Doppelzählung, Schalter für Serien und Bildschirmfotos, Reihenfolge des Fortschritts, deutsches Komma bei 4,2 GB.

Die Workflow-Datei lässt sich mit dem vorhandenen Zugang nicht ändern. GitHub verlangt dafür eine extra Berechtigung, und ein Anmeldefenster ist nicht erlaubt. Die Bildschirmfotos entstehen deshalb im bestehenden IPA-Bau, bevor das Paket gepackt wird. Sie liegen in der IPA im Ordner SimulatorBilder. Nach dem Lauf werden sie angesehen und, falls etwas abgeschnitten oder englisch ist, korrigiert.
