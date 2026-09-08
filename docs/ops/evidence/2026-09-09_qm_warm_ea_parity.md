# Echte QM-EAs im warmen MT5: Parität und nächste Freigabehürden

Stand: 09.09.2026, 00:16 Wien. Fortsetzung des Auftrags, T11 als getrenntes Versuchsterminal für schnellere Backtests ohne Qualitätsverlust zu nutzen.

## Ergebnis

Der native Warmweg funktioniert jetzt auch mit einem echten QM-EA, nicht nur mit dem Moving-Average-Beispiel. Zwei vollständige Input-Wechselsequenzen mit je eigenen Kaltreferenzen sind bestanden: A → B → A und C → D → C. Alle normalisierten HTML-Zellwerte einschließlich sämtlicher Orders-/Deals-Felder sowie sämtliche Logger-Felder stimmen mit der jeweiligen Kaltreferenz überein. Bei den Loggern wird ausschließlich der laufzeitabhängige Millisekundenanteil von `ts_utc` normalisiert; Rohdateien, Broker-Zeitstempel, Sekunden, Reihenfolge und Payloads bleiben erhalten.

Im zusätzlich festgelegten Diagnosefenster ohne native Tick-Lückenwarnungen dauerte der Warmweg **41,08 / 43,75 / 49,55 Sekunden**, die beiden Kaltreferenzen **56,16 / 94,73 Sekunden**. Das ist ein brauchbarer Laborbeleg für weniger Startaufwand, aber keine belastbare Prozentprognose für den Factory-Durchsatz. Die laufende Factory erzeugt schwankende Last; auch reine Engine-Zeiten schwanken.

**Umgesetzt sind Laborsteuerung, echte QM-Fixtures, strikte Vergleichsauswertung und Regressionstests. Nicht umgesetzt ist eine allgemeine Factory-Warmfreigabe.** Die separate, bereits bestehende T1-Report-Rettung bleibt unverändert und läuft am 10.09.2026 um 00:00 Wien automatisch aus.

Maschinenlesbarer Hauptnachweis: `docs/ops/evidence/2026-09-09_qm_warm_ea_parity.json`. Factory-/Abschlussnachweis: `docs/ops/evidence/2026-09-09_qm_warm_factory_watch.json`.

## Unveränderte Strategie, kontrollierte technische Unterschiede

Fixture: `QM5_10012_rw-fx-intraday-seas`, EURUSD.DWX, M30, Model 4, Ausführung ohne künstliche Verzögerung, Deposit 100.000 USD, Hebel 1:100, lokaler Tester, kein Visual/Remote/Cloud. Kein Compile und keine Änderung am EA, an Strategieentscheidungen, Registry-Zeilen oder Gates.

- EX5 SHA-256: `7235ca08884367a70f0740c83e0eeb7c6d7db6324aaa402f6b7680eef9aa091b`.
- Originalset SHA-256: `a4fe3429279d29316e3ab306d0acecc7a53babb7f461f3c9049dfcc5a860cea9`.
- A: exakte Originalset-Bytes, `RISK_FIXED=1000`. B: ausschließlich dieser Wert auf 500 geändert. Das ist ein Negativkontrolltest für korrektes Laden anderer Inputs, keine Strategieoptimierung und kein Vorschlag zur Änderung des Live-Risikos.
- A/B: 06.01.2025 bis 11.01.2025, Enddatum exklusiv.
- C/D: exakt dieselben A/B-Inputbytes, 06.01.2025 bis 10.01.2025. Dieses Diagnosefenster wurde vor seinen Läufen festgeschrieben, nachdem im ursprünglichen Datenfenster eine konkrete Freitagabend-Lücke entdeckt worden war. Keine Auswahl nach Gewinn oder Verlust.
- Es handelt sich um ein älteres vorhandenes QM-Binary vom Juni. Seine Logger-Struktur hat noch kein `sv`-Feld. Der Vergleich fügt keine Felder künstlich hinzu und belegt nicht die aktuelle Framework-Version.

## Messergebnisse

| Lauf | Gesamtdauer s | Native Engine s | HTML-Zeilen | Logger-Ereignisse | Ergebnis |
|---|---:|---:|---:|---:|---|
| A kalt | 67,979 | 50,300 | 104 | 25 | Referenz; bekannte Tick-Lücke |
| B kalt | 67,240 | 48,674 | 104 | 25 | Referenz; bekannte Tick-Lücke |
| A warm 1 | 40,437 | 35,673 | 104 | 25 | Vollständige Parität zu A |
| B warm 2 | 43,391 | 38,513 | 104 | 25 | Vollständige Parität zu B |
| A warm 3 | 52,656 | 48,575 | 104 | 25 | Vollständige Parität zu A |
| C kalt | 56,157 | 38,596 | 100 | 21 | Referenz; keine Tick-Lückenwarnung |
| D kalt | 94,728 | 44,758 | 100 | 21 | Referenz; keine Tick-Lückenwarnung |
| C warm 1 | 41,079 | 36,162 | 100 | 21 | Vollständige Parität zu C |
| D warm 2 | 43,750 | 37,850 | 100 | 21 | Vollständige Parität zu D |
| C warm 3 | 49,547 | 44,708 | 100 | 21 | Vollständige Parität zu C |

A/B: jeweils 567.919 Ticks, 240 Bars, fünf Trades. C/D: jeweils 451.882 Ticks, 192 Bars, vier Trades. Die veränderte Positionsgröße erzeugt unterschiedliche A/B- bzw. C/D-Ergebnisse; ein ignoriertes Setfile würde den Vergleich daher nicht bestehen. Alle 31 nativen Input-Zeilen werden beim Report-Abgleich berücksichtigt; sämtliche im Setfile angegebenen Werte müssen ausdrücklich stimmen.

Pro Sequenz bleibt derselbe Hauptprozess resident: PID 10088 für A/B/A, PID 16104 für C/D/C. Jeder Lauf hat eine eigene native Run-ID und einen nachweislich frischen erfolgreichen Engine-Journalabschnitt. Der abschließende A- bzw. C-Warmreport ist sogar byteidentisch zum ersten entsprechenden Warmreport. Gegenüber den Kaltreports werden Tabellenwerte verglichen; abweichende native Grafikreferenzen/Dateinamen werden nicht als Handelsabweichung gewertet.

Median der jeweils zur eigenen Kaltreferenz gepaarten Einsparung: 23,85 Sekunden im ursprünglichen Fenster, 15,08 Sekunden im sauberen Diagnosefenster. Die Einzelersparnis im sauberen Fenster reicht von 6,61 bis 50,98 Sekunden. Es gibt nur zwei Kaltreferenzen und drei Warmmessungen pro Fenster, keine randomisierte breite Performance-Studie. Kaltzeiten enden beim beobachteten vollständigen HTML; Warmzeiten enthalten zusätzlich nativen Export, Beenden des zuständigen Tester-Agenten und Logger-Erfassung. Eine pauschale Werbeaussage wie „Factory jetzt X % schneller“ wäre daraus nicht gerechtfertigt.

### Wo die Zeit in diesen Kaltläufen verloren geht

| Kaltreferenz | Vor Engine s | Engine s | Engine-Ende → erste Reportbytes s |
|---|---:|---:|---:|
| A | 15,872 | 50,300 | 1,305 |
| B | 16,318 | 48,674 | 1,747 |
| C | 15,372 | 38,596 | 1,685 |
| D | 47,322 | 44,758 | 2,144 |

Beim 94,73-Sekunden-Lauf ist der große Ausreißer **vor** der Engine. Das native Tester-Journal zeigt zwischen dem Ausschalten der Netzwerk-/Cloud-Farm um 00:07:42 und dem Laden des Experts um 00:08:12 fast 30 Sekunden Pause. Die genaue Ursache dieser Startpause ist noch nicht isoliert. Der HTML-Report selbst folgt dem Engine-Ende zügig. Das spricht in diesen Läufen für Wiederverwendung des Hauptterminals als Hebel; es widerlegt nicht die früher beobachteten separaten Report-Hänger.

## Zwei relevante Daten-/Setup-Funde

### Custom-Symbol-Katalog fehlte in der T11-Ausgangskopie

Der erste echte QM-Kaltlauf endete mit `symbol EURUSD.DWX not exist`, obwohl Custom-History und Ticks vorhanden waren. Der ungenutzten T11-Ausgangsinstallation fehlte `Bases/symbols.custom.dat`. Die im Repository vorhandenen DEV1-/DEV2-Isolationsrunner verlangen diese Datei bereits ausdrücklich.

Nur im separaten Labor wurde eine physische Kopie ergänzt. Die Katalogdateien von T1 und T10 mussten vorher denselben SHA-256 liefern: `6be56cd376afac7fb69bb6b30f24781f1d21e96b34bddc5b6c7e1e4f7ac09d65`, 20.480 Bytes. Keine Änderung an T1, T10, der T11-Ausgangsinstallation oder Broker-/Custom-Symbolparametern. Fehlversuch `qm10012_colda` bleibt als Setup-Fehler erhalten, ohne Strategie-Verurteilung.

### „100 % real ticks“ übersieht hier eine native Warnung

Alle A/B-Läufe zeigen im HTML `100% real ticks`. Die nativen Agent-Journale melden trotzdem für **10.01.2025, 23:59** eine fehlende Real-Tick-Minute und generierten Tick-Ersatz: eine Minute innerhalb von 7.155 Minutenbars des ursprünglichen Fensters.

Deshalb wird A/B nur als Gleichwertigkeitsbeleg unter identischer Datenlücke geführt, nicht als lückenfreier Qualitätsnachweis. C/D endet vor dem betroffenen Freitag und wird zusätzlich auf null native Tick-Lücken-/Generierungswarnungen geprüft. Es wurden keine Ticks erfunden, Quelldateien repariert, problematische ursprüngliche Belege gelöscht oder Factory-Gates gelockert.

Der Fund ist zunächst auf diese private T11-Datenkopie begrenzt. Ob und welche Factory-Artefakte dieselben Tickbytes verwenden und ob deren vorhandene Daten-Gates diese spezielle Warnung abfangen, ist eine getrennte, noch offene Herkunftsprüfung. Kein pauschales Urteil über sämtliche Factory-Daten.

## Implementierte technische Absicherungen

`tools/strategy_farm/mt5_qm_warm_fixture.py`:

- Feste EX5-/Setfile-Fingerprints und vier ausdrücklich erlaubte Fixture-Arme. Keine beliebigen EAs, Symbole, Zeitfenster oder Trading-Aufrufe.
- Aktive oder wartende Factory-Aufträge desselben EA blockieren das Fixture, um bekannte FILE_COMMON-/Logger-Namenskonflikte zu vermeiden. Das ist noch keine produktionsreife, atomare Cross-Job-Isolation.
- Echte physische Kopien von zwei HCC- und zwei TKC-Dateien mit unveränderten Hashes. Keine neuen Hardlinks/Junctions zur Factory-History.
- Vor Terminalstart vollständiger Hash-Nachweis samt Datei-ID/Größe/mtime. MT5 sperrt residente HCC-Dateien teilweise exklusiv; in genau diesem Fall wird unveränderte Dateiidentität mit dem vorab gespeicherten Hash und dem exakt gebundenen lebenden Laborprozess geprüft. **Nach Schließen werden sämtliche privaten und ursprünglichen Datenfiles erneut vollständig gehasht**, bevor die Parität angenommen wird.
- Native MCP-Testaufrufe verlangen explizit `inputs_path`; allein ein ExpertParameters-Eintrag gilt nicht als Nachweis. INI, Reportname, Setfile-Pfad, Real-Tick-Modell und Isolationswerte sind gebunden.
- Vollständiger nativer HTML-Export, exakter Settings-/Input-Abgleich und genau ein frischer erfolgreicher nativer Engine-Abschnitt. Ein bloßer Status `stopped` oder ein gecachter Report genügt nicht.
- Erst nach vollständigem validiertem Report wird der exakt zur Laborsession gehörende Tester-Agent beendet. Der Hauptprozess bleibt resident. Frische Logger-Dateien werden anhand vorheriger Bytes bzw. Sessionstart abgegrenzt; alte Agent-Dateien und mehrdeutige parallele Logger-Ströme werden nicht zugelassen.
- Neue Konfigurationen und Belege werden nicht überschrieben. Fehler lassen keinen akzeptierten Ergebnisdatensatz entstehen. Der bestehende 30-Minuten-Watchdog begrenzt die Laborsession.

`tools/strategy_farm/mt5_qm_warm_acceptance.py`: reproduzierbarer kompletter Kalt-/Warmvergleich mit positiven/negativen Inputkontrollen, nativen Trade-Stream-Hashes, allen HTML-Zellwerten und Logger-Feldern, Daten-Hashprüfung nach Prozessende sowie Zeitzerlegung. Die zwei älteren Kaltläufe stammen noch von vor der Journal-Offset-Erfassung; deren eigene native Abschnitte werden über lokale Journal-Zeitstempel zwischen Sessionstart und gespeichertem Report-Abschluss rekonstruiert und separat archiviert. Neuere C/D-Läufe erfassen echte Byte-Offsets bereits vor dem Start.

`mt5_warm_lab.py`: Zulassung der fest gepinnten echten QM-Fixtures, Daten-Preflight vor MCP-Konfigurationsänderung und Journal-Offsets vor Kaltstart. Kein Anschluss an den produktiven Worker und keine Änderung des vorhandenen Factory-Prozess-Eigentums.

**Verifikation: 115 Python-Tests und vier PowerShell-Regressionsskripte bestanden.** Abgedeckt sind unter anderem falsche Inputs, verbotene Modelle/Cloud/Symbole, falsche Pfade, veränderte Quelldateien, gesperrte History-Identität, alte/mehrdeutige Logger, reine Logger-Millisekunden-Normalisierung, abgeschnittene Journale, Tick-Lücken sowie Prozessabgrenzung. Das vorhandene Logger-Regressionsskript benötigt PowerShell 7 (`utf8NoBOM`); ein erster Aufruf unter Windows PowerShell 5 wurde korrekt mit diesem Kompatibilitätsfehler abgewiesen, danach unter `pwsh` bestanden. Keine produktive Codeänderung wegen dieses Testaufrufs.

## Factory-Beobachtung und Sicherheitsabschluss

25 Beobachtungen im 15-Sekunden-Takt, **00:07:44 bis 00:13:44 Wien**. Keine Observerfehler und kein vom vorhandenen Identitätsprüfer erkannter Post-Engine-Stau über 60 Sekunden. Innerhalb dieses Fensters wurden zehn Queue-Aufträge fertig: sechs `MEASURED`, vier `FAIL`. Das sind Factory-Verarbeitungsergebnisse, keine zehn bestandenen Strategiegates und keine permanente Gesundheitsgarantie. Der Beobachter lief nur dieses begrenzte Fenster und ist beendet.

Unter anderem wurde der T1-Auftrag `6ba180b7-08a9-5682-9010-3d15bf1dccb3`, QM5_41301, OPT_CENSUS, um 00:13:24 Wien als `done / MEASURED` abgeschlossen. Die bisherige T1-Rettungspolicy wurde in dieser Fortsetzung weder verändert noch auf andere Terminals erweitert. Eine erfolgreich gerettete echte Produktionsblockade und deren Produktionsersparnis sind weiterhin nicht belegt.

Alle Laborprozesse geschlossen; ursprüngliche MCP-Konfiguration bytegleich wiederhergestellt. T11 bleibt aus der Worker-Policy ausgeschlossen; diese ist unverändert T1–T10. Die eigene T11-Diagnosesperre darf bis **01:39:40 Wien am 09.09.2026** natürlich auslaufen. Ein unnötiges Umschreiben der gemeinsamen Reservierungsdatei mit gleichzeitig aktiven Fremdreservierungen wurde vermieden. FTMO-Live-PID 15464 und T_Live-PID 31728 unverändert. Kein AutoTrading-Umschalten, kein Live-Deploy, keine Order, kein Queue-Eingriff.

Keine Quelldaten oder Benutzerdateien gelöscht. Bereits vorhandene fremde Änderungen an QM5_41240 und der separaten Infrastruktur-Triage bleiben unverändert.

## Priorisierte nächste Schritte

1. **Produktionsfähige Warm-Isolation spezifizieren und im Labor qualifizieren.** Aktuelles Framework-Binary, mindestens die vorhandene 20-Vergleichszellen-Hürde, mehrere echte EAs/Symbole/Setfiles, A/B/A-Wechsel, Neustart-Wiederholungen, frische History-/News-/Logger-Grenzen. Vier Fixture-Arme mit wiederverwendeten Inputbytes sind keine 20 unterschiedlichen Qualifikationszellen. Der vorhandene `ResidentSessionBackend`-Ansatz in `warm_cell_runner.py` ist ein möglicher Anschluss; keine Freigabeseals oder Zustimmungseinträge erfinden.
2. **Native Fehlerfälle gezielt auf T11 testen.** Hängender/abgebrochener Test, fehlerhafte INI, fehlende EX5, langsamer oder blockierter Speicherdialog, kompletter Session-Neustart, PID-Wechsel, alte Reportreste. Akzeptanz: keine alten Belege als neue werten; vollständiger kalter Wiederanlauf innerhalb der bisherigen Runner-/Gate-Verträge.
3. **Wiederverwendung dort integrieren, wo sie tatsächlich hilft.** Viele derzeitige OPT_CENSUS-/Q02-Aufträge haben nur einen Lauf. Warmhaltung nur innerhalb eines solchen Auftrags spart keinen erneuten Start. Cross-Job-Warmbetrieb muss vorher Windows-Job-Object-Eigentum, Scheduler-Reservierung und per-Auftrag Daten-/Logger-Isolation korrekt lösen. Erst danach ein begrenzter Factory-Canary mit messbaren Start-/Engine-/Report-/Loggerzeiten, sofortigem Kalt-Fallback und unveränderten Gates.
4. **Tick-Lückenherkunft nachverfolgen.** Zuerst read-only prüfen, ob dieselben T11-Tickbytes überhaupt in Factory-Fenstern vorkommen, und ob vorhandene Daten-Gates native Generierungswarnungen schon berücksichtigen. Keine globale Datenreparatur oder Neubewertung ohne konkrete betroffene Artefakte.
5. **Bestehenden T1-Export-Canary anhand echter Ereignisse beurteilen.** Aktivierung und unbeeinträchtigter Normalbetrieb sind belegt; Nutzen bei einem echten Stau noch nicht. Vor Ablauf prüfen, ob eine Rettung tatsächlich stattfand und den unveränderten vollständigen Runner bestand. Ohne solchen Nachweis weder globale Ausweitung noch Erfolg behaupten.

Nicht priorisiert: Website, Videos, Marketplace, Strategietuning anhand dieser Kurzfenster, pauschales Senken des Tickmodells oder Abschalten von Logger/Gates. Es wird auch kein echter grafikloser „Headless“-Betrieb behauptet: Der hier qualifizierte native HTML-Export verwendet weiterhin gezielt gebundene MT5-Dialoge.

## Belegorte

Laborroot: `D:\QM\mt5\T11\latency_lab_20260908`.

- `experiments/qm10012_fixture/manifest.json`, `symbol_spec_manifest.json`, `clean_window.json`: vorab fixierte EX5-/Inputs-/Daten-/Zeitraumdefinitionen.
- `experiments/qm10012_colda`: erhaltener erster Setup-Fehler.
- `experiments/qm10012_colda2`, `qm10012_coldb`: Originalfenster; unter letzterem `warm1`, `warm2`, `warm3`.
- `experiments/qm10012_coldc`, `qm10012_coldd`: sauberes Diagnosefenster; unter letzterem `clean1`, `clean2`, `clean3`.
- Native Kaltreports im Laborroot: `qm10012_<coldname>_cold.htm`; Warmreports jeweils im Laufunterordner als `native.html`. Die vollständigen exakten Pfade und Hashes stehen im Hauptnachweis.
- `experiments/qm10012_fixture/acceptance_2026-09-09_qm_warm_ea_parity`: rekonstruierte native Zeitfenster der älteren Kaltjournale.
- `experiments/qm10012_fixture/factory_watch_20260909.jsonl`: unveränderter Rohstrom des sechsminütigen Beobachters.

Rücknahme dieser Fortsetzung erfordert keinen Factory-Rollback: Die neuen Werkzeuge sind nur Laborwerkzeuge und nicht am Worker angeschlossen. Konfiguration und Prozesse wurden bereits zurückgeführt. Die native T1-Export-Rettung aus der vorherigen Umsetzung ist davon getrennt dokumentiert in `2026-09-08_native_report_rescue_canary.md`.
