# Claude-Handoff: unabhängiger Audit von W6–W8 und den Dashboards

Du bist Claude in der Rolle eines unabhängigen Senior-Auditors für QuantMechanica. Prüfe den vollständigen Implementierungsstack ab Commit `b62cf063` bis zum Auditzeitpunkt vorliegenden finalen `HEAD`, einschließlich der nachfolgenden, zuletzt integrierten W6-/W7-/W8- und Dashboard-Welle.

Arbeite evidenzgetrieben. Vertraue weder Commit-Texten noch Statusdokumenten, Dashboard-Anzeigen oder früheren Auditberichten ohne unabhängige Reproduktion. Ein grüner Test ersetzt keine Architekturprüfung, ein vorhandenes Artefakt ersetzt keine Runtime-Integration, und ein Dashboard-Label ersetzt keine Autorisierung.

## 1. Ziel und erwartetes Ergebnis

Beantworte unabhängig:

1. Ist der Commit-Stack technisch korrekt, deterministisch und fail-closed?
2. Sind alle Sicherheitsgrenzen während der Umsetzung und während deines Audits eingehalten?
3. Sind W6, W7 und W8 ehrlich klassifiziert, insbesondere:
   - W6 nur als `PARTIAL` beziehungsweise `PARTIAL_SOURCE_IMPLEMENTED`, solange die Flotte nicht vollständig migriert, kompiliert und prospektiv belegt ist;
   - W7 nur als `DRY_RUN`, `PLAN_ONLY` oder `NOT_APPLIED`, solange keine OWNER-autorisierte Migration erfolgt ist;
   - W8 nur als `SOURCE_ONLY`, `SHADOW` oder gleichwertige Vorstufe, solange weder ein reales Zielbuch zugelassen noch eine FTMO-Challenge gekauft oder gehandelt wurde?
4. Stimmen Source, Tests, Schemas, MQL-Verträge, Dokumentation und Generatoren überein, und ist der getrennte Deploymentzustand der beiden durch Canonical-Tasks verwalteten HTML-Dateien ehrlich ausgewiesen?
5. Werden Legacy-Q08-Urteile wie `FAIL_SOFT` klar von Q08-v3-Evidenzurteilen getrennt?
6. Wurden vorhandene Claude-eigene Dokumente oder Briefs durch die neue Implementierung sachlich überholt?

Liefere am Ende:

- einen vollständigen Auditbericht;
- Findings nach Severity;
- gegebenenfalls einen eng begrenzten Dokumentationspatch;
- ein Patch-Receipt für jede von dir geänderte Datei;
- eine explizite Vorher-/Nachher-Sicherheitsbilanz.

## 2. Verbindliche Zahlen- und Hash-Regel

Übernimm keine finale Testzahl, Dateianzahl, Diffstatistik, Commit-ID, Artefaktgröße, SHA-256 oder Statuszählung aus diesem Prompt oder aus einem früheren Bericht.

Für jede solche Angabe gilt ausdrücklich:

> **Aus finalem Evidence-Receipt lesen und unabhängig nachrechnen.**

Wenn kein finales Evidence-Receipt vorhanden ist, dessen Stack-Basis und `HEAD` exakt zu deinem Auditobjekt passen, ist das ein Finding. Erfinde keine Ersatzwerte und verwende keine alten Zahlen als vermeintlich finale Baseline.

Im Bericht müssen behauptete und selbst gemessene Werte getrennt stehen. Abweichungen sind zu erklären, nicht zu glätten.

## 3. Absolute Sicherheitsgrenze

Die Factory wurde vom OWNER absichtlich abgeschaltet. Das ist kein Defekt und keine Aufforderung zur Reaktivierung.

Während des gesamten Audits verboten:

- Factory ON oder OFF ausführen oder das OFF-Flag verändern;
- `FACTORY_MUTATION.lock` erzeugen, entfernen oder übernehmen;
- Scheduled Tasks aktivieren, deaktivieren, starten, stoppen, registrieren oder umschreiben;
- Factory-Worker, Phase-Runner, Smoke-Runner, Metatester oder Terminals starten oder beenden;
- `T_Live` neu starten, stoppen, konfigurieren oder anderweitig berühren;
- den AutoTrading-Zustand verändern;
- irgendeine produktive SQLite-Datenbank beschreiben, migrieren, vacuumieren oder reparieren;
- Deployments, Setfile-Kopien, Preset-Änderungen oder Registry-Mutationen durchführen;
- eine FTMO-Challenge oder andere Leistung kaufen;
- Geld-, Risiko- oder Live-Entscheidungen auslösen;
- `D:\QM\strategy_farm\dashboards\strategies.html` oder `D:\QM\strategy_farm\dashboards\cockpit.html` neu rendern oder überschreiben;
- bestehende Canonical-Dirty-Änderungen in `C:\QM\repo` verändern, stagen, committen, verschieben, löschen oder formatieren.

Alle produktiven Datenquellen sind ausschließlich read-only zu öffnen. SQLite nur über URI `mode=ro` und zusätzlich `PRAGMA query_only=ON`; wenn möglich auch `immutable=1`. Verwende keine Anwendung, deren Initialisierung bereits Tabellen, Metriken, Caches oder State-Dateien aktualisiert.

Die Dashboard-Hauptprogramme dürfen nicht gegen `D:\QM\strategy_farm` gestartet werden: ihre normalen Main-Pfade schreiben HTML, Render-State und teilweise abgeleitete Metriken. Verwende stattdessen pure Renderfunktionen, Fixtures oder einen vollständig isolierten temporären Root.

## 4. Zulässige Arbeitsumgebung

Auditiere einen sauberen, dedizierten Worktree auf dem finalen Ziel-`HEAD`. Arbeite nicht direkt im schmutzigen Canonical-Worktree.

Vorbedingung:

- `b62cf063` ist auflösbar;
- das finale `HEAD` enthält die gesamte zur Prüfung übergebene W6-/W7-/W8-/Dashboard-Welle;
- der Audit-Worktree ist vor deinen optionalen Dokumentationsänderungen clean;
- das finale Evidence-Receipt bindet den unmittelbar vorhergehenden Implementierungscommit; ein einzelner nachfolgender, reiner Receipt-Commit ist zulässig und von dir unabhängig als solcher zu verifizieren.

Falls die Welle noch uncommitted ist, `HEAD` und Evidence-Receipt nicht zusammenpassen oder du nur einen halb integrierten Worktree siehst: keine fremden Änderungen übernehmen oder committen. Dokumentiere den Blocker und fordere den korrekten finalen Auditstand an.

Prüfe den Stack einschließlich des Baseline-Commits mit einer Range entsprechend:

```powershell
git show --no-patch --format=fuller b62cf063
git log --reverse --format=fuller b62cf063^..HEAD
git diff --stat b62cf063^..HEAD
git diff --name-status b62cf063^..HEAD
git diff --check b62cf063^..HEAD
```

Ermittle `HEAD`, Commitliste, Dateizahlen und Diffstatistik selbst. Werte dafür: **aus finalem Evidence-Receipt lesen und unabhängig nachrechnen**.

## 5. Sicherheitsbaseline vor dem Audit

Erhebe vor jeder Testsuite und vor jeder optionalen Dokumentationsänderung eine read-only Baseline. Speichere die Messwerte in deinem Audit-Evidence-Verzeichnis, nicht unter Runtime- oder T_Live-Pfaden.

Mindestens erfassen:

1. `FACTORY_OFF.flag`
   - absoluter Pfad;
   - Existenz;
   - Bytegröße;
   - SHA-256;
   - LastWriteTime;
   - Schema-/Inhaltsprüfung ausschließlich read-only.
2. `FACTORY_MUTATION.lock`
   - Existenz, Größe und SHA, falls wider Erwarten vorhanden;
   - niemals löschen oder verändern.
3. Scheduled Tasks
   - die erwarteten OFF-/Quiescence- und `ENFORCE_DISABLED`-Keysets aus dem versionierten Source ableiten;
   - tatsächlichen Enabled-State read-only abfragen;
   - zusätzliche relevante QM-Tasks separat ausweisen;
   - nichts schalten.
4. Prozesse
   - Factory-Worker, Phase-Runner, Smoke-Prozesse, T1–T10-Terminals, Metatester und Near-Matches read-only klassifizieren;
   - den versionierten Scope-Klassifizierer gegen die reale Liste anwenden, aber keinen Reaper ausführen;
   - `T_Live` mit PID, vollständigem Pfad und Startzeit separat festhalten;
   - `T_Live` darf niemals als Factory-Reap-Kandidat erscheinen.
5. Canonical-Worktree `C:\QM\repo`
   - Branch/HEAD;
   - vollständiges `git status --porcelain=v2`;
   - SHA-256 aller bereits geänderten und untracked Dateien;
   - dieser Zustand ist user-owned und muss nach dem Audit byte-identisch bleiben.
6. Audit-Worktree
   - Branch, HEAD und Cleanliness.
7. Gerenderte Dashboards und autonome Render-Provenienz
   - `D:\QM\strategy_farm\dashboards\strategies.html`;
   - `D:\QM\strategy_farm\dashboards\cockpit.html`;
   - jeweils Existenz, Größe, SHA-256, LastWriteTime und Render-Badge/Renderzeit read-only erfassen;
   - `QM_StrategyFarm_Cockpit_2min` und `QM_StrategyFarm_Dashboard_Hourly` einschließlich Action, Working Directory, LastRunTime, NextRunTime und LastTaskResult read-only erfassen;
   - beachten: beide ALWAYS_ON-Tasks laufen absichtlich aus `C:\QM\repo` weiter und dürfen die Dateien während des Audits autonom ersetzen. Eine solche Änderung ist anhand Task-History und Generator-Provenienz zuzuordnen; sie ist weder als Auditmutation zu verschweigen noch fälschlich dem Auditor anzulasten.
8. Produktive Datenbank
   - nur wenn für einen Claim wirklich nötig: Dateihash und read-only Schema-/Census-Abfragen;
   - keine Verbindung ohne `mode=ro`, `query_only=ON` und nach Möglichkeit `immutable=1`.

Wenn der GUI-Zustand des T_Live-AutoTrading-Buttons nicht verlässlich read-only abfragbar ist, sage das ausdrücklich. Erfinde keine Bestätigung. Belege stattdessen, dass dein Audit weder Prozess, Dateien noch Konfiguration verändert hat.

## 6. Zu lesende Autoritäten

Lies vollständig, nicht nur auszugsweise:

- `CLAUDE.md`;
- `docs/ops/evidence/2026-07-29_pipeline_books_w6_w8_dashboard_wave.md`;
- `docs/ops/evidence/2026-07-29_pipeline_books_dashboard_render_receipt.md`;
- `docs/ops/MASTER_PIPELINE_BOOKS_IMPLEMENTATION_PLAN_2026-07-29.md`;
- `docs/ops/evidence/2026-07-29_pipeline_books_foundation_wave.md`;
- `docs/ops/MNT_IMPLEMENTATION_STATUS_2026-07-29.json` und die korrespondierende MD-Sicht;
- den ursprünglichen Claude-Auditbericht beziehungsweise dessen versionierte Ablage, sofern vorhanden;
- alle im finalen Receipt referenzierten Evidence-Dateien;
- die versionierten Gate-, Rulepack-, Q08-, Execution-Bundle-, Card-, Governance-, Lifecycle-, Migration-, W8- und Dashboard-Schemas.

Prüfe Links, Hashbindungen und Statusclaims. Ein Dokument darf nicht dadurch als wahr gelten, dass ein zweites Dokument es zitiert.

## 7. Auditstrang A – kompletter Commit-Stack

Prüfe jeden Commit von `b62cf063` bis `HEAD` einzeln und zusätzlich den Gesamtdiff gegen `b62cf063^`.

Für jeden Commit:

- Parent und Reihenfolge;
- Name-Status und Diffstatistik;
- hinzugefügte, geänderte, gelöschte und umbenannte Dateien;
- Binärartefakte, generierte Dateien und Evidence-JSONs;
- unbeabsichtigte Runtime-, T_Live-, Preset-, Task- oder DB-Pfade;
- Testabschwächungen, neue `skip`, `xfail`, gelockerte Assertions oder Fail-open-Fallbacks;
- hardcodierte lokale Pfade, veraltete Gate-Namen und Legacy-P/Q-Verwechslungen;
- Dokumentationsclaims gegenüber tatsächlichem Source und Tests.

Prüfe zusätzlich, dass die aktuelle Welle nach ihrem Commit vollständig in `HEAD` enthalten ist und keine für den Claim nötigen Dateien nur untracked im Implementierungsworktree lagen.

## 8. Auditstrang B – bestehende Foundation und frühere Findings

Revalidiere die Foundation aus dem vorigen Stack, insbesondere:

- Factory-OFF- und Mutation-Lock-Protokoll;
- Claim-Fence und globale Writer-Koordination;
- Restore-Intent-Freshness und PID-/Nonce-/StartTime-Identität;
- ENFORCE_DISABLED-Hazards während OFF;
- Prozess-Scope samt Interpreter-Flag-Whitelist und T5/T_Live-Ausschluss;
- Weakref-/Objektidentitäts-Cache in allen betroffenen FTMO-Screens;
- MNT009/010- und MNT012-Reconciliation-Verträge;
- Gate-Manifest Q00–Q13;
- immutable Execution Bundle;
- Strategy Card V3;
- Source-Authorization, getrennte Agent-/OWNER-G0-Entscheidungen und Experiment-Records;
- Q08-v3-Shadow-Policy und Calendar-Evidence-Series;
- DXZ- und FTMO-Target-Rulepacks;
- Green-/External-Residual-Testlanes.

Prüfe, ob die neue Welle diese Verträge korrekt konsumiert oder parallel eine widersprüchliche zweite Wahrheit erzeugt.

## 9. Auditstrang C – W6 EA-/Runtime-Framework

Prüfe mindestens die tatsächlich geänderten oder neu hinzugefügten Komponenten rund um:

- `framework/include/QM/QM_RuntimeExecutionContract.mqh`;
- `framework/include/QM/QM_Common.mqh`;
- `framework/include/QM/QM_Entry.mqh`;
- `framework/include/QM/QM_BasketOrder.mqh`;
- `framework/include/QM/QM_RiskSizer.mqh`;
- `runtime_execution_contract_smoke.mq5`, `entry_execution_identity_smoke.mq5`,
  `basket_order_execution_policy_smoke.mq5` und die übrigen zugehörigen
  MQL-/Static-Smoke-Fixtures;
- `framework/scripts/update_magic_resolver.py` und Strict-Default-Tests;
- `tools/strategy_farm/windows_job_object.py` und Containment-Tests;
- `tools/strategy_farm/mt5_history_isolation.py` und Isolationstests;
- `tools/strategy_farm/work_item_lifecycle_v2.py`, Schema und Tests;
- die begrenzten Integrationsänderungen in `farmctl.py` sowie Cascade-/Basket-Tests.

Beantworte konkret:

1. Ist die neue Runtime-Execution-Identity eine echte one-way state machine und hashgebunden?
2. Führen inkonsistente EA-, Magic-, Symbol-, Timeframe-, Account-, Server-, Card-, Bundle-, Rulepack-, Magic-Registry- oder Source-Generation-Identitäten fail-closed zum Entry-Block?
3. Kann ein Vertrag innerhalb eines Prozesses still neu gebunden, durch einen Legacy-Init zurückgesetzt oder über ein produktiv sichtbares Reset-Symbol gelöscht werden?
4. Ist FTMO ohne erforderlichen Governor beziehungsweise bei ungültigem/stalem Governor-Vertrag blockiert?
5. Bleibt der Legacy-Pfad bewusst als `LEGACY_UNDECLARED` kompatibel, und wird genau deshalb nirgends behauptet, W6 sei fleetweit abgeschlossen?
6. Verhindert der Entry-Pfad neue Orders, ohne die Verwaltung bereits offener Positionen zu zerstören?
7. Bleiben Fixed-Risk- und Percent-Risk-Modi semantisch getrennt und ohne Risk-Creep?
8. Sind Magic-Resolver-Defaults streng, deterministisch und mit realen Zeilenenden/BOM-Fällen getestet?
9. Werden beide produktiven Runner auf Windows bereits mit `CREATE_SUSPENDED` erzeugt und erst nach exakter Popen-Handle-Zuordnung, Job-Assignment, Identity-Capture und Registry-Retention resumed? Prüfe Assign-, Identity-, Registry-, PID-/Thread- und Resume-Fehler samt Tree-Kill/Wait-Cleanup sowie die Lebensdauer des residenten `terminal_worker` als Handle-Owner.
10. Erkennt der read-only History-Audit nicht nur exakte Same-Component-Kollisionen, sondern auch Cross-Component- und Ancestor/Descendant-Überlappungen in beide Richtungen sowie symmetrische Überschneidungen mit T5/T_Live? Die einzige zulässige Ausnahme ist `Bases` → `Bases/Custom` desselben Terminals. Der Audit implementiert keine physische Isolation und darf auch nicht so beschrieben werden.
11. Ist die Lifecycle-v2-Sicht eine read-only, content-addressed Projektion ohne Apply-Pfad, mit disjunkten vollständigen Verdict-Klassen? Müssen unbekannte Verdicts, pending/active mit Verdict und failed mit PASS-like Verdict fail-closed scheitern?
12. Verändert `farmctl` dadurch keine produktive Lifecycle-Semantik oder DB ohne separat autorisierten Apply?
13. Können Standard-Entry oder Basket nach einem gültigen V3-Init eine andere EA-ID, ein anderes Symbol oder eine andere Magic wählen? Der aktuelle V3-Vertrag ist absichtlich Single-Identity; Multi-Symbol/-Magic muss bis zu einem eigenen versionierten Vertrag blockiert bleiben.
14. Durchlaufen V3-Baskets exakt dieselben directional `OrderCalcProfit`-, Broker-Margin- und FTMO-Governor-Rails, und können explizite Lots diese Rails ausschließlich reduzieren, niemals vergrößern?

MQL-Prüfung:

- lies alle geänderten `.mqh`- und `.mq5`-Dateien vollständig;
- führe die versionierten Python-Static-/Contract-Tests aus;
- verifiziere vorhandene Compile-Evidence und deren Source-/EX5-Hashes, falls das finale Receipt solche Claims enthält;
- starte keinen Terminalprozess;
- kompiliere nicht in T1–T10 oder T_Live;
- wenn eine echte isolierte MQL-Kompilation nicht ohne Mutation oder Terminalstart reproduzierbar ist, markiere sie als nicht reproduziert und prüfe stattdessen Source, Fixtures und vorhandene hashgebundene Compile-Receipts.

Das zulässige Höchsturteil für W6 ist ohne vollständige Flottenmigration und prospektive Runtime-Evidence `PARTIAL` beziehungsweise `PARTIAL_SOURCE_IMPLEMENTED`. Jede höhere Behauptung ist eigens zu belegen oder als Finding zu melden.

## 10. Auditstrang D – W7 Migration und Re-Adjudikation

Prüfe mindestens:

- `tools/strategy_farm/q08_v3_migration_inventory.py`;
- `tools/strategy_farm/q08_v3_migration_plan.py`;
- beide zugehörigen Schemas;
- Tests für Inventory, Binding, Collision, Discordance und Plan-Hash;
- Lifecycle-v2-Plan und seine Trennung von einer späteren Apply-Operation.

Beantworte:

1. Wird die produktive DB ausschließlich read-only geöffnet?
2. Gibt es im W7-Code irgendeinen Apply-, UPDATE-, INSERT-, DELETE-, Task-Enqueue- oder Overlay-Mutationspfad?
3. Sind Inventory und Plan content-addressed und create-new-only?
4. Werden Work-Item-ID, Alias und Lineage eindeutig und kollisionssicher aufgelöst?
5. Bleiben `NO_MATCH`, Ambiguität, Mehrfachbindung und ungültige V3-Evidence fail-closed?
6. Ist die Discordance-Taxonomie deterministisch und verhindert sie, dass Legacy `FAIL_SOFT` automatisch zu `CONDITIONAL` wird?
7. Ist jede spätere Re-Adjudikation explizit OWNER-gated und außerhalb dieses Commits?
8. Stimmen Schema, Modul, Tests und Dokumentation exakt überein?
9. Binden Inventory und Shadow-Manifest exakt das eine repository-eigene Policy-Artefakt per Pfad, Raw-File-SHA, semantischem Canonical-SHA und Policy-Version, sodass ein syntaktisch gültiges Ersatz-Policy-JSON abgelehnt wird?
10. Enthält jede Shadow-Bindung normalisierte echte `SubtestResult`-Datensätze, und wird die Decision mit dem produktiven `aggregate_shadow` vollständig neu berechnet statt als deklarierter Verdict akzeptiert?
11. Ist das normalisierte Binding-Manifest vollständig im Plan enthalten und validiert `validate_plan` Policy, Manifest-Hash, Decision-/Binding-Hashes sowie Matched/Unresolved-Zuordnung erneut? Baue als Negativprobe einen intern neu gehashten Fake-Plan; er muss trotzdem scheitern.

W7 muss im Bericht als `DRY_RUN_ONLY`, `PLAN_ONLY` beziehungsweise `NOT_APPLIED` erscheinen. Ein vorhandener Plan ist keine ausgeführte Migration. Verifiziere außerdem read-only, dass die produktive DB durch diese Welle nicht verändert wurde; verwende dafür Baseline-/Receipt-Hashes und keine Schreibabfrage.

## 11. Auditstrang E – W8 Outcome-Dossier

Prüfe vollständig:

- `tools/strategy_farm/target_outcome_dossier.py`;
- `tools/strategy_farm/schemas/target_outcome_dossier_v1.schema.json`;
- `tools/strategy_farm/tests/test_target_outcome_dossier.py`;
- beide bestehenden Target-Rulepacks und deren kanonische Hashberechnung.

Beantworte:

1. Bindet jedes Dossier exakt beide Rulepacks per unabhängig nachgerechnetem canonical SHA-256?
2. Sind DXZ- und FTMO-Evidence-IDs global eindeutig und gegen Cross-Lane-Laundering geschützt?
3. Wird jede deklarierte Evidence-Datei unter dem erlaubten Root tatsächlich strict-resolved und geöffnet, ihr SHA unabhängig neu berechnet und Pfadtraversal beziehungsweise Escape verworfen?
4. Verlangt `SEALED` eine reale, vom Artefakt verschiedene Seal-Datei, deren Datei-SHA stimmt und deren strictes Payload exakt `schema_version`, `evidence_id`, Lane, Slot, Artifact-Pfad/-SHA und Fidelity bindet?
5. Wird Cross-Lane-Reuse unabhängig über resolved Artifact-Pfad, Artifact-SHA, resolved Seal-Pfad und Seal-SHA abgelehnt, auch bei unterschiedlichen Evidence-IDs?
6. Werden fehlende, `APPROXIMATE`, `UNSEALED` oder unvollständig versiegelte Evidenzen zwingend `NO_GO`?
7. Sind Provider-Regeln und interne QM-Entscheidungskriterien strukturell getrennt?
8. Wird das OWNER-Gate als `PENDING_OWNER` behandelt, ohne einen fehlenden OWNER-Entscheid als technischen PASS zu maskieren?
9. Werden alle FTMO-Wahrscheinlichkeits-, Breach-, Freshness-, Fidelity-, MTM- und Free-Trial-Schwellen aus dem gebundenen Rulepack gelesen statt dupliziert oder hardcodiert?
10. Liegen alle Wahrscheinlichkeiten zwischen 0 und 100, ist das untere P1-Konfidenzband höchstens der P1-Punktschätzer und ist Joint höchstens P1 sowie conditional P2?
11. Werden DXZ-Incumbent und Challenger nur auf sealed Evidence verglichen und müssen Return, Drawdown und Return/Drawdown-Vergleich sowie Probation die gebundenen Kriterien erfüllen? Prüfe außerdem Return >= -100 %, Drawdown 0..100 % und R/DD > 0.
12. Ist sichtbare Evidence Debt für `CONDITIONAL` zwingend, während `INSUFFICIENT`, `CONTRADICTED` und `INVALID` nicht hochgewichtet werden können?
13. Ist die höchste mögliche maschinelle Ausgabe ausschließlich `READY_FOR_OWNER_DECISION`, niemals `GO`, `BUY`, `DEPLOY` oder eine gleichwertige Auto-Autorisierung?
14. Sind `runtime_action`, `factory_action`, `mt5_action`, `purchase_action` und `deployment_action` immer `NONE` und `owner_decision_required=true`?
15. Ist der Dossier-Hash deterministisch und werden existierende Dateien niemals überschrieben?
16. Decken Tests Hash-/File-/Seal-Tampering, Duplicate Keys, Floats, Pfadtraversal, fehlende Evidenz, Cross-Lane-Pfad-/Hash-Reuse, Beziehungsfehler und Threshold-Grenzwerte ab?

W8 ist ein Source-/Shadow-Evaluator. Er beweist nicht, dass aktuell ein besseres DXZ-Buch existiert oder dass eine FTMO-Challenge kaufreif ist. Klassifiziere W8 entsprechend ehrlich als `SOURCE_ONLY`/`SHADOW`, solange keine separat autorisierte, reale Evidenz vorliegt.

## 12. Auditstrang F – gemeinsamer Dashboard-Statusvertrag

Prüfe vollständig:

- `tools/strategy_farm/pipeline_books_dashboard_status.py`;
- `tools/strategy_farm/config/pipeline_books_program_status.v1.json`;
- `tools/strategy_farm/schemas/pipeline_books_program_status_v1.schema.json`;
- die zugehörigen Tests;
- alle vom Statusdokument gebundenen Plan-, Evidence-, Policy-, Testlane- und Rulepack-Dateien.

Prüfe:

1. Duplicate-Key-, Float-, Nonfinite-, Path- und Exact-Key-Rejection.
2. Unabhängig nachgerechnete File- und Canonical-Hashes.
3. Exakte W0–W8-Keysets und Zielpfade.
4. `FRESH`, `STALE`, `MISSING`, `INVALID` als explizite Zustände.
5. `MISSING`/`INVALID` dürfen niemals als leere grüne Sicht erscheinen.
6. `STALE` darf höchstens die letzte validierte Sicht mit klarer Warnung zeigen.
7. Nach finalen W6-/W7-/W8-Dokuänderungen müssen Plan-/Evidence-Bindings im Statusdokument auf den finalen Bytes basieren.
8. Safety-Felder dürfen keinerlei Runtime-Autorisierung enthalten.
9. Testzahlen, Residual-Anzahl und Work-Package-Status müssen dem finalen Evidence-Receipt entsprechen: **aus finalem Evidence-Receipt lesen und unabhängig nachrechnen**.

Ein hash-ungültiges oder sachlich veraltetes Statusdokument ist mindestens ein Dashboard-/Dokumentationsfinding; es darf nicht durch Lockerung des Validators „repariert“ werden.

## 13. Auditstrang G – Dashboard-Generatoren und gerenderte HTML-Dateien

Die reale Publikationsgrenze ist Teil des Audits: Die ALWAYS_ON-Tasks starten die
Generatoren aus `C:\QM\repo`, nicht aus einem Audit- oder Integrationsworktree. Vor
Integration darf eine manuelle Worktree-Ausgabe daher nur ein transienter Preview sein
und wird beim nächsten Tasklauf erwartbar durch die Canonical-Version ersetzt. Prüfe
Receipt-Zeitstempel, Task-History und beide transienten Render-Hashes unabhängig. Melde
einen fehlenden oder verschleierten Deploymenthinweis als Finding; behandle die ehrlich
dokumentierte, taskverursachte Ersetzung nicht als Runtime-Autorisierung der Welle.
Der finale Receipt dokumentiert außerdem eine produktive DB-Hashänderung, deren Mtime
direkt auf den noch alten Canonical-Hourly-Renderer folgt. Reproduziere diese Zuordnung
read-only. Verschweige den Drift nicht; schreibe ihn aber nur dann dem Implementierungs-
worktree zu, wenn du einen entsprechenden Schreibpfad oder Prozessbeleg findest.

Prüfe Source und Output paarweise:

### Strategy Archive

- Generator: `tools/strategy_farm/dashboards/render_dashboards.py`
- Output: `D:\QM\strategy_farm\dashboards\strategies.html`

### Cockpit

- Generator: `tools/strategy_farm/render_cockpit.py`
- Output: `D:\QM\strategy_farm\dashboards\cockpit.html`

Prüfe im Source:

- beide Renderer konsumieren denselben strikten Statushelper;
- kein Renderer rekonstruiert W0–W8-Claims heuristisch aus Legacy-DB-Zeilen;
- `MISSING`/`INVALID` werden sichtbar fail-closed gerendert;
- `STALE` ist unübersehbar;
- W0–W8, Q08-v3, DXZ/FTMO-Lanes, Rulepack-Hashes, Testlanes, Residuals und OWNER-Blocker stammen aus dem gemeinsamen Vertrag;
- die fünf orthogonalen Dimensionen bleiben getrennt: Execution Status, Evidence Strength, Economic Merit, Target Eligibility, Promotion Decision;
- Legacy-Q08-Work-Item-Verdicts sind ausdrücklich `LEGACY` und werden nicht als Q08-v3 `SUPPORTED` oder `CONDITIONAL` umgedeutet;
- der kanonische Gate-Bereich ist Q00–Q13, nicht Q00–Q14;
- kein Dashboardtext behauptet Kauf-, Deploy-, Money-, Factory-, MT5- oder AutoTrading-Autorität;
- der OWNER-Decision-Feed unterscheidet echte OWNER-Entscheidungen von Agent-/Programmstatus;
- Quota-/Health-Information wird durch den neuen Block nicht verfälscht.
- der volle Hourly-Pfad überspringt `ea_metrics`-Upserts bei vorhandenem oder nicht
  sicher lesbarem `FACTORY_OFF.flag`;
- alle übrigen SQLite-Lesezugriffe beider Renderer verwenden `mode=ro` und
  `PRAGMA query_only=ON`.

Prüfe die tatsächlichen D:-HTML-Dateien read-only:

- stimmen Render-Badge, Statuszustand und programmatische Marker mit dem finalen Source überein?
- sind Q08-v3-Fünfzustand, beide Target-Lanes und ehrliche W6-/W7-/W8-Klassifikationen vorhanden?
- bleiben Legacy-`FAIL_SOFT`-Zeilen sichtbar als Legacy?
- sind External-Residuals und offene OWNER-Blocker sichtbar?
- stimmen dargestellte Hash-Kurzformen mit den vollständigen, validierten Source-Hashes überein?
- enthält eine Seite alte Q00–Q14-, Auto-GO- oder „W8 complete“-Texte?
- zeigen beide Seiten dieselbe Programmbaseline oder sind sie gegeneinander gedriftet?

Source-vs-rendered-Vergleich ohne D:-Mutation:

- rufe nur pure Funktionen wie `program_status_snapshot`, `render_pipeline_books_program_status`, `pipeline_books_program_snapshot` und `render_pipeline_books_program` auf;
- rendere Strings ausschließlich im Speicher oder in einem neu erzeugten temporären Auditverzeichnis;
- rufe nicht den produktiven `main()`-Pfad gegen `D:\QM\strategy_farm` auf;
- vergleiche semantische Marker und gebundene Werte; verlange wegen Zeitstempeln nicht blind Bytegleichheit;
- wenn der D:-Output älter oder inkonsistent ist, melde das als Finding und schreibe ihn nicht selbst um.

Wenn sich ein D:-Hash während des Audits ändert, muss die Änderung entweder exakt einer
ALWAYS_ON-Ausführung zugeordnet oder als Finding gemeldet werden. Der Auditor selbst darf
keine der beiden Dateien schreiben.

## 14. Auditstrang H – Schemas, Serialisierung und Content Addressing

Prüfe alle im Stack neu hinzugefügten oder geänderten JSON-Schemas und ihre Python-Validatoren:

- Draft-Version;
- `additionalProperties: false` und Exact-Key-Entsprechung;
- Enum-, Null-, Integer-, Decimal-String-, UTC-, Identifier-, SHA- und Pfadregeln;
- Duplicate-Key-Rejection;
- Float-/NaN-/Infinity-Rejection, wo kanonische Decimal-Strings verlangt werden;
- kanonische Sortierung;
- Hash-Ausschluss nur des jeweils vorgesehenen Identity-Felds;
- create-new/no-overwrite;
- Schema-, Modul- und Testkonstanten müssen übereinstimmen;
- Hashänderung bei jeder materiellen Payloadänderung;
- Hashstabilität bei identischem semantischem Input.

Parse alle JSON-Dateien mit Duplicate-Key-Guard. Berechne gebundene SHA-256 unabhängig nach. Verwende nicht nur den projektionseigenen Validator als einzige Bestätigung seiner eigenen Hashfunktion.

## 15. Verbindlicher Testplan

Führe zunächst fokussierte Tests je Arbeitsstrang aus und danach die vollständige grüne Lane.

Mindestens:

1. Factory-/Lock-/Restore-/Process-Scope-Tests.
2. Gate Manifest, Execution Bundle, Strategy Card V3, Governance, Testlanes und Target Rulepacks.
3. Q08-v3-Aggregation und Evidence Series.
4. W6:
   - Runtime-Execution-Contract static;
   - Entry-Execution-Policy static;
   - Magic Resolver Strict Default;
   - Risk-Sizer-Smoke-Evidence;
   - Job Object und farmctl containment;
   - MT5 History Isolation;
   - Lifecycle-v2 sowie Cascade-/Basket-Regressionen.
5. W7:
   - Q08-v3 Migration Inventory;
   - Q08-v3 Migration Plan;
   - Collision-/Ambiguity-/No-Apply-Tests.
6. W8:
   - Target Outcome Dossier einschließlich aller negativen Evidence- und Authority-Fälle.
7. Dashboards:
   - gemeinsamer Statushelper;
   - Cockpit-Programmblock;
   - Strategy-Programmblock;
   - Quota-/bestehende Cockpit-Regressionen.
8. `py_compile` für alle geänderten Python-Dateien.
9. PowerShell-AST und vorhandene PowerShell-Vertragstests.
10. `git diff --check` und strikte JSON-Prüfung.

Danach:

```powershell
python tools/strategy_farm/test_lanes.py green
```

Erwartete finale Zahlen: **aus finalem Evidence-Receipt lesen und unabhängig nachrechnen**.

Führe anschließend die unveränderte External-Residual-Lane aus:

```powershell
python tools/strategy_farm/test_lanes.py residual
```

Die exakten fünf Node-IDs sind aus `tools/strategy_farm/config/test_lanes.v1.json` zu lesen. Schreibe sie nicht aus einem alten Bericht ab. Verifiziere:

- exakt diese fünf Residualtests werden gesammelt;
- sie scheitern aus den weiterhin dokumentierten externen Hash-/Kalender-/Binding-Gründen;
- kein zusätzlicher Test scheitert;
- keine der fünf Assertions wurde gelockert;
- keine wurde `skip` oder `xfail`;
- Green und Residual verwenden dasselbe hashgebundene Manifest;
- die Dashboard-Anzeige entspricht dem finalen Receipt.

Wenn die Residual-Lane wegen inzwischen behobener externer Evidenz weniger als fünf rote Tests liefert, ist das nicht automatisch ein Fehler: prüfe zuerst, ob ein versionierter, OWNER-autorisierter Amendment-/Ratifikationspfad vorliegt. Ohne diesen Pfad darf ein unerwartetes Grün nicht als legitime Reparatur akzeptiert werden.

Pytest- oder Subprozess-`__pycache__` ist als Audit-Nebenwirkung transparent auszuweisen. Lösche nichts aus Canonical- oder Runtime-Pfaden, nur um die Baseline optisch sauber zu machen.

## 16. Canonical-Dirty-Schutz

Die bereits vorhandenen offenen Änderungen unter `C:\QM\repo` gehören nicht dir.

Du musst:

- ihren Anfangsstatus und ihre Bytehashes erfassen;
- sie mit der versionierten Open-Worktree-Triage vergleichen;
- prüfen, ob der neue Stack sie fälschlich als integriert, erledigt oder releasable bezeichnet;
- ihren Endstatus und ihre Bytehashes erneut erfassen.

Du darfst nicht:

- sie formatieren oder normalisieren;
- Quarantäne-Renames zurückdrehen;
- Public-Data-Dateien regenerieren;
- untracked Dateien übernehmen;
- sie stagen oder committen;
- einen Clean-Worktree vortäuschen.

Jede Abweichung Anfang versus Ende ist ein Sicherheitsfinding, sofern sie nicht ausschließlich aus einer vorher explizit autorisierten, audit-eigenen Datei in deinem separaten Audit-Worktree stammt.

## 17. Begrenzte Erlaubnis für Claude-eigene Dokumentkorrekturen

Phase A des Audits ist vollständig read-only. Erst nachdem du ein Finding mit konkreter Evidenz formuliert hast, darfst du in Phase B sachlich veraltete Claude-eigene Dokumente oder Briefs korrigieren.

Zulässig sind ausschließlich:

- neue Auditbericht- und Patch-Receipt-Dateien unter `docs/ops/evidence/`;
- `CLAUDE.md`, sofern eine nachweislich veraltete Tatsachenbehauptung korrigiert wird und keine Sicherheitsregel gelockert wird;
- Dateien unter `docs/ops/`, die sich ausdrücklich selbst als von Claude verantwortet oder verfasst ausweisen;
- bestehende Claude-Auditberichte oder Claude-Briefs, wenn die Korrektur als nachträgliche, datierte Errata-/Supersession-Notiz erfolgt und der historische Originalclaim erkennbar bleibt.

Nicht allein wegen des Dateinamens zulässig:

- Code, Tests, Schemas, Configs oder Generatoren;
- `CODEX_BRIEF_*`;
- Masterplan, finales Implementierungs-Receipt oder MNT-Statusmatrix;
- OWNER-Entscheidungen;
- `D:\QM\reports\state\owner_decisions.json`;
- D:-Dashboards;
- Runtime-, DB-, Task-, Terminal-, Preset-, Deploy- oder Public-Data-Dateien.

Wenn eine veraltete Behauptung außerhalb der zulässigen Claude-Dokumente liegt, melde sie als Finding und ändere sie nicht.

Jede zulässige Dokumentänderung muss:

1. auf ein Finding mit ID verweisen;
2. die vorherige Behauptung nennen;
3. die neue, durch Source/Test/Receipt belegte Aussage nennen;
4. keine Implementierungslücke sprachlich in einen Erfolg umdeuten;
5. W6/W7/W8 weiterhin ehrlich als `PARTIAL`/`DRY_RUN`/`SHADOW` klassifizieren;
6. vor und nach dem Patch gehasht werden;
7. in einem separaten doc-only Commit landen, falls überhaupt Änderungen nötig sind.

Ändere niemals Code, um deinen Auditbericht grün zu bekommen. Code-Findings bleiben Findings für die Implementierer.

## 18. Patch-Receipt

Wenn du irgendeine Datei änderst, erstelle ein maschinenlesbares und ein menschenlesbares Patch-Receipt. Enthalten sein müssen:

- Audit-HEAD vor dem Patch;
- eigener doc-only Commit nach dem Patch;
- Finding-ID pro Änderung;
- Pfad;
- SHA-256 vorher und nachher;
- Diffstatistik;
- genaue fachliche Begründung;
- ausgeführte fokussierte Tests;
- vollständige Green-/Residual-Ergebnisse, sofern nach dem Patch erneut relevant;
- Bestätigung, dass keine Code-, Runtime-, D:-, Canonical-Dirty- oder Sicherheitsdatei geändert wurde;
- Vorher-/Nachher-Hashes der Sicherheitsbaseline.

Wenn keine Korrektur nötig ist, erstelle trotzdem einen kurzen Patch-Receipt-Abschnitt im Auditbericht: `patches_applied: 0` und begründe, dass keine zulässige Claude-Datei evidenzbasiert veraltet war.

Finale Commit-IDs, Hashes und Zahlen: **aus finalem Evidence-Receipt lesen und unabhängig nachrechnen**.

## 19. Findings und Severity

Verwende diese Klassen:

- `CRITICAL`: Sicherheitsgrenze verletzt; T_Live/AutoTrading/Factory/DB/Tasks/Deploy/Purchase mutiert; Datenverlust; autonome Geldaktion.
- `HIGH`: fail-open Entry-/Governor-/Migration-/Outcome-Pfad; falsches Auto-GO; falsche Rulepack-/Bundle-Identität; Dashboard oder Dokument behauptet fälschlich Runtime-/Money-Autorität.
- `MEDIUM`: materieller Source-/Schema-/Hash-/Lifecycle-/Testdefekt; Cross-Lane-Evidence-Laundering; irreführende W6/W7/W8-Klassifikation; gerendertes Dashboard wesentlich inkonsistent zum Source.
- `LOW`: Defense-in-Depth, unkritische Validatorlücke, stale Dokumentationspräzision, fehlende negative Regression ohne gegenwärtigen Fail-open-Nachweis.
- `INFO`: bestätigte offene Restarbeit, Einschränkung oder transparent dokumentierte Audit-Nebenwirkung ohne aktuellen Defekt.

Jedes Finding braucht:

- stabile ID;
- Severity;
- betroffene Welle/MNT/Datei und Zeile;
- reproduzierbaren Prüfweg;
- Erwartung;
- tatsächliches Ergebnis;
- Auswirkung;
- empfohlene Korrektur;
- Kennzeichnung, ob es durch diesen Stack verursacht, nur aufgedeckt oder bereits vorbestehend ist;
- Kennzeichnung, ob du lediglich dokumentiert oder eine zulässige Claude-Doku korrigiert hast.

Keine pauschalen Aussagen wie „sieht gut aus“. Kein Finding darf durch eine spätere Summary verschwinden.

## 20. Sicherheitsbaseline nach dem Audit

Wiederhole nach allen Tests und nach einem eventuellen doc-only Patch exakt die Baseline aus Abschnitt 5.

Vergleiche mindestens:

- Factory-OFF-Flag bytegenau;
- Mutation-Lock;
- alle abgeleiteten OFF-/Hazard-Taskzustände;
- Factory-/Terminal-/Metatester-Prozessscan;
- T_Live PID, Pfad und Startzeit;
- Canonical-Dirty-Dateien bytegenau;
- produktive DB, sofern ihr Hash Teil der Baseline war;
- beide D:-HTML-Dateien samt Task-History; autonome, zeitlich passende ALWAYS_ON-Rewrites
  separat vom Auditdiff ausweisen;
- Audit-Worktree und eigener doc-only Diff.

Das Audit gilt nicht als sicher abgeschlossen, wenn eine unerklärte Abweichung verbleibt.

## 21. Verbindliches Berichtsformat

Schreibe den Abschlussbericht auf Deutsch mit diesen Abschnitten:

1. **Executive Verdict**
   - `PASS`, `PASS WITH FINDINGS` oder `FAIL`;
   - höchste Severity;
   - Merge-/Freigabeempfehlung nur für Source, niemals als Runtime-Autorisierung.
2. **Geprüfter Scope**
   - Baseline-Commit;
   - finales HEAD;
   - Commitliste;
   - Dateizahl und Diffstatistik;
   - Receipt-Identität.
3. **Sicherheitszustand vor und nach dem Audit**
   - tabellarischer Byte-/State-Vergleich.
4. **Claim-Matrix W0–W8**
   - behaupteter Status;
   - verifizierter Status;
   - Source-Evidence;
   - Runtime-Evidence;
   - Abweichung.
5. **W6 Framework-Prüfung**
6. **W7 Dry-Run-/Migration-Prüfung**
7. **W8 Shadow-/Outcome-Dossier-Prüfung**
8. **Q08-v3 versus Legacy-Q08**
9. **Dashboard-Source-versus-rendered-Prüfung**
   - Strategy Archive;
   - Cockpit;
   - gemeinsame Statusquelle;
   - D:-Hashes vorher/nachher.
10. **Schema-, Hash-, MQL- und Architekturprüfung**
11. **Testergebnisse**
    - fokussiert;
    - Green Lane;
    - exakt fünf External Residuals;
    - Statik/AST/JSON.
12. **Canonical-Dirty-Unverändertheit**
13. **Findings nach Severity**
14. **Claude-Dokumentkorrekturen und Patch-Receipt**
15. **Bekannte Restarbeit und OWNER-Entscheidungen**
16. **Abschlussurteil und nächste sichere Schritte**

Werte und Hashes im Bericht müssen gemessen sein. Wo du den erwarteten Wert aus der Implementierung brauchst: **aus finalem Evidence-Receipt lesen und unabhängig nachrechnen**.

## 22. Explizite Nicht-Claims

Bestätige am Ende ausdrücklich, sofern die Evidenz nichts anderes autorisiert:

- Factory blieb absichtlich OFF;
- T_Live und AutoTrading wurden nicht verändert;
- W6 ist keine abgeschlossene Flottenmigration;
- W7 hat keine produktive Re-Adjudikation angewandt;
- W8 hat weder ein reales DXZ-Challenger-Buch zugelassen noch eine FTMO-Challenge gekauft, deployed oder gehandelt;
- `READY_FOR_OWNER_DECISION` ist kein `GO`;
- Dashboard-Status ist eine read-only Projektion und keine Autorität;
- die fünf External Residuals bleiben sichtbare externe Restarbeit, solange kein versionierter OWNER-Pfad sie legitim auflöst;
- Canonical-Dirty-Dateien blieben unverändert;
- dein Audit hat keine D:-HTML-Datei geschrieben; jede Byteänderung ist entweder anhand
  der ALWAYS_ON-Task-History kausal zugeordnet oder als ungeklärtes Finding gemeldet.

Beginne jetzt mit der read-only Sicherheitsbaseline. Nimm keine Reparatur vor, bevor die unabhängige Prüfung und ein konkretes Finding abgeschlossen sind.
