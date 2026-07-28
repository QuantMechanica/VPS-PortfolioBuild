# MNT convergence review — round 2 — 2026-07-29

Task: `6066746a-65c5-44c4-85d2-02ece5ef17bb`  
Predecessor task: `80b9d54d-7414-439a-abca-5d6b6675cde0`  
Branch: `agents/codex-mnt-review-20260728`  
Round-1 implementation: `aa73570d7`  
Round-2 implementation: `31c51587a4f794b153d533fe3dbd08508e2b3a46`  
Disposition: REVIEW — no self-approval and no pipeline promotion

## Ergebnis

Die drei Major-Findings und neun Minor-Folds aus
`CODEX_BRIEF_mnt_review_round2_2026-07-29.md` sind auf der vorgeschriebenen
Branch umgesetzt:

1. Gemini-Orchestrierung und Mailbox-Intake sind im unexecuted AFTER-Paket
   nicht mehr bare SYSTEM/pythonw, sondern SYSTEM-Scheduler mit
   `run_in_console_session.ps1 -TargetUser qm-admin`.
2. `pipeline_view` zeigt je Phase und als `current_stage` den jüngsten
   identity-bound Run; historischer Erfolg steht getrennt in `best_verdict`,
   und ein Rückschritt wird mit `regressed=true` sichtbar.
3. Der Round-1-Verbatim-Claim ist auf den tatsächlich unveränderten
   Reboot-Ausführungsblock begrenzt. Die absichtlich geänderte Haupt-State-
   Machine wird nicht mehr als byteidentisch bezeichnet.

Diese Arbeit hat keine Scheduled Task registriert, gestartet, gestoppt,
aktiviert oder deaktiviert. Das Apply-Skript lief ausschließlich im
read-only-PLAN-Modus, nie mit `-Apply` oder `-Rollback`. Kein MT5-Prozess wurde
gestartet oder beendet; T5, T_Live und AutoTrading wurden nicht verändert. Die
Produktions-DB wurde ausschließlich über SQLite `mode=ro` gelesen.

## R1 — Benutzer-Auth in den AFTER-Verträgen

### Korrigierter Vertrag

Die beiden AFTER-XMLs besitzen weiterhin den Scheduler-Principal
`S-1-5-18/ServiceAccount`, aber ihre Actions rufen jetzt Windows PowerShell und
den vorhandenen Session-Wrapper auf:

- Gemini:
  `tools/ops/task_contract_fix_2026-07-28/after/QM_StrategyFarm_GeminiOrchestration_15min.xml:1`,
  Ziel `qm-admin`, Entry
  `run_agent_orchestration_task.py --agent gemini --max-sessions 1`,
  `WaitSeconds=14100`.
- Mailbox:
  `tools/ops/task_contract_fix_2026-07-28/after/QM_StrategyFarm_MailboxSourceIntake_Daily.xml:1`,
  Ziel `qm-admin`, Entry `mailbox_source_intake.py`,
  `WaitSeconds=2640`.

Damit stammt der Kindprozess-Token aus der angemeldeten `qm-admin`-Session.
Für Gemini bindet das den Credential-Manager-/`LOCALAPPDATA\agy`-Kontext, den
der Entry-Point selbst dokumentiert
(`tools/strategy_farm/run_agent_orchestration_task.py:25-47,73`).
Mailbox bindet entsprechend den Administrator-`CODEX_HOME` und Benutzer-Auth.
Der Wait bleibt innerhalb der jeweiligen Task-Limits und erhält Exitcode-/
Retry-Semantik.

Die package-eigenen Regressionstests prüfen Principal, Wrapper, Zielbenutzer,
Entry-Point und Wait-Budget
(`tools/strategy_farm/tests/test_task_contract_fix_package.py:16-44`).
README und Matrix unterscheiden jetzt beobachtetes BEFORE vom vorgeschlagenen
AFTER und warnen, dass XML/Force-Registrierung einen bewusst deaktivierten
Task wieder aktivieren kann
(`tools/ops/task_contract_fix_2026-07-28/README.md:22-23,48-53`;
`docs/ops/evidence/2026-07-28_mnt_review_corrections.md:383` ff.).

### Fresh-export-Nachweis

Read-only-PLAN gegen frische `Export-ScheduledTask`-Ausgaben:

```text
QM_StrategyFarm_AgyGovernor               BEFORE  would_apply
QM_StrategyFarm_CodexFleetPacer           BEFORE  would_apply
QM_StrategyFarm_GeminiOrchestration_15min BEFORE  would_apply
QM_StrategyFarm_MailboxSourceIntake_Daily BEFORE  would_apply
QM_StrategyFarm_WorkerDedupe              BEFORE  would_apply
QM_T_Live_AtLogon                         BEFORE  would_apply
QM_FTMO_AtLogon                           BEFORE  would_apply
QM_Live_MT5_SessionSupervisor             BEFORE  would_apply
```

Command:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File tools/ops/task_contract_fix_2026-07-28/Apply-TaskContractFix.ps1
```

Damit entsprechen 8/8 `before/*.xml` weiterhin dem Live-Export; kein Vertrag
wurde angewendet.

### pythonw-Crash-Evidenz

Beide Python-Entry-Points installieren den Exception-Hook vor
projektlokalen Imports. Ein Fehler vor dem normalen Run-Log wird in das
lane-eigene Log geschrieben
(`run_agent_orchestration_task.py:25-47,73`;
`mailbox_source_intake.py:49-70,97`). Die Tests injizieren je einen
`RuntimeError` und prüfen den persistierten Traceback.

## R2 — `pipeline_view`: latest, best und Regression

### Implementierter Vertrag

`pipeline_view`:

- faltet `Qnn_SUFFIX` für die Q-only Operator-Sicht und verwirft Nicht-Q-Keys
  (`farmctl.py:2209-2220`);
- überspringt Task-Metadaten ohne explizites `payload.ea_id`, statt UUID-
  Ziffern als EA-ID zu normalisieren (`farmctl.py:2246-2252`);
- wählt je `(EA,Phase)` das jüngste Work-Item nach
  `(updated_at, created_at, id)` und berechnet den historischen Bestwert
  separat (`farmctl.py:2318-2345`);
- setzt `regressed=true`, wenn die jüngste Verdict-Familie schlechter als die
  historische beste ist (`farmctl.py:2334-2338`);
- leitet `current_stage` vom jüngsten identity-bound Work-Item der EA ab
  (`farmctl.py:2354-2378`).

### Read-only-Produktionsbeleg

Die SQLite-URI wurde mit `mode=ro` geöffnet. Die bindende Abfrage:

```sql
SELECT verdict, COUNT(*) AS n, MAX(updated_at) AS newest
FROM work_items
WHERE ea_id IN ('QM5_10035','10035') AND phase='Q04'
GROUP BY verdict;
```

ergab:

```text
FAIL      58  newest=2026-07-20T05:04:12+00:00
PASS_SOFT  1  newest=2026-06-09T07:33:13Z
```

Das jüngste Work-Item ist
`ae6f5349-927f-42aa-b25f-c549fba48a64`, `Q04/NDX.DWX`,
`done/FAIL`, aktualisiert `2026-07-20T05:04:12+00:00`. Der alte Algorithmus
zeigte trotzdem den sechs Wochen älteren `PASS_SOFT`; der neue Vertrag zeigt
`verdict=FAIL`, `best_verdict=PASS_SOFT`, `regressed=true`.

Zusätzlich:

```sql
SELECT COUNT(*) AS rows, COUNT(DISTINCT ea_id) AS eas
FROM work_items WHERE phase='Q09_PORTFOLIO';
```

ergab exakt `112 rows / 85 EAs`; diese Zeilen erscheinen operatorseitig als
`Q09`. Der Regressionstest deckt neuesten FAIL nach altem PASS,
`Q09_PORTFOLIO -> Q09`, einen zukünftigen `Q88_SUFFIX`, Nicht-Q-Skip und die
UUID-Phantom-Gefahr ab
(`tools/strategy_farm/tests/test_pipeline_view_work_items.py:129-243`).

## R3 — ehrliche Reichweite der Watchdog-Verifikation

Der Runde-1-Test lief mit leerem Baseline-Pfad; PART 5c war damit SKIPPED.
Zudem ist die Haupt-Recovery-State-Machine durch Park-Awareness absichtlich
verändert. Testbeschreibung und PART 5 heißen deshalb jetzt „REBOOT SAFETY“
und behaupten keine Invarianz des Hauptblocks
(`tools/strategy_farm/tests/Test-LiveAlarmState.ps1:1-26,343`).

Der optionale Vorgängervergleich extrahiert ausschließlich den
Reboot-Ausführungsblock vom `controlled_reboot_requested`-Entry bis vor die
post-block Status/Exit-Abbildung. Letztere wurde mit Park-Awareness bewusst
geändert. Checkout-Zeilenenden werden normalisiert, danach muss der Blockinhalt
exakt gleich sein (`Test-LiveAlarmState.ps1:385-401`).

Ausgeführt gegen den per `git archive` aus `fa215b3e9` extrahierten Vorgänger:

```text
WS-E1 alarm-state tests PASS (217 assertions).
```

Der Hauptblock bleibt damit ausdrücklich „intentionally rewritten“; nur der
Reboot-Ausführungsblock ist diff-/testverifiziert unverändert. Die frühere
Zuschreibung der `cmd.exe`-Wrapper-Entfernung an
`run_agent_orchestration_task.py` ist im additiven Round-2-Abschnitt des
Runde-1-Dokuments ebenfalls korrigiert.

## R4 — Minor-Folds

- **MNT-001:** Die Zahlenbrücke ist dokumentiert:
  `11 loaded + 9 dormant + 4 no-file = 24 Manifest-Sleeves`; von 54
  divergierenden Gesamtpaaren gehören 20 zum Manifest, 34 nicht
  (`MNT-001.md:20-36`). Ein LOADED-Event ohne Hash zählt beabsichtigt als
  `hash_mismatch`; Regressionstest:
  `test_health_vacuousness.py:590`.
- **MNT-002:** 666 (Review-Basis) und 687 (Codex-Snapshot) sind als beweglicher
  append-only Kick-Zähler, nicht als Invariante, erklärt (`MNT-002.md:39-43`).
- **MNT-017:** Source-/Input-Wiring wird pro EA verlangt; 1116 ist nur der
  belegte Einzelpfad, Baskets brauchen den separaten `QM_BasketOrder`-Nachweis
  (`MNT-017.md:31-36,58-62`).
- **Static CI:** `Live_Alarm_State.ps1` ist in ASCII- und PS5.1-Parser-Listen
  aufgenommen (`test_live_uptime_watchdog_static.py:20-41`). Die drei
  Nicht-ASCII-Bytes im runtime-invoked
  `verify_ftmo_round25_live_contract.ps1:14` sind entfernt.
- **Expiry:** Entscheidung ist fail-closed. Reihenfolge ist
  `contract_invalid -> contract_expired -> maintenance -> probe_unknown`.
  PowerShell/Python sind ausgerichtet
  (`Live_Alarm_State.ps1:149-156`;
  `T_Live_Watchdog.ps1:599-623`;
  `ftmo_trial_pulse.py:98-106`;
  `silent_failure_monitor.py:866-905`). Die volle Seite liegt in
  `MNT-004.md`.
- **pythonw:** Frühe Exception-Hooks sind in beiden Entry-Points vorhanden und
  testgedeckt.
- **README:** Der mögliche Enabled=true-Reapply durch
  `Register-ScheduledTask -Xml -Force` ist dokumentiert.
- **KS-Härtung:** Fehlender Event-Hash bleibt bewusst mismatch/fail-closed und
  ist in MNT-001 plus Test festgeschrieben.

## Verifikation

Im sauberen Branch-Worktree ausgeführt:

```text
python -m pytest -q \
  test_ftmo_trial_pulse.py test_silent_failure_live_uptime.py \
  test_live_book_pulse.py test_health_vacuousness.py \
  test_pipeline_view_work_items.py test_live_uptime_watchdog_static.py

92 passed
```

Mit Package- und Entry-Point-Tests:

```text
python -m pytest -q <obige sechs> \
  test_task_contract_fix_package.py \
  test_agent_orchestration_lock.py test_mailbox_source_intake.py

119 passed
```

Zusätzlich:

```text
Test-LiveAlarmState.ps1 -BaselineWatchdogPath <fa215b3e9 extraction>
217 assertions PASS

Task-Paket read-only PLAN:
8/8 live_state=BEFORE; 8/8 action=would_apply

git diff --check:
PASS
```

Die statische Suite parste alle gelisteten Live-PowerShell-Skripte unter
Windows PowerShell 5.1 und las sie vollständig als ASCII. Beide geänderten
AFTER-XMLs wurden durch ElementTree geparst und ihre Wrapper-Invarianten
bestanden.

## Reviewer-/OWNER-gebunden

1. Das Task-Paket bleibt UNEXECUTED. Reviewer/OWNER prüft PLAN/WhatIf und
   entscheidet separat über Apply.
2. Die 54 KS-Baseline-Paare bleiben unreconciled; Round 2 ändert keine
   Laufzeit-Baseline.
3. Keine Code-/Task-Änderung ist selbst-approviert oder in die Pipeline
   promoted. Claude verifiziert MNT-003 und MNT-040 unabhängig.
