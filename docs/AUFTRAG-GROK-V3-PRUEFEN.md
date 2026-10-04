# Auftrag an Grok: Version 0.3 der Aufräum-App prüfen und auf Spitzenqualität bringen

Cursor hat gerade `docs\AUFTRAG-CURSOR-APP-V3.md` bearbeitet. Du bist der stärkste Agent im Team und machst daraus eine hochwertige App.

1. Lies den Auftrag, `docs\PLAN-V3.md`, `docs\ERGEBNIS.md`, `docs\STAND.md` und die Spec unter `docs/superpowers/specs/`.
2. Prüfe jeden Punkt des Auftrags am Code: erledigt, halb oder fehlt. Schreib das Ergebnis nach `docs\PRUEFUNG-GROK-V3.md`.
3. Behebe alles, was halb ist oder fehlt. Verbessere, was unklar ist. Der Maßstab: Ein Nichttechniker mit vollem iPhone 14 Pro Max versteht in zehn Sekunden, wie er Platz freibekommt, und es funktioniert mit Sideloadly und kostenloser Apple-ID.
4. Alle Tests müssen über GitHub Actions grün sein. Sieh dir die Bildschirmfotos aus dem Simulator-Lauf selbst an und korrigiere, was unklar, abgeschnitten oder englisch ist.
5. Pushen ist erlaubt, nur so und ohne Anmeldefenster: `git -c credential.helper= -c "credential.helper=!gh auth git-credential" push`. Das Repo ist öffentlich: keine Namen, Mails, Fotos oder Schlüssel ins Repo.
6. Lege die fertige IPA als `out\Aufraeumer.ipa` ab. Schreib `docs\ERGEBNIS.md` mit höchstens zehn Zeilen und zum Schluss die leere Datei `docs\APP-V3-GEPRUEFT.md`.
