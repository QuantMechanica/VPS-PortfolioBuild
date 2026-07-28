# MNT-Konvergenz Runde 3 — Codex-Positionen zu MNT-043–046

Datum: 2026-07-29  
Reviewer: Codex  
Router-Task: `6a1811dd-0adb-41a7-a4c9-a9dc63a22a5b`  
Review-Branch: `agents/codex-mnt-review-20260728`  
Disposition: **REVIEW — keine Selbstfreigabe**

## Umfang und Sicherheitsgrenze

Dieses Dokument liefert:

1. den Nachweis zum implementierten WP-1-Delta für `pipeline-view` und das
   Task-Contract-Paket;
2. ausschließlich Review-Positionen, Dissents und verbesserte
   Akzeptanzkriterien zu MNT-043 bis MNT-046.

WP-2 enthält bewusst **keine Implementierung**. Es wurden keine Scheduled Tasks
verändert, keine Factory-Schalter betätigt, kein Terminal gestartet, kein
laufender Backtest unterbrochen und weder T5 noch T_Live berührt. Alle
Produktionsabfragen waren read-only gegen
`D:\QM\strategy_farm\state\farm_state.sqlite` beziehungsweise das Dateisystem.
Kein hier genannter Backtest- oder Strategie-Verdict wird aus Review-Meinung
abgeleitet; Pipeline-Verdicts bleiben ausschließlich Sache ihrer
Pipeline-Evidenz.

## Kurzposition

| Seite | Zustimmung Lösung + Akzeptanz | Prioritätsposition | Kern-Dissent |
|---|---:|---|---|
| MNT-043 | **82 %** | P0 für Live-Halt-Schuld; P1 für den übrigen Flottenbestand | `mtime` ist keine Build-Provenienz; jeder Rebuild entwertet binär gebundene Evidenz |
| MNT-044 | **92 %** | P0 für Live-/Admission-Offender; P1 für den historischen Rest | Roh-Verdicts nicht umschreiben; unveränderliche Adjudication-Ebene einführen |
| MNT-045 | **84 %** | P1 bestätigt | „Tester wie live degradieren“ ist keine zulässige Option; Preflight vor Claim und atomisches Bundle |
| MNT-046 | **86 %** | P1 bestätigt | kein `q*`-Glob; exakte Runner-Allowlist plus Work-Item-/Lineage-Bindung |

Die Prozente sind keine Freigabe. MNT-044 liegt aus Codex-Sicht über der
90-%-Schwelle; MNT-043, MNT-045 und MNT-046 benötigen die unten beschriebenen
materiellen Korrekturen.

## WP-1 — Ergebnis und gemessener Effekt

### Implementierter Vertrag

`pipeline_view()` trennt nun drei unterschiedliche Fragen:

- `verdict`: neuestes **nicht-neutrales Strategie-Verdict** der Phase;
- `best_verdict`: bestes nicht-neutrales Strategie-Verdict der Phase;
- `latest_run`: neuester Run unabhängig von Verdict-Familie, einschließlich
  Status, Verdict, Work-Item und Zeitstempel.

`regressed` vergleicht ausschließlich Strategie-Verdicts. `current_stage`
bleibt absichtlich an den neuesten Run gebunden und zeigt damit weiterhin einen
neuen `INFRA_FAIL`, während die Strategiezelle den letzten belegten
Strategiezustand behält. Die Implementierung und die Trennung stehen in
`tools/strategy_farm/farmctl.py:2195-2225`,
`tools/strategy_farm/farmctl.py:2324-2383` und
`tools/strategy_farm/farmctl.py:2387-2405`.

Die expliziten Pins decken `P2 -> Q02`, neutral-neuester Run,
`P5b/P5c/P9b` in Kleinschreibung sowie `current_stage` ab
(`tools/strategy_farm/tests/test_pipeline_view_work_items.py`). Das
Task-Paket prüft zusätzlich `pythonw.exe` und
`WaitSeconds <= ExecutionTimeLimit`
(`tools/strategy_farm/tests/test_task_contract_fix_package.py`). Die
Deploy-Reihenfolge ist in
`tools/ops/task_contract_fix_2026-07-28/README.md` festgehalten; die
Operator-Semantik in
`docs/ops/mnt_page_updates_2026-07-28/MNT-040.md`.

### Read-only Produktionsreplay

Snapshot `2026-07-28T23:39:43Z`, 104.076 Work-Items und 5.839 kanonische
EA/Phase-Gruppen:

- alter Algorithmus: 636 `regressed=true`;
- raffinierter Algorithmus: 374 `regressed=true`;
- 333 alte Flags hatten ein neutrales neuestes Verdict:
  326 `INFRA_FAIL`, 4 `PENDING_RUNNER`, 1 `NEED_MORE_DATA`, 2 `RETIRE`;
- 294 dieser 333 verschwinden korrekt;
- 39 bleiben korrekt bestehen, weil unter dem neutralen neuesten Run eine echte
  Strategiefolge `PASS* -> FAIL*/INVALID*/ZERO_TRADES*/RETIRE*` liegt.

Damit ist „ungefähr 334 verschwinden“ keine sichere Akzeptanzkonstante. Die
richtige Invariante lautet: **ein neutrales Verdict erzeugt nie selbst eine
Regression; eine darunter weiterhin belegte Strategieregression bleibt
sichtbar**. Der Replay gruppierte die read-only abgefragten Spalten
`id, phase, ea_id, status, verdict, created_at, updated_at` mit exakt den
Sortier- und Familienregeln aus
`tools/strategy_farm/farmctl.py:2195-2208`,
`tools/strategy_farm/farmctl.py:2227-2232` und
`tools/strategy_farm/farmctl.py:2324-2367`.

### Verifikation

- fokussiert:
  `python -m pytest -q tools/strategy_farm/tests/test_pipeline_view_work_items.py tools/strategy_farm/tests/test_task_contract_fix_package.py`
  — **8 passed**;
- vollständige Round-3-Suite über die neun im Brief gebundenen Testmodule:
  **122 passed in 4.50s**;
- `python -m py_compile` für `farmctl.py` und beide geänderten Testmodule:
  **PASS**;
- `git diff --check`: **PASS** (nur erwartete LF/CRLF-Checkout-Warnungen).

## MNT-043 — Flottenweite Recompile-Schuld

**Position: 82 % Zustimmung. Priorität splitten: P0 für die 24
Live-Sleeves beziehungsweise jede nachweislich halt-kanal-tote Live-Binary,
P1 für Q08/Q10, aktive Queue und Restbestand.**

### Worin ich zustimme

Die Sicherheitslücke ist real und nicht durch einen Source-Patch allein
geschlossen. Der ursprüngliche Halt-Kanal benutzte im MQL5-Sandbox-Modell
unauflösbare absolute Pfade
(`docs/ops/KILLSWITCH_HALT_CHANNEL_FIX_2026-07-05.md:8-18`). Das
Rollout-Dokument sagt ausdrücklich, dass vorhandene Live-Binaries bis zum
Rebuild die toten Pfade behalten
(`docs/ops/KILLSWITCH_HALT_CHANNEL_FIX_2026-07-05.md:55-57`), und der
Framework-Audit fand 12 von 24 Live-Sleeves vor dem Fix
(`docs/ops/EA_FRAMEWORK_AUDIT_2026-07-20.md:39`).

Auch die vorgeschlagene serielle Leiter, SHA-Bindung, Tranchierung und ein
nicht-live ausgeführter Canary sind richtig. Der vorhandene immutable
EX5-Staging-Vertrag kann dafür wiederverwendet werden: Source-Hash,
atomischer Replace, Pre-/Post-Run-Hash und Fail-closed-Prüfung sind bereits in
`tools/strategy_farm/terminal_worker.py:1608-1671` implementiert und in
`docs/ops/evidence/2026-07-28_ex5_staging_and_probe_result.md:11-25`
dokumentiert.

### Materielle Dissents

1. **`mtime` darf nur Discovery-Signal, nie Betroffenheitsbeweis sein.** Ein
   read-only T1-Snapshot am `2026-07-28T23:40:38Z` fand 1.706 EX5-Dateien,
   davon 1.643 mit `LastWriteTimeUtc` vor
   `6f2393373` (`2026-07-20T20:15:31Z`). Diese Zahl ist volatil und weicht
   bereits vom Seitentext ab. Außerdem ist `6f2393373` laut Git ein
   Kill-Switch-Persistenzfix vom 20.07., während der dokumentierte tote
   Halt-Pfad auf den Fix vom 05.07. zurückgeht. `5535c3c1b` datiert sogar vom
   28.07. Eine einzige „Fix-Welle vom 20.07.“ ist daher keine eindeutige
   Provenienzgrenze. Benötigt wird die tatsächlich kompilierte
   Source-/Include-Closure mit Commit-IDs und Hashes.

2. **Nicht „T_Live zuerst neu bauen und deployen“.** Zuerst außerhalb von
   T_Live bauen, statisch prüfen und im nicht-live Tester/Demo canaryen. Ein
   Live-Redeploy bleibt eine separate OWNER-signierte Manifestaktion; genau
   das verlangt der bestehende Rollout
   (`docs/ops/KILLSWITCH_HALT_CHANNEL_FIX_2026-07-05.md:59-67`). Ein
   experimenteller Halt auf T_Live ist ausgeschlossen.

3. **Ein Rebuild ist eine Verhaltensänderung, nicht bloß Wartung.** Beim
   Vintage-Vergleich für 9936 waren nur 91,5136 % der größeren
   Trade-Stream-Menge exakt identisch; 97 Abweichungen blieben kausal
   ungeklärt
   (`docs/ops/evidence/2026-07-28_vintage_bisect.md:20-29`). Der gemessene
   FUND_SCORE fiel um 11,1 %, weshalb Alt-Evidenz nicht als Current-Tree-Messung
   dargestellt werden darf
   (`docs/ops/evidence/2026-07-28_vintage_bisect.md:81-94`). Ein
   Tranche-Canary allein reicht folglich nicht, um die alte Q-Evidenz jedes
   neu gebauten Kandidaten weiterzuverwenden.

4. **`TEMP DIAG` ist kein abstraktes Risiko.** Der getrackte Treffer liegt
   aktuell in
   `framework/EAs/QM5_20096_ha-stoch-h4-swing/QM5_20096_ha-stoch-h4-swing.mq5:241-401`
   sowie `:639-643`; die Quelle fordert selbst Entfernung vor Commit. Die
   Bereinigung muss als eigener reviewbarer Source-Commit vor einem
   Flotten-Build erfolgen, nicht als unprotokollierter Build-Step.

5. **Akzeptanz „kein Live-Binary älter als Commit X“ ist zu schwach.**
   Timestamp-Neusetzen oder ein Build aus falscher Include-Closure würde
   formal bestehen. Ebenso beweist „Backlog fallend“ keine korrekte Binary.

### Verbesserter Lösungs- und Akzeptanzvertrag

1. Inventar pro EA mit `mq5_sha256`, vollständiger Include-Closure
   (`path, blob/sha256, required-fix-set`), Compiler-Version,
   `ex5_sha256`, Build-Zeit und Zielkohorte. `mtime` nur als
   Vorfilter.
2. Zwei getrennte Bills:
   - **P0-Live-Sicherheitsbill:** 24/24 Sleeves, außerhalb live gebaut und
     geprüft; anschließender Deploy ausschließlich per OWNER-Manifest;
   - **P1-Requalifikationsbill:** promoted/aktive Queue/restliche Flotte in
     kleinen, seriellen Kohorten.
3. Jeder Binary-Wechsel setzt für betroffene historische Q-Ergebnisse einen
   expliziten `evidence_vintage_stale`-Adjudication-Status. Die für Admission
   erforderlichen Gates werden mit der neuen SHA wiederholt; Altwerte bleiben
   unverändert historisch.
4. Kohorten verwenden immutable Staging statt Überschreiben einer gemeinsam
   genutzten kanonischen EX5 während aktiver Queue.
5. Akzeptanz P0:
   - 24/24 Manifestzeilen binden erwartete Fix-Closure und EX5-SHA;
   - 24/24 Deploy-Verifikationen binden exakt dieselbe SHA;
   - Halt-Kanal-Nachweis erfolgt auf Tester/Demo, nie experimentell live, und
     belegt `KS_BOOK_TAG_SET` sowie den erwarteten Haltgrund;
   - kein Deploy ohne OWNER-Signatur.
6. Akzeptanz P1:
   - kein promoted/aktives Work-Item konsumiert Evidenz einer anderen
     Binary-SHA;
   - neuer Build erzeugt entweder neue erforderliche Q-Evidenz oder bleibt
     admission-blocked;
   - Recompile-Backlog wird nach Hash-/Closure-Invariante, nicht nach
     Zeitstempel gezählt.

## MNT-044 — Q06/Q07-Altlast re-adjudizieren

**Position: 92 % Zustimmung. P0 für alle live, promoted oder aktuell für
Admission konsumierten Offender; P1 für die übrige historische Bereinigung.**

### Worin ich zustimme

Die Seite hat die eigentliche Lücke korrekt von der bereits vorhandenen
Fail-closed-Erkennung getrennt. Die eingefrorene und die nachgezogene Zählung
stehen in
`docs/ops/mnt_page_updates_2026-07-28/MNT-018.md:8-23`. Ein erneuter
read-only Snapshot am `2026-07-28T23:40:29Z` bestätigt die bewegliche
Momentaufnahme: 244 Q07-`PASS`, davon 106 ohne existente Evidenzdatei und 23
lesbare Aggregate mit `metrics.variance_pct == 0.0`.

Der aktuelle Q07-Runner authentifiziert bei neuen Runs requested und effective
Seed aus demselben Run-Verzeichnis
(`framework/scripts/q07_multiseed.py:173-210`,
`framework/scripts/q07_multiseed.py:540-588`) und macht fehlende oder
widersprüchliche Evidenz zu `INVALID`
(`framework/scripts/q07_multiseed.py:591-613`). Die Lösung muss daher den
Altbestand re-adjudizieren und den bestehenden Pfad nutzen, nicht eine zweite
parallele Seed-Auth bauen.

### Materielle Dissents

1. **Historische Pipeline-Rohzeilen nicht überschreiben.** Die Tabelle
   `work_items` besitzt nur `status`, `verdict`, `payload_json` und
   `evidence_path`, aber kein separates Review-/Adjudication-Feld. Ein
   Review-basiertes Umschreiben von `PASS` zu
   `PROVENANCE_UNVERIFIED` würde Pipelinegeschichte verändern und ein
   Review-Verdict als Pipeline-Verdict ausgeben. Stattdessen braucht es ein
   unveränderliches Adjudication-Register beziehungsweise eine Overlay-Tabelle
   mit `work_item_id`, originalem Verdict, effektivem Admission-Status,
   Grundklasse, Reviewer, Zeitstempel und Evidence-Hash.

2. **„Aggregate existiert“ reicht nicht.** Es muss parsebar sein und auf die
   fünf requested/effective Seed-Paare, Summary-/Report-Hashes, EX5,
   MQ5/Closure, Setfile, Symbol und Zeitraum zurückverweisen. Der aktuelle
   Runner prüft co-lokalisierte Seed-Evidenz, persistiert im Aggregate aber
   überwiegend Summary-Pfade und `invalid_reason`; der Vertrag sollte die
   authentifizierten Paare und Hashes direkt dauerhaft machen
   (`framework/scripts/q07_multiseed.py:543-588`,
   `framework/scripts/q07_multiseed.py:735-753`).

3. **Recompile allein beweist keine verdrahteten Inputs.** Vor Rebuild und
   Rerun ist eine statische Source-/Setfile-Prüfung erforderlich:
   `qm_rng_seed`, Stress-Inputs und der Basket-Order-Pfad müssen tatsächlich
   den ausgeführten Entry-/Orderpfad erreichen. Sonst produziert MNT-043 nur
   eine neue SHA mit demselben Vakuum.

4. **Die harte Live-Reihenfolge ist inzwischen teilweise veraltet.**
   `QM5_13128/NDX` hat weiterhin nur Work-Item
   `37308752-fa5f-41fc-9756-13113058f976`, `attempt_count=0`,
   Payload `backfill: requal_wave_20260717` und als `evidence_path` ein
   Verzeichnis statt `aggregate.json`: klar P0. Dagegen ist
   `QM5_1567/EURUSD` im aktuellen Snapshot nicht mehr `PASS`, sondern
   `INFRA_FAIL` mit tatsächlichem Run; `QM5_1567/XAUUSD` ist inzwischen ein
   neuer `PASS`. Die Priorisierung muss deshalb aus einem bei Bill-Erstellung
   neu erzeugten Offender-Register kommen, nicht aus dauerhaft festcodierten
   Beispielen.

5. **OWNER-Vorlage heißt nicht „PASS bis Entscheidung“.** Ein
   provenance-unverifiziertes Resultat muss bis zur Entscheidung aus Admission,
   Ranking und Live-Reliance ausgeschlossen bleiben.

### Verbesserter Lösungs- und Akzeptanzvertrag

1. Reproduzierbarer Offender-Scanner mit den Klassen:
   `MISSING_FILE`, `UNREADABLE`, `NULL_KPI`, `ZERO_VARIANCE`,
   `PARSE_ERROR_BACKFILL`, `SEED_AUTH_MISSING`,
   `IDENTITY_HASH_MISSING` und `BINARY_VINTAGE_MISMATCH`.
2. Scanner schreibt ein append-only Register; er ändert keine
   `work_items`-Rohzeile. Pipeline-/Dashboard-Leser verwenden den effektiven
   Admission-Status aus dem Overlay.
3. Live/promoted Offender werden fail-closed aus jeder Promotion und
   Portfolioentscheidung entfernt, bis eine neue identitäts- und
   seed-gebundene Q07-Evidenz oder eine OWNER-Entscheidung vorliegt.
4. Vor Rerun: statische Verdrahtungsprüfung plus MNT-043-Binary-Bindung. Rerun
   exakt pro `(EA, Symbol, Setfile, Binary-SHA, Zeitraum)`, nicht nur pro EA.
5. `parse_error`, Backfill, fehlende Datei oder fehlende Seed-Achse können
   strukturell niemals einen effektiven PASS erzeugen.
6. Akzeptanz:
   - kein effektiver Q07-PASS ohne lesbares, hash- und seed-authentifiziertes
     Aggregate;
   - jede Overlay-Zeile ist auf unveränderte Rohzeile und Evidenzhash
     rückführbar;
   - keine Cascade-/Admission-Abfrage konsumiert
     `PROVENANCE_UNVERIFIED`;
   - 13128/NDX besitzt echten Run oder explizite OWNER-Entscheidung;
   - der Offender-Scanner arbeitet über Invarianten und darf keine
     festcodierte Gesamtzahl voraussetzen.

## MNT-045 — Tester-Kalenderabhängigkeit

**Position: 84 % Zustimmung. P1 bestätigt, weil Fail-closed heute falsche
Strategie-PASS verhindert, aber Claim- und Tester-Kapazität unnötig verbrennen
kann.**

### Worin ich zustimme

Die EA-Seite bricht im Tester bei fehlender/unlesbarer Datei tatsächlich
fail-closed ab, während live auf den nativen Kalender degradiert
(`framework/include/QM/QM_NewsFilter.mqh:653-669`). CSV-Parsefehler haben
denselben Tester-/Live-Split
(`framework/include/QM/QM_NewsFilter.mqh:689-702`).

Ein Provisioning-Preflight existiert bereits innerhalb von `run_smoke`: beide
Source- und FILE_COMMON-Dateien, Alter <= 336 Stunden und SHA-Gleichheit werden
als `MISSING_SOURCE`, `MISSING_COMMON`, `STALE_COMMON` oder
`COMMON_MISMATCH` klassifiziert
(`framework/scripts/run_smoke.ps1:2017-2072`) und vor Terminalausführung
fail-closed abgebrochen
(`framework/scripts/run_smoke.ps1:2198-2202`). Die echte Restlücke ist:
dieser Check kommt erst **nach dem Claim**.

### Materielle Dissents

1. **„Tester wie live degradieren“ streichen.** Tester besitzt nicht die
   identische native Kalendergrundlage; eine Degradierung würde die
   verpflichtende News-Blackout-Evidenz entfernen. Der erlaubte Vertrag ist
   fail-hard plus vorgezogener Provisioning-Preflight. Der Guardrail begrenzt
   `qm_news_stale_max_hours` auf maximal 336
   (`tools/strategy_farm/validate_build_guardrails.py:183-192`); er darf
   weder erhöht noch umgangen werden.

2. **Nicht „je Terminal“, sondern je ausführendem Windows-Prinzipal und dessen
   FILE_COMMON.** `run_smoke` leitet den Pfad aus `$env:APPDATA` ab
   (`framework/scripts/run_smoke.ps1:2017-2023`). T1–T10 teilen unter
   demselben Konto diesen Common-Pfad. Bei mehreren Task-Prinzipalen muss pro
   Principal geprüft werden; ein Terminalcache allein wäre semantisch falsch.

3. **Bestehende Diagnose hoisten, nicht duplizieren.** Derselbe Helper soll
   vom Dispatcher vor Reservation/Claim und unmittelbar vor Spawn nutzbar sein.
   Ein früher Cache spart IO; die zweite Prüfung schließt das TOCTOU-Fenster.
   Ein Fehlschlag darf `attempt_count` nicht verbrauchen und keinen
   Terminalprozess starten.

4. **`CALENDAR_MISSING` ist zu grob.** Die bereits implementierten vier
   Zustände plus `PARSE_INVALID` müssen erhalten bleiben. Missing, stale und
   Hash-Mismatch haben unterschiedliche Operatoraktionen.

5. **Der Publisher ist nicht atomar.** Die Source-Dateien werden zuerst
   angehängt
   (`tools/strategy_farm/refresh_news_calendar.ps1:237-240`), danach werden
   beide Dateien einzeln per `Copy-Item -Force` nach Common geschrieben
   (`tools/strategy_farm/refresh_news_calendar.ps1:244-281`). Zwischen den
   Kopien kann ein Claim ein gemischtes Bundle sehen. Erforderlich sind
   temp-Dateien, Parse-/Hash-Prüfung beider Dateien, danach atomischer Replace
   mit gemeinsamem Bundle-Manifest.

6. **„7 Tage grün“ ist Monitoring, kein vollständiger Akzeptanztest.** Ohne
   deterministische Missing/Stale/Mismatch/Partial-Publish-Injektion kann ein
   nie ausgeführter Check sieben Tage grün wirken.

### Verbesserter Lösungs- und Akzeptanzvertrag

1. OWNER-Decision festschreiben: Tester bleibt fail-hard; keine
   Degrade-Option. Ein INIT-Fehler wird durch Refresh von
   `D:\QM\data\news_calendar` **und** FILE_COMMON behoben.
2. Kalenderdiagnose in einen side-effect-free Helper extrahieren und mit
   identischer Taxonomie vor Claim sowie direkt vor Spawn aufrufen.
3. Bei Fehler: Work-Item bleibt unclaimed/deferred, `attempt_count` unverändert,
   kein `terminal64.exe`, Taxonomie und Principal/Common-Pfad werden geloggt.
4. Publisher aktualisiert ein versioniertes Zwei-Dateien-Bundle atomar und
   publiziert Manifest, SHA-256 und `generated_at`.
5. Deterministische Tests für missing source, missing Common, stale >336,
   Hash-Mismatch, Parsefehler und unterbrochenen Zwei-Dateien-Publish; alle
   ohne Terminalstart.
6. Operative Akzeptanz zusätzlich: sieben Tage keine claim-bedingte
   Kalender-Verbrennung, aber nur nach bestandenen Fault-Injection-Tests.

## MNT-046 — Factory_OFF und Phase-Runner

**Position: 86 % Zustimmung. P1 bestätigt.**

### Worin ich zustimme

Die Lücke ist im aktuellen Code klar: der gemeinsame Scope-Vertrag verlangt
exakte Pfade und positive Factory-Selektoren; Basename-/Substring-Matches sind
verboten
(`tools/strategy_farm/factory_process_scope.ps1:3-16`). Der Python-Matcher
deckt den exakten `terminal_worker.py` mit T1–T10 und Farm-Root ab
(`tools/strategy_farm/factory_process_scope.ps1:128-156`), aber keinen
Phase-Runner.

`Factory_OFF.ps1` stoppt zuerst Tasks/Respawner
(`tools/strategy_farm/Factory_OFF.ps1:63-81`), dann Worker und
`run_smoke`
(`tools/strategy_farm/Factory_OFF.ps1:84-98`) sowie T1–T10
Terminal-/Tester-Images. Der abschließende Scan zählt jedoch nur Worker,
Terminals und Tester
(`tools/strategy_farm/Factory_OFF.ps1:115-150`). Ein verwaister Phase-Runner
bleibt sowohl beim Reap als auch beim Verify unsichtbar.

### Materielle Dissents

1. **Kein „q*-Runner unter `C:\QM\repo`“-Glob.** Das würde genau den breiten
   Substring-/Pfadklassifikator wieder einführen, den der Sicherheitsvertrag
   verbietet. Die kanonische exakte Allowlist existiert bereits als
   `PHASE_RUNNER_SCRIPTS`
   (`tools/strategy_farm/farmctl.py:126-147`) und muss aus einer
   gemeinsam gepflegten Datenquelle in den PowerShell-Classifier gelangen.

2. **Scriptpfad allein reicht ebenfalls nicht.** Ein Runner ist
   Factory-owned nur mit eindeutigem direkten Work-Item-Report-Root
   `D:\QM\reports\work_items\<UUID>` und, wo der Runner ihn trägt, einem
   T1–T10-Selector. Die Factory baut genau diesen Root und die Runner-Commandline
   in
   `tools/strategy_farm/farmctl.py:3791-3807` beziehungsweise
   `tools/strategy_farm/farmctl.py:13764-13776`. Fehlende, doppelte oder
   mehrdeutige Argumente müssen fail-closed **nicht matchen**.

3. **Reap-Reihenfolge ergänzen.** Nach Deaktivieren der Respawn-Vektoren:
   Phase-Runner-Eltern vor `run_smoke`, danach Terminal-/Tester-Kinder.
   Andernfalls kann ein überlebender Runner zwischen Wrapper- und
   Terminal-Sweep erneut spawnen.

4. **Verify braucht stabile Quieszenz, nicht einen einzelnen Scan.** Zwei
   aufeinanderfolgende Null-Scans nach kurzer bounded Settling-Phase, jeweils
   mit PID, ParentPID, gehashter Commandline und Matcher-Grund, sind stärker
   als „zehn Minuten kein Respawn“ ohne definierte Beobachtung.

5. **Regressionstest nicht als gewöhnlichen destruktiven Unit-Test bauen.**
   Die bestehende Suite prüft Parser, side-effect-free Helper und verbietet
   breite Klassifikatoren
   (`tools/strategy_farm/tests/Test-FactoryProcessScope.ps1:185-236`).
   Dazu gehören synthetische positive/negative Phase-Runner-Commandlines.
   Ein echter OFF-End-to-End-Test gehört in ein OWNER-kontrolliertes,
   nicht-live Wartungsfenster und darf weder T5 noch T_Live verwenden oder
   einen echten MT5-Lauf starten.

### Verbesserter Lösungs- und Akzeptanzvertrag

1. Neue side-effect-free Funktion
   `Test-QmFactoryPhaseRunnerCommandLine`:
   - Interpreter exakt `python.exe`/`pythonw.exe`;
   - Script exakt Mitglied der versionierten `PHASE_RUNNER_SCRIPTS`-Allowlist;
   - `--out-prefix` exakt direkter UUID-Kindpfad unter
     `D:\QM\reports\work_items`;
   - vorhandener Terminalselector exakt T1–T10;
   - doppelte, relative, fehlende oder mehrdeutige Identität matcht nicht.
2. `Factory_OFF`: Respawner aus -> Phase-Runner -> Worker/Wrapper ->
   Terminal/Tester; jede Klasse mit Before-/After-Evidenz.
3. Abschließender Quieszenzvertrag umfasst Worker, Phase-Runner,
   `run_smoke`, T1–T10 `terminal64.exe` und `metatester64.exe`; zwei stabile
   Null-Scans sind erforderlich.
4. Unit-Tests pinnen jeden erlaubten Runner sowie negative
   Basename-, Fremdroot-, T_Live-, T5-, Duplicate-Option- und
   `work_items_evil`-Fälle. Der Helper bleibt side-effect-free.
5. Ein separat OWNER-freigegebener nicht-live Integrationstest belegt Reap
   und ausbleibenden Respawn. Der Test ist kein Bestandteil dieses Review-Tasks
   und wurde hier nicht ausgeführt.

## Reviewer-Fazit

WP-1 erfüllt den verfeinerten Anzeigevertrag, ohne Infrastrukturzustand zu
verstecken. Für WP-2 ist MNT-044 nach Einbau der unveränderlichen
Adjudication-Ebene konvergenzreif. MNT-043 braucht die Trennung von
Live-Sicherheitsbill und Flotten-Requalifikation; MNT-045 eine fest
fail-closed OWNER-Decision plus Pre-Claim-Provisioning; MNT-046 eine exakte,
identitätsgebundene Runner-Klassifikation statt eines Globs.

Keine dieser Positionen autorisiert Build, Deploy, Factory-OFF oder Änderung
historischer Pipeline-Verdicts.
