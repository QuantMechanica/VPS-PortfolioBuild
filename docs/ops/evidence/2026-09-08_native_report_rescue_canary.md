# Native HTML-Export-Rettung: T1-Canary

Stand: 2026-09-08, Umsetzung nach OWNER-Auftrag „gut, wenn es sich was bringt, dann umsetzen“.

## Ergebnis und genaue Abgrenzung

Implementiert und auf **T1** zeitlich begrenzt aktiviert: Ein einmaliger nativer HTML-Exportversuch, wenn der frisch gestartete, exakt zugeordnete Tester nachweislich fertig ist, kein Bericht existiert und Agent-CPU sowie beide Journale mindestens 60 Sekunden unverändert geblieben sind. Maximal 30 Sekunden Hilfsprozess; normaler Report-Latch, Real-Tick-Nachweis, Setfile-/EX5-Nachweise, Logger-Sicherung, Gate-Prüfungen und vorhandene Wiederholungsregeln bleiben zuständig. Keine Verkürzung des 600-Sekunden-Stallbudgets, kein synthetischer Bericht und kein PASS aus Engine-Fertigmeldungen.

**Nicht aktiviert:** dauerhafter Factory-Warmbetrieb, auch nicht zwischen Aufträgen. Das native Warmverfahren ist im T11-Labor schneller, aber Windows-Job-Object-Eigentum, History-Vorbereitung und frische QM-Logger-Erfassung müssen für Wiederverwendung gesondert integriert und mit echten QM-EAs qualifiziert werden. Viele aktuelle OPT_CENSUS- und Q02-Aufträge haben Runs=1; Warmhaltung nur innerhalb eines solchen Auftrags bringt dort keinen Nutzen. Deshalb wird zuerst der separate Exportengpass angegangen.

Policy: `framework/registry/mt5_native_report_rescue.json`, ausschließlich T1, Terminal-Binary SHA-256 `bd1d438bc7563a57ba4496dbde994eac207d1ab71c8864e5093bfe721dd960ab` (beobachteter Build 6182). Automatischer Ablauf **2026-09-09 22:00 UTC = 2026-09-10 00:00 Wien**. Rücknahme: `enabled=false`; der Helfer prüft die Policy unmittelbar vor einer Aktion erneut. Keine laufenden Factory-Terminals wurden für den Rollout beendet.

## Neue Laborbelege

Session: `D:\QM\mt5\T11\latency_lab_20260908\experiments\warmrollout_20260908`.

- Der manuell angestoßene, native Tester-HTML-Export ist vollständig gleichwertig zum klassischen nativen HTML: für Fixture A **alle 295 Tabellenzeilen/Zellen** identisch, nicht nur Gewinn und Tradezahl. Abweichende Berichtsnamen/Grafiklinks erklären unterschiedliche Datei-Hashes; die fachlichen Tabelleninhalte sind exakt gleich.
- A → B → A mit unveränderter Moving-Average-EX5, EURUSD, M5, Model 4, lokaler Agent, kein Visual/Cloud/Remote. A: 01.–05.09.2026; B: 02.–05.09.2026. Jeder native HTML-Bericht entspricht seinem eigenen Kaltstart-Vergleich.
- Vom warmen Teststart bis zum vollständigen nativen HTML: **5,765 / 4,125 / 3,922 Sekunden**. Das sind kurze Laborfixtures, keine gemessene Beschleunigung des gesamten Factory-Durchsatzes.
- Native Exportzeiten darin: 4,125 / 3,297 / 3,047 Sekunden. Alle Kennzahlen, Inputs und Orders-/Deals-Tabellen bleiben nativ. Der problematische MCP-JSON-Gross-Loss-Wert wird nicht verwendet.
- Zusätzlich wurde der Identitäts-/Input-Prüfer an einem unveränderten echten Factory-Bericht von QM5_41163 / USDCAD.DWX / D1 / 2024 und seinem exakten Setfile geprüft: **37 native Inputs**, PASS. Dies ist Parser-Qualifikation, ausdrücklich **kein** echter QM-EA-Warmtest.

Relevante Belege: `native_html_control_probe.json`, `native_auto_tab_a.json`, `native_html_aba.json` sowie ihre nativen HTML-Dateien. Die Vergleichsdateien liegen im bestehenden Laborroot: `warmcold.htm`, `switchbcold.htm`.

## Technische Umsetzung

1. `mt5_native_html_export.py`: ausschließlich PID-gebundene native Kontrollnachrichten. Tester-Tab über Sieben-Tab-Layout und Tester-Ledger identifiziert; kein Toolbox-/Live-History-Zugriff. HTML-Menübefehl 33420. Der moderne Speicherdialog benötigt echtes Editieren per EM_REPLACESEL und seinen Save-Button; bloßes WM_SETTEXT/WM_COMMAND kann den alten Standardnamen verwenden. Exakter Dateinamen-Readback, neue Zieldatei, keine Überschreibbestätigung, 20-Sekunden-Exportbudget, 64-MiB-Leserlimit.
2. `mt5_report_rescue.py`: direkte Kindbeziehung zum lebenden run_smoke-Eigentümer, Prozessstartzeit und Executable-Pfade von Terminal/Agent, aktive Work-Item-Bindung, aktuelle native Engine-Fertigmeldung, festes Build, identische INI/EX5/Setfile-Fingerprints. Der native Bericht muss Expert, Symbol, Zeitraum, Währung, Deposit, Hebel, komplette erforderliche Metriken und alle gesetzten Inputs bestätigen. Unbekannte alte Setfile-Einträge führen vorsichtshalber zur Ablehnung der Rettung.
3. Export in eine neue native Geschwisterdatei. Nach Prüfung atomare, nicht überschreibende Veröffentlichung per Hardlink. Beide nativen HTML-Artefakte und die originalen Grafikdateien bleiben erhalten. Taucht inzwischen der normale Bericht auf, bleibt er unangetastet. Die existente HTML-Latch-/Logger-Strecke verarbeitet anschließend den Bericht wie zuvor.
4. `run_smoke.ps1`: nur einmaliger optionaler Canary-Helfer. Pro Run Policy-Snapshot und sichtbare Stage-Markierung. Fehler der optionalen Policy oder des Helfers ersetzen keine vorhandene Qualitätsentscheidung. Fehlerartefakte bleiben im Run-Verzeichnis.
5. `mt5_warm_lab.py`: getrennte benannte Sessions inklusive Watchdog-/Close-Zuordnung; Reportnamen nicht mehr auf die alte Session hart codiert.

Es wird kein Factory-MCP-Endpoint geöffnet, kein Account-/Trading-Aufruf verwendet und AutoTrading nicht verändert. Live-Terminals sind schon durch die Root-Allowlist ausgeschlossen.

## Verifikation und Grenzen

**69 gezielte Tests PASS:** neuer Export-/Policy-/Input-/Prozessschutz plus vorhandene Warm-Lab-, Report-Finalization-, Logger- und Empty-Tester-Log-Regression. Geprüft werden unter anderem PID-Wiederverwendung, falscher Owner/Agent/Auftrag, EX5-Wechsel, geänderte Inputs während des Exports, alte Journale, frühes Eingreifen, vorhandene Report-Shells, Parallelveröffentlichung sowie deaktivierte/abgelaufene Policy. PowerShell wird dabei nativ geparst; der bestehende 600-Sekunden-Watch bleibt getestet.

Factory-Nachweis: neuer T1-Run `9aa91157-e7aa-5c8b-a170-b2394ce832d2`, QM5_41301, Terminal-PID 13780, Start 23:23:35 Wien. Sein kanonisches Runnerlog enthält `native_report_rescue_canary_armed`. Regulär abgeschlossen: nativer Bericht 125.380 Bytes, 446 Logger-Ereignisse / 156.735 Bytes, run_smoke PASS, Factory-Zeile done / MEASURED. Report-First-Byte 2,127 Sekunden nach nativem Engine-Ende. Der Canary griff mangels Stau **nicht** ein. Dies beweist Aktivierung und unveränderten Normalpfad, noch **keine** erfolgreiche Rettung eines echten Produktionshängers oder eine Produktions-Zeitersparnis.

Beobachtung: `D:\QM\reports\diagnostics\native_rescue_canary_20260908_2324.jsonl`, 23:23:11 bis 23:28:12 Wien, 15-Sekunden-Takt. Kein erkannter, frisch zugeordneter Post-Engine-Stau über 60 Sekunden und kein Observerfehler. Abschluss und Hashes stehen in `2026-09-08_native_report_rescue_canary.json`. Ein ausbleibender Hänger bedeutet nicht, dass der Nutzen im Produktionsbetrieb bereits gemessen wurde.

Wichtige Restqualifikation: absichtliche Fehlerfälle mit dem realen nativen Dialog und vollständiger Wiederanlaufstrecke; ein echter Factory-Hänger, der erfolgreich gerettet und anschließend durch sämtliche normalen Qualitätsprüfungen verarbeitet wird; große Berichte; echte QM-EA-Warmtests mit frischem, deterministischem Logger sowie Setfile-/EA-/Symbolwechsel. Eine nicht reagierende native UI kann auch die Rettung ablehnen; der bestehende Retry bleibt erforderlich. Keine globale Warmfreigabe aus diesem Canary ableiten.

## Aufräumen und Sicherheit

T11-Laborterminal und sein exakt zugeordneter Tester um 23:16:45 Wien beendet; ursprüngliche MCP-Konfiguration wiederhergestellt. T11 prozessfrei, eigene Diagnosereservierung nach Eigentümer-/DB-/Prozessprüfung freigegeben. Worker-Policy weiterhin T1–T10. Geschützte Live-PIDs 15464 (FTMO) und 31728 (T_Live) unverändert.

Fünf während der Dialogdiagnose neu erzeugte Report-/PNG-Dateien aus `D:\QM\console_design_20260907` wurden anhand ihrer exakten Namen und Erstellungszeit identifiziert und **verlustfrei verschoben** nach `<Session>\recovered_default_export`. Keine fremden Berichte gelöscht oder überschrieben. Unabhängige vorhandene Änderungen an QM5_41240 und der früheren Infrastruktur-Triage bleiben unangetastet.
