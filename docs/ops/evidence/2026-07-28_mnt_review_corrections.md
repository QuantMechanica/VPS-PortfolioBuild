# MNT review corrections and chain 003→002→004 kickoff — 2026-07-28

Task: `80b9d54d-7414-439a-abca-5d6b6675cde0`  
Agent: Codex  
Branch: `agents/codex-mnt-review-20260728`  
Base: `fa215b3e9cead543e9bf505d36cff733eeb062e1`  
Implementation commit: `aa73570d7`  
Disposition: REVIEW — no self-approval and no pipeline promotion

## Ergebnis

Die sechs korrigierten deutschen Ersatzseiten liegen unter
`docs/ops/mnt_page_updates_2026-07-28/`. Der Supervisor-Ausfall ist auf den
`InteractiveToken`-Queue/No-op-Pfad bei getrennter `qm-admin`-Session
zurückgeführt. Das unexecuted Before/After/Rollback-Paket liegt unter
`tools/ops/task_contract_fix_2026-07-28/`. Die Monitoring-Quellen besitzen jetzt
einen expliziten Zustand `RUNNING|PARKED|MAINTENANCE`, einen Review-Ablauf und
eine einmalige Eskalationskante nach drei identischen Fehlerzyklen.

Diese Arbeit hat **keine** Scheduled Task registriert, gestartet, gestoppt,
aktiviert oder deaktiviert. Sie hat keinen MT5-Prozess gestartet oder beendet,
T5 nicht berührt, weder T_Live noch AutoTrading verändert und kein Work-Item
oder Pipeline-Verdict geschrieben. Die Task-XMLs wurden nur über
`Export-ScheduledTask` gelesen. Das Apply-Skript wurde nicht ausgeführt; nur
seine PowerShell-Syntax und seine statischen Invarianten wurden geprüft.

## WP-A — gelieferte Seiten

| Seite | Korrektur |
|---|---|
| `MNT-001.md` | Beide KS-Baseline-Verzeichnisse, reale Loader-Priorität und KS-Metrik im Live-Pulse. |
| `MNT-002.md` | Step 0 vor Contract-Fix: API-Kick ist kein Action-/Heartbeat-Beweis. |
| `MNT-017.md` | 18 Paare/13 EAs; EA-seitige Stress-Inputs und erzwungener Rebuild; rückwirkender Live-Scope. |
| `MNT-018.md` | Fail-closed Detection existiert; Legacy-Stempel, 13128/1567 und Rebuild-vor-Rerun sind die Lücke. |
| `MNT-019.md` | Ungültiger T5-Kontrollarm ersetzt durch positive Controls 11912/20102 und Framework-Cache-Probe. |
| `MNT-040.md` | Fehlerquelle ist `farmctl.py::pipeline_view`, nicht `pipeline_state.json`; String-Verdict abgesichert. |

Pfad:
`docs/ops/mnt_page_updates_2026-07-28/MNT-{001,002,017,018,019,040}.md`.

## WP-B.1 — Supervisor ohne Heartbeat: Step-0-Diagnose

### Reproduzierte Laufzeitfakten

Read-only-Snapshot am 28.07.2026, ungefähr 23:15 Europe/Berlin:

| Fakt | Beobachtung | Nachweis |
|---|---|---|
| Desktop-Session | `qm-admin`, Session 3, `Disc` | `qwinsta`; Ausgabezeile `qm-admin 3 Disc`. |
| Supervisor-Task | `Ready`, Principal `qm-admin`, LogonType `Interactive`, zwei Trigger, `AllowDemandStart=True`, `LastTaskResult=0x800710E0` | `Get-ScheduledTask` + `Get-ScheduledTaskInfo -TaskPath '\' -TaskName 'QM_Live_MT5_SessionSupervisor'`. |
| Letzter Task-Run | `2026-07-28T23:15:15+02:00`; nächster TimeTrigger `23:30:30+02:00` | gleiche TaskInfo-Abfrage. |
| Heartbeat | letzte Dateiänderung `2026-07-26T15:34:18.9004432Z`, 1007 Byte | `Get-Item D:\QM\reports\state\live_session_supervisor.json`. |
| Zweiter Watchdog | 730 Logzeilen, davon 687 `kicked`, 0 Zeilen passend auf `fail|error`; zuletzt `2026-07-28T21:15:06Z kicked ... state_age=193246` | `D:\QM\reports\state\live_supervisor_watchdog.log`, gezählt mit `Where-Object`. |
| Scheduler-Semantik | `0x800710E0` = dezimal 2147946720, „The operator or administrator has refused the request“ | `net helpmsg 4320` und TaskInfo-Wert. |

Der Task-Scheduler-Operational-Log zeigte wiederholte Queue-Ereignisse
(`Event ID 110`, gefolgt von `325`) für denselben Task, aber keinen passenden
Action-Start (`Event ID 200`) im untersuchten Fenster. Reproduzierbare Abfrage:

```powershell
Get-WinEvent -FilterHashtable @{
  LogName='Microsoft-Windows-TaskScheduler/Operational'
  StartTime=(Get-Date).AddHours(-4)
} | Where-Object {
  $_.Message -like '*QM_Live_MT5_SessionSupervisor*'
} | Select-Object TimeCreated, Id, Message
```

### Warum „kicked“ kein Startnachweis ist

`tools/strategy_farm/live_supervisor_watchdog.ps1:95-96` ruft
`Start-ScheduledTask` auf und schreibt unmittelbar nach Rückkehr `kicked`. Das
Skript prüft danach weder einen Engine-PID noch dessen Session, einen Event-200
noch einen erneuerten Heartbeat. Die 687 Kicks belegen deshalb nur akzeptierte
API-Aufrufe. Sie widerlegen den Ausfall nicht.

Der Supervisor schreibt bei jedem Schleifendurchlauf atomar
`live_session_supervisor.json`
(`tools/strategy_farm/Live_MT5_SessionSupervisor.ps1:119-140,335-337`). Wenn
sein Entry-Code tatsächlich in Session 3 liefe, müsste die Datei ungefähr alle
zehn Sekunden erneuert werden. Der unveränderte Heartbeat plus fehlender
Supervisor-Prozess und `0x800710E0` belegen, dass kein dauerhafter
Supervisor-Engine-Prozess gestartet wurde.

### Ausgeschlossene Alternativhypothesen

- **PS5.1-Stderr-Trap:** Supervisor und zweiter Watchdog setzen
  `$ErrorActionPreference='Continue'`
  (`Live_MT5_SessionSupervisor.ps1:24-25`,
  `live_supervisor_watchdog.ps1:28-35`). Die Task-Actions enthalten kein
  `2>&1`. Die bekannte Kombination `EAP=Stop + 2>&1` liegt hier nicht vor.
- **G:-Abhängigkeit beim Einstieg:** Die Supervisor-Pfade sind vollständig auf
  `C:\QM`, `D:\QM`, den FTMO-Installationspfad und `%SystemRoot%` gebunden
  (`Live_MT5_SessionSupervisor.ps1:27-34`). Im Entry-Pfad gibt es keinen
  `G:`-Zugriff.
- **Nur Contract-Block:** Der SYSTEM-Watchdog ist wegen der Drift blockiert,
  aber der zweite Watchdog ist es nicht und erzeugte 687 API-Kicks. Dass auch
  diese keinen Heartbeat erzeugen, isoliert den Queue/InteractiveToken-Pfad.

### Root Cause

`QM_Live_MT5_SessionSupervisor` ist ein `InteractiveToken`-Task für
`qm-admin`. In der getrennten Session 3 werden die wiederholten Time-/Demand-
Starts gequeued bzw. mit `0x800710E0` abgelehnt. `Start-ScheduledTask` kann
ohne Ausnahme zurückkehren, obwohl keine Action in der Zielsession beginnt.
Die zusätzliche Contract-Drift verhindert parallel den gehärteten
sessiongebundenen Starter. Die Korrektur braucht daher beides:

1. exakten Task-Contract mit nur einem AtLogon-Trigger; und
2. Erfolg ausschließlich nach frischem, session- und schedulergebundenem
   Heartbeat.

## WP-B.2 — Disposition der sieben `0x800710E0`-Tasks

Alle sieben Werte wurden mit derselben read-only-Abfrage erfasst:

```powershell
$names = @(
  'QM_StrategyFarm_AgyGovernor',
  'QM_StrategyFarm_CodexFleetPacer',
  'QM_StrategyFarm_GeminiOrchestration_15min',
  'QM_StrategyFarm_MailboxSourceIntake_Daily',
  'QM_StrategyFarm_WorkerDedupe',
  'QM_T_Live_AtLogon',
  'QM_Live_MT5_SessionSupervisor'
)
$names | ForEach-Object {
  $task = Get-ScheduledTask -TaskPath '\' -TaskName $_
  $info = Get-ScheduledTaskInfo -TaskPath '\' -TaskName $_
  [pscustomobject]@{
    Name=$_; Principal=$task.Principal.UserId
    LogonType=$task.Principal.LogonType
    LastResult=('0x{0:X8}' -f [uint32]$info.LastTaskResult)
    TriggerCount=@($task.Triggers).Count
    AllowDemand=$task.Settings.AllowDemandStart
  }
}
```

| Task | Zielprincipal / LogonType | Triggervertrag | Abhängigkeit und Begründung | Fallback |
|---|---|---|---|---|
| `QM_StrategyFarm_AgyGovernor` | Task: `SYSTEM` / `ServiceAccount`; Python-Kindprozess via `run_in_console_session.ps1` als `qm-admin` | vorhandene 10-Minuten-Repetition | `agy_governor.py` benötigt den benutzerspezifischen Credential-Manager/DPAPI-Kontext `gemini:antigravity`; direktes SYSTEM/S4U kann ihn nicht entschlüsseln (`tools/strategy_farm/agy_governor.py`, Kopfkommentar und Credential-Zugriff). Kein G:-Bedarf. | Ohne vorhandene `qm-admin`-Session schlägt der Wrapper sichtbar fehl; kein verdeckter SYSTEM-Fallback. |
| `QM_StrategyFarm_CodexFleetPacer` | `SYSTEM` / `ServiceAccount`, direkt `pythonw.exe` | vorhandene 15-Minuten-Repetition | Headless, feste `C:\QM`/`D:\QM`-Pfade; kein Desktop und kein G: erforderlich (`tools/strategy_farm/codex_fleet_pacer.py`). | Taskfehler bleibt im Scheduler/State sichtbar; kein InteractiveToken-Retry. |
| `QM_StrategyFarm_GeminiOrchestration_15min` | `SYSTEM` / `ServiceAccount`, direkt `pythonw.exe` | vorhandene 15-Minuten-Repetition | `run_agent_orchestration_task.py` setzt SYSTEM-taugliche HOME/CODEX-Pfade und weist im Prompt auf fehlendes G: hin; `cmd.exe >> ... 2>&1` wird entfernt (`tools/strategy_farm/run_agent_orchestration_task.py`). | Eigene Orchestrierungslogs/TaskResult; kein Desktop-Fallback. |
| `QM_StrategyFarm_MailboxSourceIntake_Daily` | `SYSTEM` / `ServiceAccount`, direkt `pythonw.exe` | täglich 06:07 | Feste Administrator-Python-/Codex- und `C:\QM`/`D:\QM`-Pfade; kein Desktop/G:-Startbedarf (`tools/strategy_farm/mailbox_source_intake.py`). | Nächster Tageslauf bzw. OWNER-Demand-Run unter SYSTEM. |
| `QM_StrategyFarm_WorkerDedupe` | Task: `SYSTEM` / `ServiceAccount`; Launcher via `run_in_console_session.ps1` als `qm-admin` | on-demand, kein periodischer Trigger | Terminal-Worker bzw. mögliche GUI-Kinder dürfen nicht in Session 0 entstehen; der vorhandene WTS/CreateProcessAsUser-Wrapper bindet sie an die bestehende User-Session (`tools/strategy_farm/run_in_console_session.ps1:1-31`). | Ohne User-Session sichtbarer Fehler; kein direkter SYSTEM-Start von Terminal-Kindern. |
| `QM_T_Live_AtLogon` | unverändert `qm-admin` / `InteractiveToken` | genau ein AtLogon, Delay `PT15S`, Demand-Start **aus** | MT5-GUI muss in der interaktiven Session bleiben; `T_Live_ON.ps1` ist der gehärtete Launcher. | Ausschließlich nächster Logon; kein SYSTEM- oder Demand-Start. |
| `QM_Live_MT5_SessionSupervisor` | unverändert `qm-admin` / `InteractiveToken` | genau ein AtLogon, Delay `PT45S`; Demand-Start nur für expliziten RunEx-Session-Starter | Residenter Prozess und seine Launcher müssen in Session 3 laufen (`Live_MT5_SessionSupervisor.ps1:176-216`). | `Start_Live_SessionSupervisor.ps1` mit expliziter Session-ID und Heartbeat-/Ownership-Verifikation; kein einfacher Kick. |

Das Paket enthält zusätzlich `QM_FTMO_AtLogon` als achten, unterstützenden
Park-Contract: InteractiveToken und ein AtLogon-Trigger bleiben erhalten,
Demand-Start wird ausgeschaltet. `FTMO_ON.ps1` beendet sich wegen des
eingebauten Zustands `PARKED` vor jeder Identity-, Profil-, Experts- oder
Prozess-Startlogik. Damit kann auch ein kontrollierter Windows-Neustart FTMO
nicht still wieder starten
(`tools/strategy_farm/FTMO_ON.ps1:30-97` im Branch).

## WP-B.3 — unexecuted Change Package

Paket:
`tools/ops/task_contract_fix_2026-07-28/`

- `before/*.xml`: semantische Read-only-Exporte des beobachteten Zustands.
- `after/*.xml`: vorgeschlagene Verträge aus der Matrix.
- `rollback/*.xml`: vollständige Kopie jedes Before-Vertrags.
- `Apply-TaskContractFix.ps1`: Default ist read-only PLAN. `-Apply` akzeptiert
  ausschließlich `BEFORE→AFTER`; `-Rollback` ausschließlich `AFTER→BEFORE`.
  Ein dritter Driftzustand wird abgelehnt. Nach einer expliziten Registrierung
  vergleicht das Skript den vollständigen Task-Fingerprint.

Statische Verifikation:

1. alle 24 XMLs (acht Tasks × Before/After/Rollback) lassen sich als XML parsen;
2. jedes `before` entspricht dem aktuellen `Export-ScheduledTask`;
3. jedes `rollback` entspricht byteunabhängig dem `before`;
4. die fünf Headless-Tasks haben in `after` SID `S-1-5-18` und
   `ServiceAccount`;
5. T_Live bleibt Interactive und hat explizit
   `AllowStartOnDemand=false`;
6. T_Live und FTMO AtLogon bleiben Interactive, besitzen genau einen
   Logon-Trigger und verbieten Demand-Start;
7. der Supervisor bleibt Interactive, hat einen Trigger und
   `AllowStartOnDemand=true`;
8. das Apply-Skript parst unter Windows PowerShell und enthält keine Start-,
   Stop-, Enable-, Disable-, Prozess- oder Terminal-Aktion.

Das Apply-Skript selbst wurde **nicht** ausgeführt. OWNER/Claude muss es in der
interaktiven Admin-Session zuerst ohne Schalter (PLAN), dann mit
`-Apply -WhatIf` und erst nach Prüfung explizit mit `-Apply` aufrufen.

## WP-B.4 — Park-Awareness und Alarm-Deduplizierung

### Vertrag

- DXZ: `RUNNING`
- FTMO: `PARKED`
- Review-Ablauf: `2026-08-25T00:00:00Z` (30-Tage-Ziel ab OWNER-Parkentscheidung)
- Maintenance-Flag überschreibt temporär beide Zustände mit `MAINTENANCE`.
- `PARKED + OFF = OK`.
- `PARKED + RUNNING = unexpected_running/ALARM`; der Code stoppt den Prozess
  nicht selbst.
- `RUNNING + OFF = missing/ALARM`; nur RUNNING-Ziele dürfen relaunch werden.
- Ablauf oder ungültiges Ablaufdatum = `contract_expired/ALARM`; ein
  ungültiger Sollzustand schlägt ebenfalls fail-closed als
  `contract_invalid/ALARM` fehl.
- Nach drei identischen Alarmzyklen wird genau einmal
  `new_escalation=true` gesetzt; bei unverändertem Fehler wird nicht erneut
  eskaliert.

### Geänderte Quellen

| Quelle | Wirkung | Code-Evidenz |
|---|---|---|
| `T_Live_Watchdog.ps1` | FTMO fest `PARKED`, Profil-Soll `null`, Relauchliste enthält nur RUNNING-Ziele, Zustand/Ablauf in Evidence. | `:76-81,563-579,647-658,691-718,803-874` |
| `Live_MT5_SessionSupervisor.ps1` | Miss-Zähler und Launcher nur für RUNNING; PARKED erzeugt `parked_no_relaunch`; unerwarteter Prozess wird nur alarmiert. | `:36-42,268-288,296-326` |
| `FTMO_ON.ps1` | AtLogon-/manueller Launcher beendet sich im gebackenen PARKED-Zustand vor jeder Launch- oder AutoTrading-Konfiguration; Ablauf bleibt fail-closed. | Zustand und Guard vor `$identity` im Branch. |
| `ftmo_trial_pulse.py` | Reine Tri-State-Funktion; PARKED/OFF short-circuited ohne Journal-/Equity-Stale-Alarm. | `:75-117,295-339` |
| `Live_Alarm_State.ps1` | Schema v2, neue Zustände, identische Fehlerzyklen und einmalige Eskalationskante. | `:79-100,128-176,184-279,348-393` |
| `silent_failure_monitor.py` | Erwartete Zustände statt „beide müssen laufen“; Parked-Running und Ablauf sind FAIL. | Funktion `check_live_uptime`, `:824-960` im Branch. |

Keiner dieser Pfade enthält einen automatischen Stop für ein unerwartet
laufendes FTMO. Die vorhandene Reboot-Sicherheitskante bleibt fail-closed: ein
Reboot wird weiterhin abgebrochen, sobald irgendein Live-Prozess erscheint
(`T_Live_Watchdog.ps1`, finaler CIM- plus unabhängiger Prozess-Probe-Block).

## MNT-001 und MNT-040 — implementierte Monitoring-/Aggregator-Korrekturen

### KS-Baselines

Der MQL-Loader öffnet terminal-lokal und fällt dann auf `FILE_COMMON` zurück
(`framework/include/QM/QM_KillSwitchKS.mqh:141-146`). Der Read-only-Vergleich:

```powershell
$local  = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\baselines'
$common = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\baselines'
$localFiles = Get-ChildItem -LiteralPath $local -Filter '*.json'
$commonFiles = Get-ChildItem -LiteralPath $common -Filter '*.json'
$different = foreach ($f in $localFiles) {
  $other = Join-Path $common $f.Name
  if ((Test-Path -LiteralPath $other) -and
      (Get-FileHash $f.FullName).Hash -ne (Get-FileHash $other).Hash) {
    $f.Name
  }
}
[pscustomobject]@{
  local=$localFiles.Count; common=$commonFiles.Count
  same_name_different_hash=@($different).Count
}
```

ergab `local=54`, `common=54`, `same_name_different_hash=54`. Es wurden keine
Baseline-Dateien verändert. `health.py` und `live_book_pulse.py` prüfen jetzt
beide Pfade in Loader-Reihenfolge; divergierende Spiegel sind `FAIL`. Der
Live-Pulse veröffentlicht `kill_switch_baselines` und kann bei 0/24 nicht mehr
grün sein (`live_book_pulse.py:437-526,1318-1332,1552-1557` im Branch).

### Pipeline-View

Der Review-Snapshot verglich 793 Legacy-`backtest_q03`-Tasks mit 12.717
Q03-Work-Items. Reproduzierbare Query:

```sql
SELECT
  (SELECT COUNT(*) FROM tasks WHERE kind='backtest_q03') AS legacy_tasks,
  (SELECT COUNT(*) FROM work_items WHERE phase='Q03') AS canonical_items;
```

`pipeline_view` liest nun Work-Items für Gate-Status und Tasks nur für
Build-/Review-Metadaten (`tools/strategy_farm/farmctl.py:2151` ff.).
Legacy-Phasen werden Q-kanonisiert und nur als Fallback verwendet. Der Test
`test_pipeline_view_work_items.py` bindet den QM5_10035-Fehlerfall und einen
String-Review-Verdict.

## Acknowledgment der Minor Folds

- **MNT-003:** Akzeptanzabfragen müssen
  `Principal.LogonType=Interactive` filtern. Ein roher
  `LastTaskResult=0x800710E0`-Filter erfasst auch kurzzeitig laufende
  SYSTEM-Tasks. Nachweisquelle: dieselbe TaskInfo-/Principal-Abfrage aus
  WP-B.2.
- **MNT-004:** Der alte Watchdog alarmierte nicht nur, sondern erhöhte
  `consecutive_relaunch_failed` und delegierte FTMO-Recovery. Zusätzlich sind
  `D:\QM\reports\state\ftmo_trial_pulse.json` und
  `QM_FTMO_AtLogon` (`LastTaskResult=0x2`) Teil der Beobachter-/Launcher-Kette.
  Der Fix liegt deshalb in den bestehenden baked-in Erwartungen, nicht in einer
  neuen Flagdatei (`T_Live_Watchdog.ps1`, `ftmo_trial_pulse.py`).
- **MNT-006/008:** Akzeptanzkriterien werden als Invarianten/Queries und nicht
  als absolute Counts formuliert. `valid_zero` gehört in RETIRE/Frequency-Floor,
  nicht Retry; Legacy-Zeilen `phase='P2'` müssen explizit normalisiert werden.
  Review-Basis und Zähler stehen im Brief
  `docs/ops/CODEX_BRIEF_mnt_review_corrections_2026-07-28.md`.
- **MNT-007:** `tools/strategy_farm/requeue_stranded_infra.py` existiert bereits;
  offen sind Health-Invariante und Automation. Q08
  `phase_runner_invalid_report` ist `INVALID`, nicht retrybares Infra.
  Evidenz/Counts: derselbe Review-Brief, Abschnitt „Minor folds“.
- **MNT-009/010:** Die 832 sind ein geschlossenes Legacy-Fenster vom
  14./15.07.; Backfill muss den gesamten Corpus und vorhandene
  `report_root/log_path` berücksichtigen. „Alle Kinder terminal“ ist erst nach
  Migration der NULL-Verdicts definiert; Reihenfolge 009→010. Evidenz: Review-
  Brief, Minor-Folds-Abschnitt.
- **MNT-012:** Frontmatter `r3=PASS` und Body `R3=UNKNOWN` müssen gemeinsam mit
  der G0-Logik korrigiert werden. Das Binary von 20062 liegt unter
  `C:\QM\repo\framework\EAs\...`, nicht im Factory-Tree. Evidenz: Review-Brief,
  Minor-Folds-Abschnitt.
- **MNT-013:** `not_build_ready=0` widerlegt die Heterogenitätsbegründung; der
  Preflight bleibt als Guardrail, aber nicht mit dieser Begründung. Evidenz:
  Review-Brief, Minor-Folds-Abschnitt.
- **MNT-015/016:** Messfenster explizit machen (Kalendertag gegen rolling 24h);
  Taxonomie-Invariante muss `verdict_reason` und die bidirektionale
  Kontamination sowie den `INFRA_FAIL`-Statussplit umfassen. Evidenz: Review-
  Brief, Minor-Folds-Abschnitt.
- **MNT-021:** Vor Nutzung des Registers Selbst-Deduplizierung für
  11132/SP500 und 10715/USDJPY. Evidenz:
  `framework/registry/magic_numbers.csv`, Suche nach beiden EA/Symbol-Paaren.
- **MNT-036:** Probation-Beginn ist 13.07.2026; die ersten EA-Logs liegen
  06:28–06:36Z. Ein 19.07.-Anker wäre sechs Tage zu spät. Evidenz: Review-Brief,
  Minor-Folds-Abschnitt.
- **MNT-041:** „cap: T5“ verwechselt Quarantäne mit RAM-Throttle. Design-
  Kapazität muss den Check-Status `WARN` treiben, nicht nur einen grünen
  Detail-Suffix. Evidenz: Review-Brief, Minor-Folds-Abschnitt.

## Verifikation

Ausgeführt im sauberen Worktree
`C:\QM\worktrees\codex-mnt-review-20260728`:

```text
python -m pytest -q \
  test_ftmo_trial_pulse.py test_silent_failure_live_uptime.py \
  test_live_book_pulse.py test_health_vacuousness.py \
  test_pipeline_view_work_items.py test_live_uptime_watchdog_static.py

Ergebnis: 86 PASS, 2 FAIL.
```

Die zwei FAILs sind ein bereits im Basisstand vorhandener, nicht durch diese
Änderung erzeugter ASCII-Guard:
`verify_ftmo_round25_live_contract.ps1` enthält vorbestehende Nicht-ASCII-Bytes,
während `test_live_uptime_watchdog_static.py` die Datei als ASCII liest. Die
sechs direkt betroffenen Watchdog-Tests wurden separat selektiert und bestanden:
`6 passed, 6 deselected`.

Zusätzliche fokussierte Nachweise:

```text
Windows-PowerShell-Parser:
  T_Live_Watchdog.ps1
  Live_MT5_SessionSupervisor.ps1
  Live_Alarm_State.ps1
  FTMO_ON.ps1
  Test-LiveAlarmState.ps1
  Apply-TaskContractFix.ps1
Ergebnis: PASS

powershell.exe ... Test-LiveAlarmState.ps1
Ergebnis: PASS (204 assertions)

Task-Paket:
  24/24 XML parsebar
  8/8 BEFORE == aktueller read-only Export
  8/8 ROLLBACK == BEFORE
  AFTER-Principals/Trigger/Demand-Settings wie Matrix
  Apply-Skript parsebar und frei von verbotenen Laufzeitaktionen
Ergebnis: PASS; Apply-Skript ausgeführt: NEIN
```

Zusätzlich bestanden `python -m py_compile` für die geänderten Python-Quellen,
`git diff --check` und der grüne, direkt betroffene Pytest-Teillauf mit
`76 passed`; die sechs betroffenen statischen Watchdog-Tests bestanden mit
`6 passed, 6 deselected`.

## Noch OWNER-/Reviewer-gebunden

1. Task-Paket in PLAN/`-WhatIf` prüfen und erst dann interaktiv anwenden.
2. Supervisor über den sessiongebundenen Starter starten und Heartbeat plus
   Ownership verifizieren.
3. Die 54 KS-Baseline-Paare OWNER-gesteuert auf eine Quelle reconciliieren.
4. Branch-Code substantiv prüfen und erst nach Close-Review deployen.
5. MNT-043/044 für Rebuild und rückwirkende Q05–Q07-Neubeurteilung ausführen.

Keiner dieser Schritte wurde von diesem headless Codex-Lauf vorweggenommen.

## Round 2 corrections — 2026-07-29

Dieser Abschnitt korrigiert die Runde-1-Evidenz additiv; die damalige
Ausführungshistorie wird nicht umgeschrieben.

### Task-Matrix: BEFORE und vorgeschlagenes AFTER

Die Spalte „Zielprincipal / LogonType“ in WP-B.2 beschrieb das vorgeschlagene
AFTER, nicht den beobachteten Istzustand. Insbesondere waren AgyGovernor und
WorkerDedupe **nicht bereits** SYSTEM-Tasks mit Session-Wrapper. Die
`before/*.xml`-Exporte belegen für alle vier auth-/sessiongebundenen Lanes den
Administrator-SID `S-1-5-21-1736347224-3968129211-1303436014-500` mit
`InteractiveToken`:

| Task | BEFORE-Action | vorgeschlagenes AFTER |
|---|---|---|
| `QM_StrategyFarm_AgyGovernor` | direkt `pythonw.exe agy_governor.py` als InteractiveToken | SYSTEM-Scheduler → `run_in_console_session.ps1` → `qm-admin` |
| `QM_StrategyFarm_GeminiOrchestration_15min` | `cmd.exe /c python.exe ... >> ... 2>&1` als InteractiveToken | SYSTEM-Scheduler → Session-Wrapper → `qm-admin`-`pythonw.exe` |
| `QM_StrategyFarm_MailboxSourceIntake_Daily` | direkt `pythonw.exe mailbox_source_intake.py` als InteractiveToken | SYSTEM-Scheduler → Session-Wrapper → `qm-admin`-`pythonw.exe` |
| `QM_StrategyFarm_WorkerDedupe` | direkt `python.exe start_terminal_workers.py --dedupe` als InteractiveToken | SYSTEM-Scheduler → Session-Wrapper → `qm-admin` |

Die beiden in Runde 1 noch bare-SYSTEM vorgeschlagenen Lanes Gemini und
Mailbox nutzen im korrigierten AFTER jetzt ebenfalls
`run_in_console_session.ps1 -TargetUser qm-admin`. Das ist für Gemini zwingend,
weil agy den benutzerspezifischen Credential-Manager-Eintrag
`gemini:antigravity` und `LOCALAPPDATA\agy` verwendet
(`run_agent_orchestration_task.py`, `_AGY_BIN_CANDIDATES` und Kopfkommentar).
Mailbox bindet dadurch den dokumentierten Administrator-`CODEX_HOME` und den
gleichen Benutzer-Authkontext. Der LocalSystem-Task bleibt nur Scheduler; die
authentifizierte Python-Action läuft im vorhandenen Benutzer-Token.

Die Entfernung des `cmd.exe`-Redirect-Wrappers ist ausschließlich eine
**unexecuted Änderung in**
`after/QM_StrategyFarm_GeminiOrchestration_15min.xml`. Sie wurde in Runde 1
fälschlich `run_agent_orchestration_task.py` zugeschrieben; das Python-Modul
ändert keinen Scheduled-Task-Action-Vertrag.

### Reichweite der State-Machine-Verifikation

Die Runde-1-Behauptung einer byteweisen Erhaltung der gesamten Recovery- und
Reboot-State-Machine war nicht ausgeführt: `Test-LiveAlarmState.ps1` erhielt
`-BaselineWatchdogPath ''`, daher wurde PART 5c übersprungen. Gegen
`fa215b3e9` ist der Haupt-State-Machine-Block erwartungsgemäß verschieden,
weil RUNNING/PARKED/MAINTENANCE ihn absichtlich verändert.

Korrekt und nachprüfbar ist nur:

- Der Haupt-Recovery-State-Machine wurde für Park-Awareness absichtlich
  geändert und besitzt strukturelle Guard-Tests; für ihn wird keine
  Byte-Invarianz behauptet.
- Der Reboot-**Ausführungsblock** ab
  `if ($actions -contains 'controlled_reboot_requested')` bis vor die
  post-block Status/Exit-Abbildung ist gegenüber `fa215b3e9`
  inhaltsidentisch (Checkout-Zeilenenden normalisiert). PART 5c vergleicht
  jetzt ausschließlich diesen Block, wenn ein Vorgängerpfad übergeben wird.
- Der Test-Headline und die Warnung benennen diese eingeschränkte Reichweite;
  ein leerer Baseline-Pfad ist nur noch ein explizit übersprungener optionaler
  Reboot-Block-Vergleich, kein ausgeführter Verbatim-Nachweis.

### Weitere Round-2-Entscheidungen

- MNT-004 ist fail-closed festgelegt: `contract_expired` gewinnt gegen
  `MAINTENANCE` und `probe_unknown`. Ein gültiger Maintenance-Zustand
  unterdrückt weiterhin Laufzeit-Recovery.
- Das strengere KS-Verhalten ist beabsichtigt: Ein
  `KS_BASELINE_LOADED`-Event ohne `payload.hash` zählt als `hash_mismatch`, nie
  als `loaded_ok`. MNT-001 und ein eigener Regressionstest schreiben das fest.
- `Live_Alarm_State.ps1` ist nun Teil der ASCII- und PS5.1-Parser-CI. Die drei
  Nicht-ASCII-Bytes im Laufzeit-Verifier
  `verify_ftmo_round25_live_contract.ps1` wurden durch ASCII ersetzt.
- Die direkten `pythonw.exe`-Entry-Points besitzen einen top-level
  Exception-Hook in ihre lane-eigenen Logverzeichnisse, sodass ein Absturz vor
  dem normalen Run-Log nicht mehr still bleibt.
