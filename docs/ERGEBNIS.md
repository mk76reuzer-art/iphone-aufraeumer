# Ergebnis verbesserte App (0.2.0)

Die App zeigt beim Start freien und belegten Speicher in großen Zahlen, listet Aufräum-Vorschläge in fünf Gruppen mit Größe in Gigabyte und Vorschaubildern, und wählt nur sichere Kandidaten vor (Duplikate, Serien, alte Bildschirmfotos).
Große Videos und alte Aufnahmen werden nach iCloud Drive gesichert mit Fortschrittsanzeige; gelöscht wird nur über die Fotos-Schnittstelle mit Apple-Bestätigung, danach Hinweis zu „Zuletzt gelöscht“.
Kern-Tests: 57 bestanden (GitHub Actions Lauf 37235012485). IPA: `out/Aufraeumer.ipa`, etwa 199 Kilobyte (unsigniert).
Offen: Ausgeblendete Fotos brauchen ggf. extra Freigabe in den iOS-Einstellungen; Upload-Prozent nur grob während iCloud lädt; echte Nutzung auf dem iPhone durch Manuel noch nicht protokolliert.
