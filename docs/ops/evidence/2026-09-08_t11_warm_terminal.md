# T11: Warmterminal, native Berichte und schnellere Backtests

Stand: 8. September 2026, 22:24 Wien/Berlin. Status: Experiment bestanden; noch keine Produktionsfreigabe.

## Entscheidung

Die nächste Performance-Priorität ist ein dauerhaft geöffnetes MT5 je Worker mit nativ gesteuerten Tester-Jobs und explizitem Berichtsexport. Das vermeidet insbesondere wiederholte Anmeldung und Terminalinitialisierung. Auf T11 wurde dafür ein isolierter, ausführbarer Prototyp gebaut und gemessen. Factory-Runner, Gate-Anforderungen und Live-Trading wurden in diesem Experiment nicht geändert.

T11 bleibt Versuchsterminal, außerhalb der Factory-Worker T1–T10. Getestet wurde nur die bereits vorhandene, getrennte Installation unter D:\QM\mt5\T11\latency_lab_20260908. Das ursprüngliche T11 mit Build 6140 wurde nicht gestartet oder aktualisiert; das Labor verwendet den bereits vorhandenen Produktionsbuild 6182.

## Gemessene Ergebnisse

Fixture A: unverändertes MetaQuotes-Beispiel Moving Average, EURUSD M5, 01.–05.09.2026, Model 4 / reale Ticks, Visual=0, Optimization=0, lokale Agents, keine Cloud/Remote-Agents, 100.000 USD, Hebel 1:100.

| Variante | Wiederholungen | Messwerte in Sekunden | Median |
|---|---:|---|---:|
| Frischer Terminalstart → HTML erstmals beobachtet | 3 | 48,946 / 11,617 / 20,338 | 20,338 |
| Terminal bleibt offen, normales Fenster → vollständiger nativer Export und Evidenz | 5 | 6,609 / 6,422 / 3,844 / 3,203 / 3,375 | 3,844 |
| Terminal bleibt offen, Fenster tatsächlich unsichtbar → Export und Evidenz | 2 | 4,531 / 2,719 | 3,625 |

Das Verhältnis der ersten beiden Mediane liegt bei etwa 5,3. Das ist ein vielversprechender Kurztest-Befund, kein belastbarer Multiplikator für die gesamte Factory. Die Testrechnung selbst dauerte in diesen Warmdurchläufen 0,203–0,339 Sekunden. Bei minuten- oder stundenlangen EAs wird derselbe eingesparte Startaufwand prozentual kleiner.

Wichtige Einschränkungen:

- Kleine, sequenzielle Stichprobe bei parallel laufender Factory; kein randomisierter Lasttest.
- Kaltstart-Beobachtung teilweise im 2-Sekunden-, Warmstatus im 0,5-Sekunden-Takt. Kaltwert ist Berichtserkennung; Warmwert enthält zusätzlich Konfigurations-/JSON-Abfragen, nativen Dateiexport und Journalsicherung.
- Erstmalige Anmeldung und MCP-Einrichtung sind nicht Teil der Warmjob-Zeit. Der Laborclient las den Schlüssel vor der Zeitmessung über die normalen Einstellungen; ein dauerhafter Produktionscontroller sollte diese einmalige Einrichtung nicht je Job wiederholen.
- Beim ersten Kaltstart lagen bereits rund 30 Sekunden zwischen Terminalstart und Broker-Anmeldung. Spätere Anmeldungen waren schneller. Daher nicht pauschal mit 49 Sekunden Ersparnis rechnen.
- Versteckte Fenster funktionierten. Der Unterschied 3,844 gegenüber 3,625 Sekunden belegt aber keinen eigenständigen Headless-Geschwindigkeitsgewinn. Ein verstecktes Terminal ist kein anderer Rechenkern.

## Qualitätsnachweis

Alle drei Kaltberichte der Fixture A haben nach Normalisierung dieselben vollständigen HTML-Tabellenzellen. Die sieben Warmdurchläufe der Fixture A stimmen jeweils mit dem Kaltbericht überein:

- 516.822 reale Ticks, 1.151 Bars, 60 Trades.
- Sämtliche Felder der 120 Orders und 121 Deal-Zeilen einschließlich Einzahlung: identisch, inklusive Zeit, Richtung, Volumen, Preis, Gebühren, Swap, Gewinn, Saldo und leerer Felder.
- Alle vier EA-Inputs und geprüfte Modell-/Fenster-/Kontometadaten identisch.
- 360 native Trade-Journalmeldungen je Warmdurchlauf; derselbe normalisierte Trade-Stream-Hash.
- Frischer nativer Teststart, genau ein Engine-Abschluss und neues Journalstück pro gewertetem Durchlauf. Keine reine Wiederverwendung einer gecachten Ergebniszusammenfassung.

Zusätzlicher A–B–A-Test: Beginn auf 02.09.2026 geändert, danach auf 01.09.2026 zurückgestellt. B ergab 413.648 Ticks, 863 Bars, 46 Trades, -321,42 USD; ein eigener frischer B-Kaltstart bestätigte alle Order-/Deal-Felder. Das zurückgestellte A ergab wieder die ursprünglichen 60 Trades und -347,84 USD mit identischem Ledger. Insgesamt acht erfolgreiche Warmtests mit nativer Vergleichsevidenz.

Das belegt die geprüfte Datumsumschaltung, nicht bereits den beliebigen Wechsel zwischen EAs, Setfiles, Symbolen, Stressmodellen oder Logger-Konfigurationen.

## Technischer Durchbruch und Fallstricke

MT5s native MCP-Tester-Steuerung startet Tests im schon laufenden Terminal. Die aktuelle MetaQuotes-Version erweitert die Tester-Abfragen und Berichts-/Optimierungsfunktionen. [MetaQuotes: Build 6180](https://www.metatrader.com/en/news/metaquotes/3986097-new-metatrader-5-platform-build-6180-more-ai-features)

Lokal nachgewiesen auf Build 6182:

1. tester_run_backtest liefert eine Run-ID; tester_get_status meldet tester_status, nicht status. Ein gestoppter Tester allein ist niemals ein Gate-PASS.
2. Der klassische Report=HTML-Eintrag wird bei diesem Startweg nicht automatisch exportiert.
3. tester_get_report mit file_format=xml erzeugt tatsächlich eine native XLSX-Datei. Die Antwort nennt ausdrücklich file_format=xlsx. Die Datei enthält nicht nur Kennzahlen, sondern den vollständigen Order-/Deal-Bereich, Inputs und weitere Berichtsinhalte.
4. Dateityp daher am Inhalt und Antwortvertrag erkennen, nicht an der Endung .xml. Die Originaldateien bleiben unverändert archiviert; der Laborparser erzeugt keinen künstlichen MT5-Bericht.
5. Die kurze JSON-Zusammenfassung ist kein unveränderter Ersatz für den bisherigen Bericht: gross_loss war dort positiv 507,46, im nativen HTML/XLSX dagegen -507,46. Außerdem unterscheiden sich Darstellungspräzision und Detailumfang.
6. Ein zweiter Start desselben terminal64.exe mit neuer /config-Datei hat im offenen Terminal innerhalb des 12,7-Sekunden-Probes weder einen neuen Bericht noch ein einziges zusätzliches Tester-Journalbyte erzeugt. Dieser einfache CLI-Warmstart ist hier kein funktionierender Controller.
7. Ein Terminal hat eine aktuelle Tester-Job-Identität. Ein exklusiver Controller-Lock ist erforderlich; ein späterer Job macht alte Run-ID-Abfragen ungültig.

Die erste Pilotbeobachtung verwendete den falschen Statusschlüssel und wird nicht als akzeptierte Laufzeit gewertet. Zwei weitere Aufrufe scheiterten vor Teststart an der Fenstererkennung nach dem Verstecken. Mehrfach offene Optionsdialoge durch nicht wirksame synthetische Mausklicks wurden über den normalen IDCANCEL-Befehl geschlossen; der Prototyp nutzt jetzt diesen Befehl und wartet auf das Schließen. Diese Anlaufprobleme bleiben dokumentiert, statt als Tester-Ergebnisse zu erscheinen.

## Priorisierte weitere Arbeiten

### P0 — Warm-Backend mit vollständigem Evidenzvertrag produktionsfähig machen

Der gemessene Hebel rechtfertigt diese Priorität vor weiteren kosmetischen Terminaloptimierungen.

Noch erforderlich, bevor ein Factory-Worker umgestellt wird:

- Native XLSX-Berichte als eigenen Quelltyp integrieren, mit expliziten Spalten-/Kennzahlenverträgen, Vorzeichen, Präzision, Vollständigkeit und Originaldatei-Hash. Alle bisherigen downstream Gate-Verbraucher testen.
- QM-EA statt Beispiel-EA: gleicher EX5-Hash, Setfile, Custom-Symbol-Datenstand, Symbol-/Kostenparameter, Datum, Seed und Modell; vollständige QM-Logger-Dateien und Traces vergleichen.
- Setfile A–B–A, EA A–B–A, Symbol-/Zeitraumwechsel sowie Stress-/Holdout-Zellen prüfen. Keine Vermischung von Kennzahlen, Journals oder Run-IDs zwischen Jobs.
- Fehlerfälle absichtlich im Labor erzeugen: Exportfehler, Kommunikationsabbruch, Agentabsturz, Terminal-Neustart, Updater-Handoff. Der bestehende CLI-Pfad bleibt ein nachweislich gleich konfigurierter Rückfallweg.
- Genau ein Job je Controller, fester Prozess-/Startzeit-/Port-Nachweis, lokale Tester-Tool-Allowlist, RAM-Admission und dokumentierte Restart-Grenzen.
- Anschließend zunächst einen Worker als Canary, nicht alle zehn gleichzeitig.

### P1 — Datenlokalität und unnötige Arbeit

- Zusammengehörige Tests möglichst auf demselben Worker ausführen, sofern Priorität und Fälligkeit das zulassen: gleiche Symbolhistorie, gleicher EA, gleiche Datenrevision. Import-/Ladearbeit messen und warme Caches gezielt nutzen.
- Unveränderte Compile-/Deploy-/Validierungsartefakte anhand vollständiger Inhalts- und Versionsschlüssel wiederverwenden. Absichtlich unabhängige Wiederholungstests oder neue Daten-/Kostenstände dürfen dadurch nicht übersprungen werden.
- Pro Job Zeiten für Anmeldung, Datenbereitstellung, Engine, Export, Parser und Nachverarbeitung erfassen. Danach nach dem tatsächlich dominanten Anteil optimieren, nicht nach Fensteranzahl.

### P1 — Rechen- und Logger-Profiling auf realen QM-EAs

- Teure Indikatorabfragen, wiederholtes Laden und unveränderte Berechnungen profilieren; beispielsweise Handles einmal initialisieren und Bar-Berechnungen nur bei neuem Bar ausführen, sofern die Strategie genau diese Semantik verlangt.
- CSV-/Logger-Schreibpfade auf unnötige Flushes untersuchen. Puffern nur mit derselben vollständigen Ereignisfolge, deterministischen Flush-Grenzen und Crash-Evidenz. Keine Logger- oder Tickdaten streichen, um schneller auszusehen.
- Mit demselben großen Fixture unter Factory-Last messen, nicht nur mit diesem kurzen Beispiel.

### P2 — Batches, Agenten und Stallbudget

- Native Optimierungsbatches können wiederholte Start-/Ladearbeit sparen. Sie sind erst für Gates geeignet, wenn je Pass Inputs, Seed, Logs und vollständiges Ledger korrekt zugeordnet und erhalten bleiben.
- Standalone/Remote-MetaTester-Agenten sind keine kostenlose Qualitätsabkürzung: Remote-Agents protokollieren laut MetaQuotes unter anderem EA-Print-/Handelsmeldungen nicht wie lokale Agents. [MetaQuotes: MetaTester](https://www.metatrader5.com/en/terminal/help/algotrading/metatester)
- Den bestehenden 600-Sekunden-Post-Engine-Stallschutz nicht pauschal verkürzen. Als nächstes Labor-Fault-Injection und große Berichte messen; bei weiter unveränderter CPU-/Journal-/Dateibeobachtung könnte ein kürzeres Budget vertretbar sein.
- Keine Änderung an Model 4, Tickhistorie, Stressbreite, Gate-Schwellen oder Holdout, um Durchsatz vorzutäuschen.

## Umsetzung, Sicherheit und Ablage

Neu implementiert im Repository:

- tools/strategy_farm/mt5_warm_lab.py — begrenztes T11-Labor, prozessgebundener lokaler MCP-Client, Tester-Allowlist, Controller-Lock, Warm-/Hidden-/CLI-Probes.
- tools/strategy_farm/mt5_warm_report_parity.py — echter XLSX-Inhalt, Feldvergleich gegen native HTML-Ledger, Metadaten und neue native Engine-Nachweise.
- tools/strategy_farm/collect_warm_lab_acceptance.py — unveränderliche native Vergleichskopien und Abschlussnachweis.
- tools/strategy_farm/tests/test_mt5_warm_lab.py — isolierte Sicherheits-/Parser-Tests ohne Terminalstart oder Tradingzugriff.
- Bestehendes mt5_latency_lab.py um genau ein zweites Datumsfixture erweitert; Standard unverändert.

Die kombinierte gezielte Regression hatte 42 bestandene Tests. Kein Factory- oder Live-Deployment.

Nur 127.0.0.1:22357 wurde kontaktiert, nachdem Listener-PID, Executable und Prozessstart zum Labor passten. Der bestehende Default-Port 22346 wurde nicht kontaktiert. Schlüssel wurden nicht im Client gespeichert oder als Klartext ausgegeben; keine Handels-, Konto-, AutoTrading-, Shell- oder beliebigen Datei-MCP-Aufrufe. Keine AutoTrading-Umschaltung.

Der persistente Laborterminal und sein Tester wurden nach abgeschlossener Evidenz beendet, seine ursprüngliche MCP-Konfiguration wiederhergestellt. Die späteren Kaltkontrollen endeten natürlich. T11 ist wieder prozessfrei; die zusätzliche Diagnosereservierung wurde unter Eigentümer-/DB-/Prozessprüfung freigegeben. T11 bleibt durch die Worker-Policy außerhalb der Factory. Die beiden geschützten Live-Terminals liefen weiterhin mit denselben PIDs 15464 und 31728.

Zum Abschluss um 22:20:38 gab es im eng begrenzten Report-Tail-Snapshot keinen erkannten, frisch zugeordneten Post-Engine-Berichtsstau über 60 Sekunden. Das ist eine Momentaufnahme, keine Aussage, dass sämtliche Factory-Probleme gelöst wären.

Primäre Evidenz:

- D:\QM\mt5\T11\latency_lab_20260908\experiments\warm20260908\acceptance\acceptance.json
- D:\QM\mt5\T11\latency_lab_20260908\experiments\warm20260908\parity_final.json
- SHA-256 der finalen Paritätsakte: 25e36a8ac2b82cee68290ddc72e2dd303aa12cf4a52d5920cd0b29a04a9c7659
- Die Unterordner enthalten pro Warmjob Konfiguration, Run-ID, Beobachtungen, Bericht und Journal-Deltas; die unveränderten nativen XLSX-Dateien liegen unter MQL5\Files\QM_latency_lab.
