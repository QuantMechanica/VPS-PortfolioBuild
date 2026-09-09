# Pattern-Filter-Reparatur – 09.09.2026

Aktualisiert 14:49 Uhr Wien. **Code-Reparatur und native Abnahme bestanden: 739 Regressionstests, 535/535 native Fixtures, erfolgreicher Zero-Trade-Smoke und hash-gebundene Abnahme. Keine neue wirtschaftliche Strategieauswertung, keine Live-Änderung.** Die nachstehenden Zeitangaben dokumentieren die einzelnen Zwischenstände; der finale Abschluss steht am Ende.

## Befunde und Korrekturen

1. **Pattern 33/34 verwendeten nur zwei statt drei Kerzen.** MQL5 und Python-Zähler sind korrigiert: Bar 1 umschließt den realen Körper von Bar 2 strikt; Bar 0 bestätigt mit seinem Schlusskurs jenseits des Schlusskurses von Bar 1. Alle Bars sind geschlossen. Kein zusätzlich erfundener Trendfilter. Die vorhandenen strikten QM-Kerzenfarben bleiben erhalten: ein Doji zählt nicht als bullish/bearish.
   Unabhängige Referenz: [TA-Lib CDL3OUTSIDE](https://raw.githubusercontent.com/TA-Lib/ta-lib/main/src/ta_func/ta_CDL3OUTSIDE.c), abgerufen 09.09.2026. TA-Lib behandelt einen Doji als weiß; diese Konvention wird ausdrücklich nicht übernommen. Der frühere Zwei-Kerzen-Code und die dazu passenden alten Fixtures waren zirkulär bestätigt worden.
2. **B2/B5 waren keine verlustfreien Beschleuniger.** B2 verlangte +5% Nettogewinn sowohl 2019 als auch 2020, während die versiegelte Auswahl +5% Rendite/Maximaldrawdown in mindestens zwei Dritteln der Auswahljahre verlangt. Beispiel: Gewinn 95 statt 100, Drawdown 50 statt 100 ergibt R2DD 1,9 statt 1,0 – zulässig nach dem Originalkriterium, aber von B2 verworfen. Auch ein negatives erstes Basisjahr kann durch fünf weitere verbesserte Jahre ausgeglichen werden. B5-Ausschlüsse erzeugten fehlende Pflichtjahre und damit inadmissible Arme, ohne deren wirtschaftliche Untauglichkeit nachzuweisen.
   Neue B2/B5-Schreibpfade sind stillgelegt; `QM_DL089_PRESCREEN` wurde auf Maschinenebene von 1 auf 0 gesetzt. Ein veraltetes Environment=1 kann die retirierte Policy im neuen Code nicht reaktivieren. Neue Programme erhalten die vollständige deklarierte Matrix. Bestehende Programme behalten ihre alten Rows/Skips; nur noch nicht materialisierte Zellen werden vollständig zugelassen. **Die nach echten Messungen zulässige Activity-Floor-Prüfung bleibt unverändert.** Alte Skips werden niemals zu Messungen oder Null-Effekten umetikettiert.
3. **Falsch-positive native Testabnahme.** Der bisherige Collector zählte FAIL-Zeilen, ohne die Abnahme zu verweigern; der Worker konnte deshalb `HARNESS_OK` melden. Jetzt sind vollständige, eindeutige Fixture-IDs, passende Identitäten/Erwartungen, gültige Fenster, übereinstimmende Actual/Expected-Werte und ausschließlich PASS erforderlich. Fehler überschreiben keinen bisherigen grünen Ergebnis-CSV. Ein fehlender Prozess-Exitcode ist ebenfalls kein erfolgreicher Abschluss. Bundle und Ergebnisse bekommen einen SHA-gebundenen Collection-Nachweis.
4. **Test-Dispatch und Ressourcenmetadaten.** Die Binärdatei ist jetzt vom Enqueue bis zur verifizierten Bereitstellung gebunden. Der vorherige Harness-Dispatch-Test schrieb in das reale T9-Verzeichnis; er nutzt jetzt ausschließlich ein temporäres Testverzeichnis. Native Prüfläufe haben Vorrang vor Census-Frontier-Lanes innerhalb ihrer Prioritätsklasse. `host_timeframe` entspricht dem tatsächlichen `harness_period`: zuvor wurde der D1-Lauf für RAM fälschlich als H1-Backtest mit 29,333 GB eingeordnet. Kurze, exakt bezeichnete Fixture-Läufe erhalten einen eigenen Telemetrietyp. Reguläre RAM-Reservierung, Mindestfreiraum, CPU-/RAM-Latches und gemessene Fixture-Spitzen bleiben wirksam; keine globale Schutzschwelle wurde gesenkt.

## Unabhängige Tests und echter Compiler

- Die Suite umfasst jetzt **535 Fixtures für 77 Prädikate**, darunter 20 neu definierte Fälle für 33/34: echte Drei-Kerzen-Positive, alte Zwei-Kerzen-Falschpositive, isolierte Änderung der ältesten Kerze, fehlendes Engulfing, exakte berührende Grenzen, Bestätigung innerhalb des Dochts sowie eine Bestätigungskerze mit entgegengesetzter Farbe.
- Zusätzliche handprüfbare Regressionen reproduzieren die B2-Gegenbeispiele, prüfen die Policy-Stilllegung trotz Environment=1, den Erhalt alter Rows/Receipts und die vollständige Aufnahme neuer Matrixzellen.
- Der reale MetaEditor hat den reparierten, nicht handelnden Harness mit **0 Fehlern und 0 Warnungen** kompiliert. Sein Returncode 1 wird nicht mit einem Tester-PASS verwechselt; maßgeblich sind Compilerlog und vorhandenes gehashtes EX5. Es wurde in einem frischen Artefaktverzeichnis mit kopiertem Compiler und genau einem Include gebaut. Kein Terminal-Include und kein Strategie-Binary wurde überschrieben.
- Frühe Testläufe vor dem nativen Lauf: 127 Ablauf-/Pattern-/Prescreen-Tests, 68 zusätzliche Matrix-/Staging-Tests, 20 Integrations-/Staging-/Rollout-Tests sowie 42 Memory-/Fixture-Strukturtests bestanden. Diese Gruppen überlappen und dürfen nicht addiert werden. Die drei Prüfungen vorhandener nativer Ausgabe waren damals ausdrücklich nicht ausgewählt, weil die frische Ausgabe noch fehlte. Im abschließenden 739er-Testlauf sind sie enthalten.

Compiler-Artefaktverzeichnis:
`D:/QM/reports/pattern_permission_repair/20260909T120140Z_da3b526d`

| Bindung | SHA-256 |
| --- | --- |
| Pattern-Include, normalisierte LF-Bytes | `101cc2230e32d88970a89aadea167a8cece2a64074f450a3946f7302dcd2039e` |
| Fixture-Bundle | `04dec58e3697d1b8526a6845d0026cc7ea2533333b4c0336db0f24612a9e4c73` |
| Repariertes Harness-EX5 | `e895b98fd240144631b3d4c1d5a8678474d8a83e757f503b10ec647d41a391d7` |

Erste native Queue-ID: `b05e2e28-13d9-4e93-95a0-4c7e7b0510a3`, `HARNESS_PP_FIXTURE`, EURUSD.DWX/D1, 02.–10.01.2024. Zwischenstand vor 14:25: **pending**, kein vorweggenommenes PASS. Tatsächliche Laufzeit-/Ausgabe-Bindung wird vom Testerpfad geprüft, nicht aus den Python-Erwartungen erzeugt. Die späteren Ausführungen und ihre unterschiedlichen Abnahmen sind unten dokumentiert.

## Laufende sichere Einführung

- Maschinenflag B2/B5 = 0. Neue Python-Prozesse verwenden die retirierte Policy. Bestehende Worker werden nur im Leerlauf, ohne aktive Rows und ohne fremde Reservierungen neu geladen. Exakte PIDs, Mutation-Lock, erneute Prüfungen und Quellhash-Pin sichern jeden Austausch ab. Keine `terminal64.exe` wurde von dieser Reparatur beendet.
- Der erste Rollout stoppte bei der zusätzlichen, getesteten Telemetrie-Korrektur wie vorgesehen mit `source_drift_stop`. Der neue Controller **PID 5052**, gestartet 14:18:12 Wien, ist auf Worker-SHA `96470aedfcbe7851b70cc50fac9762606ed92701141aa4089184267f56e95908` gebunden. Laufzeit maximal 60 Minuten, mindestens 150 Sekunden Abstand. Bis 14:24 wurden T6/T10/T3 mit dieser Revision nachweislich im Leerlauf neu geladen. Vollständige Fleet-Aktivierung wird noch nicht behauptet.
- Der separate, read-only Abnahme-Watcher **PID 21784**, gestartet 14:22:54 Wien, überwacht ausschließlich die obige Harness-ID für maximal 60 Minuten. Nach echtem HARNESS_OK archiviert er die native Ausgabe und startet die volle Regression inklusive aller nativen Oracle-Vergleiche. Er verändert keine DB, beansprucht keinen Terminalplatz und beendet keine Tests. Bei Source-Drift, Testfehlern oder Ablauf wird kein PASS behauptet.
- Logs: `worker_rollout_v2.log/.err`, `acceptance_watch.log/.err`; Abschlussdatei nach Ende des Watchers: `acceptance.json`, ggf. `acceptance_pytest.log`. Alle liegen im obigen Artefaktverzeichnis. Ein noch nicht vorhandenes `acceptance.json` bedeutet laufende Beobachtung, nicht Erfolg.
- Die bisherige native CSV wurde als `pre_repair_pattern_fixture_results.csv` separat gesichert. Historische Strategie-Receipts, Regeln, Registry-Identitäten, Binärdateien und gemessene Jahresergebnisse bleiben unverändert. Die ältere Fixture-Definition ist zusätzlich im Git-Verlauf erhalten.

## Wirtschaftliche Neuauswertung – bewusst noch offen

Read-only Snapshot `impact_1215.json`: **27 materialisierte Programme, davon 22 abgeschlossene Q12-Auswertungen und fünf laufende**. Es sind keine 27 unabhängigen Strategiefamilien. Der Snapshot enthält Owner-Zuordnung, ursprüngliche Verdicts, Receipt-/Ledger-Hashes und dispositionierte Jahreszellen. Er ändert keine Bewertung.

| Priorität | Subjekt / Mess-EA | Unvermessene B2/B5-Zellen | Gemessene 33/34-Zellen mit alter Logik |
| --- | --- | ---: | ---: |
| 1 | Original-Balke 13213 / 41097 | 218 | 22 |
| 2 | GBPUSD 10706 / 41161 | 650 | 10 |
| 3 | USDCAD 11422 / 41163 | 490 | 18 |
| 4 | EURUSD 41221 / 41344 | 1078 | 0 |
| 5 | XAUUSD 41219 / 41346 | 1067 | 0 |
| 6 | Zweite Balke-Linie 21501 / 41324 | 0 | 22 |

Die zweite Balke-Linie ist keine unabhängige Diversifikation. Ihre übrigen Zellen laufen noch; der Snapshot ist kein finaler Matrixabschluss.

Nächster sauberer Arbeitsschritt nach nativer Abnahme: **separat registrierte/reviewte reparierte Mess-Lineage für Original-Balke**, mit dokumentierter Include-Closure, korrekter D1-Einbindung und eigenem Compile-/Basisnachweis. Nicht die eingefrorene 41097-EX5 in-place ersetzen: das würde alte Messungen neu binden. Für einen heutigen Rebuild muss auch der historische fehlende EA-managed-Guard gegenüber dem inzwischen integrierten Common-Framework berücksichtigt werden.

Beschleunigung nur mit nachgewiesener Äquivalenz: Ein selektives Nachmessen der 218 fehlenden Zellen plus reparierter 33/34-Zellen wäre deutlich kleiner als ein vollständiger Census. **Dafür fehlen aber noch der kompatible, eingefrorene Include-Build und die formell gebundene Recovery-Lineage.** Ohne diesen Nachweis keine Mischung alter und neuer Binärversionen, sondern vollständige neue Matrix. Kein opportunistisches Absenken von Quorum, Activity Floor oder Walk-forward-Stabilität zur Erzeugung eines Gewinners. Jede getestete Variante bleibt in der Versuchszählung.

**In diesem Arbeitsgang wurden null wirtschaftliche Balke-/EA-Neumessungen gestartet.** Weder ein verbesserter Balke-Filter noch ein neues Portfolio-PASS ist dadurch belegt. Das historische `NO_FILTER_CHANGE` bleibt als historisches Ergebnis stehen, beweist aber nicht die Nutzlosigkeit der Filter. Der 77er-Katalog ist weiterhin nicht als vollständige, 1:1 implementierte Andrea-Unger-PatternFast-Bibliothek nachgewiesen.

Autorisierung und abgegrenzter Umfang: [Entscheidungsnachweis](../../../decisions/2026-09-09_pattern_filter_repair.md).

## Native Ergebnisse und zusätzliche Wrapper-Reparatur

Der erste Lauf wurde auf T4 ausgeführt. Das Journal weist die bereitgestellte EX5 mit dem oben genannten Hash nach. Ergebnis-CSV um **14:26:39 Wien**: **535 PASS, kein FAIL**; SHA-256 `d7019fa1f75d5855620fb127b76187d33b2d07bdc99e6c960a713f958efa0de0`. Der Collector hat diese tatsächliche native Ausgabe übernommen; sie wurde nicht aus Python-Erwartungen erzeugt. Danach bestanden **733 Tests in 53,57 Sekunden**, einschließlich der nativen Oracle-Vergleiche. Diese Aussage betrifft die Predicate-/Code-Prüfung, nicht einen wirtschaftlichen Gate-PASS.

Zusätzlicher Defekt: `run_smoke` erhöhte das explizite `-MinTrades 0` des nicht handelnden Harness auf fünf Trades/Jahr. Sein authentischer `summary.json` meldet deshalb `FAIL / MIN_TRADES_NOT_MET`, obwohl die 535 Fixture-Tests bestanden. Gleichzeitig landete in der Work-item-Payload ein Exitcode 0 und `HARNESS_OK`. **Dieser DB-Status wird nicht als Nachweis eines erfolgreichen Gesamtlaufs akzeptiert.** Der Fall zeigt, warum ein DB-Token oder verloren gegangener Prozess-Exitcode allein nicht genügt.

Reparaturen:

- Der ausschließlich nicht handelnde Harness bekommt den bereits vorhandenen `-SmokeMode`, damit sein explizites `-MinTrades 0` gilt. Keine Q02-Regel eines Strategie-EAs wurde geändert.
- Der neue Worker prüft zusätzlich die echte `summary.json`: PASS/OK, exakt null Trades, passende Zeitgrenzen und Periode, eine vollständige Ausführung, unveränderte EX5 vor/nach dem Test und den tatsächlichen Report-Hash. Fehlende/fremde/abweichende Evidence wird abgewiesen.
- Auch `opt_census._harness_pass` kontrolliert diese native Evidence bei neuen hash-gebundenen Harness-Zeilen. Der erste Lauf wird nun trotz gespeichertem `HARNESS_OK` reproduzierbar mit `bound fixture harness native proof invalid` abgewiesen. Alte Zeilen werden nicht umgeschrieben.
- Fünf zusätzliche Summary-Regressionen und ein Census-Gate-Test sichern diesen Fehler ab. 46 fokussierte Tests dieses Schritts bestanden.

Der Testreport der ersten Ausführung liegt unter:
`D:/QM/reports/work_items/b05e2e28-13d9-4e93-95a0-4c7e7b0510a3/QM5_999999/20260909_122553/summary.json`.
`acceptance.json` im ersten Artefaktverzeichnis dokumentiert den damaligen Code-/Fixture-Teststand. Es ersetzt ausdrücklich nicht den nachträglich festgestellten Wrapper-Fehler und ist kein End-to-end-Freigabeschein.

T4 wurde anschließend im Leerlauf auf Worker-SHA `31785fbe6058986794d76d89ee8cd9c8ab563fa3170e0e71820a53fd33a24449` aktualisiert (PID 7420 → 27676, **14:31:10 Wien**). Neuer append-only Prüflauf: **`4ae5bebd-f670-4228-a524-b4a735c34c53`**, auf T4 begrenzt. Keine Wiederverwendung/Überschreibung der ersten Queue-Zeile.

Der neue Abnahme-Watcher **PID 32124**, gestartet **14:34:03 Wien**, beobachtet diese zweite ID maximal 60 Minuten, führt danach die vollständige Regression aus und schreibt nach `followup/acceptance.json` im Artefaktverzeichnis. Log: `acceptance_followup_watch.log/.err`. Aktueller Wartegrund: RAM-Latch der Factory (T4 protokollierte zuletzt etwa 7–11 GB frei bei notwendiger Erholung auf 20 GB). Keine Freigabe unterhalb der Schutzgrenzen und kein Abbruch anderer Tests, um ein grünes Ergebnis zu erzwingen.

Die älteren Rollout-Controller sind bei weiteren Source-Änderungen kontrolliert ausgestiegen; der T4-Canary-Rollout ist abgeschlossen. Die finale Revision wird noch nicht als auf allen Workern aktiv behauptet. Die wirtschaftlichen Recovery-Schritte für Balke bleiben davon getrennt und ungestartet.

Nachkontrolle **14:35:42 Wien**: Die vollständige Suite des aktuellen Codestands bestand mit **739 Tests in 41,58 Sekunden**, einschließlich aller nativen Fixture-Vergleiche und der neuen Summary-/Census-Gate-Regressionen. Der zweite native Gesamtlauf ist damit nicht vorweggenommen; dafür gilt weiterhin ausschließlich dessen eigene, noch ausstehende Summary-Abnahme.

Finaler begrenzter Fleet-Rollout gestartet **14:36:53 Wien**, Controller **PID 38356**, `worker_rollout_final.log/.err`, derselbe endgültige Worker-SHA wie beim T4-Canary. Er erfasst die neun übrigen exakt geprüften PIDs und stoppt spätestens nach 60 Minuten oder bei Source-Drift; ausschließlich Leerlauf-Austausch. T4 bleibt für die Abnahme unverändert. Der abschließende JSON-Snapshot enthält zusätzlich beide Harness-IDs und die unabhängige Native-Gate-Prüfung, damit ein bloß gespeichertes `HARNESS_OK` nicht mit vertrauenswürdiger Abnahme verwechselt wird.

## Finaler nativer Abschluss – 14:41:25 Wien

Der Wiederholungslauf `4ae5bebd-f670-4228-a524-b4a735c34c53` lieferte **PASS / OK**, `min_trades_required=0`, tatsächliche Trades=0, stabile EX5 vor/nach Ausführung und erneut **535/535 PASS**. Er dauerte im Runner etwa 75 Sekunden. Sein anfängliches `HARNESS_FAIL` war ein Fehler im neu ergänzten Leser: `run_smoke` speichert `ea_label=QM5_999999`, während die echte Datei unter `expert=QM\QM_pattern_permission_fixture_runner` steht. Die Validierung erwartet jetzt exakt diese tatsächliche Schemaform und weiterhin den richtigen Expert sowie sämtliche Binär-Hashes. Der native Report wurde nicht verändert.

Die falsche negative Queue-Bewertung wurde **nicht überschrieben**. Eine transparente, append-only Neuadjudikation **`ccd5acb4-af10-51ce-8b64-8953a6cb2a4b`** prüft die vorhandene native Ausführung mit dem korrigierten Leser. Sie ist keine dritte MT5-Ausführung: `native_execution_repeated=false`, `native_execution_work_item_id=4ae5…`. Der vorherige vollständige Work-item-Digest wurde nach dem INSERT identisch bestätigt. Die native CSV liegt für diese Abnahme in einer eigenen unveränderlichen Artefaktkopie. Der normale Census-Harness-Gate akzeptiert diesen Nachweis; den ersten Wrapper-FAIL weiterhin nicht.

| Finaler Nachweis | SHA-256 |
| --- | --- |
| Echte PASS-Summary | `a93fcdf2b203f5c26d7adf253fd67665c810721c51656becb5ba1192deb35349` |
| Echte native report.htm | `86a8b30b7004eea416d93d114f1c78c37b6f2943877047410ed4dc73e916150b` |
| 535 native Fixture-Ergebnisse | `d7019fa1f75d5855620fb127b76187d33b2d07bdc99e6c960a713f958efa0de0` |

Abnahmebeleg: `readjudication/receipt.json`; abschließender Gesamttest: **`final_verified/acceptance.json` und `final_verified/acceptance_pytest.log`**, jeweils unter dem oben genannten Artefaktverzeichnis. Frühere `acceptance.json`-Dateien bleiben als Zwischenstände stehen und werden nicht in einen Erfolg umgeschrieben.

## Abschließende Regression und Betrieb – 14:49 Wien

Der erste abschließende Regressionstest (`final_acceptance/`) ergab 738 PASS und einen Fehler in `test_advance_transitions_once_then_holds`: Der Test sortierte gleichzeitige Inserts nach zufälligen UUIDs und erwartete dabei die Reihenfolge der Walk-forward-Jahre. Das ist keine stabile Sortiergarantie. Ausschließlich dieser Test wurde auf das fachliche Jahr umgestellt; seine Uhr ist jetzt absichtlich eingefroren, sodass identische Zeitstempel den früheren Fehlerfall reproduzieren. Die Produktions-Auswahl, Fold-Erzeugung und Ergebnisanforderungen wurden dabei nicht verändert.

Der erneute vollständige Lauf auf dem finalen Codestand endete **14:45:40 Wien mit 739 PASS in 43,61 Sekunden**, ohne Deselektion der nativen Vergleiche. `final_verified/acceptance.json` bindet alle geprüften Quell-/Testdateien sowie die echte native Ausgabe an ihre Hashes. Das frühere fehlgeschlagene Testergebnis bleibt erhalten.

Read-only Nachkontrolle 14:49: Der reguläre Census-Harness-Anker löst auf `ccd5acb4-af10-51ce-8b64-8953a6cb2a4b` auf und bestätigt dessen echte PASS-Summary. Maschinenflag `QM_DL089_PRESCREEN=0`. Die historische Balke-EX5 41097 ist unverändert (`e077660cc9ac5d74a6edc8896b72249f221fb030279bbd022f7e9d7756bb3a2e`). Die Factory hat vier `OPT_CENSUS`- und einen `Q02`-Work-item aktiv; dieser Momentstand ist kein pauschaler Gesundheitsnachweis aller Jobs.

Der begrenzte Leerlauf-Rollout läuft noch: Nach T4 wurden T7, T3, T6, T10 und T2 mit dem finalen Worker-Hash neu geladen. Controller PID 38356 ist aktiv, sein Fehlerlog ist leer. T1/T5/T8/T9 sind im finalen Rollout noch nicht bestätigt. Deshalb wird weiterhin keine vollständige Fleet-Aktivierung behauptet. Es werden keine aktiven Backtests dafür abgebrochen.

Damit sind die reparierte Pattern-Definition, der Python-Zähler und die native Test-/Abnahmekette verifiziert. **Die nächste wirtschaftliche Arbeit ist weiterhin die separate Balke-Recovery-Lineage; aus der technischen Abnahme folgt noch keine belegte Renditeverbesserung.**
