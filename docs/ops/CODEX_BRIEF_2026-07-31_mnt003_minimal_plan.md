# CODEX BRIEF — MNT-003 Minimal-Plan: Interactive-Task-Contract-Fix (PLAN + WHATIF, KEIN APPLY)

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude (close-review; Apply nur nach APPROVED)

## Kontext

MNT-003 (Selbstheilung tot: Interactive-Tasks enden 0x800710E0, Arbeit wird nur
eingereiht) betrifft fünf Taskverträge: `QM_StrategyFarm_AgyGovernor`,
`QM_StrategyFarm_CodexFleetPacer`, `QM_StrategyFarm_GeminiOrchestration_15min`,
`QM_StrategyFarm_MailboxSourceIntake_Daily`, `QM_StrategyFarm_WorkerDedupe`.

Der bisherige Lösungsweg ist TOT: V5-Preactivation ist terminal gescheitert
(RECOVERED_NO_APPLY_EXACT_BEFORE), V6 (179 KB Executor, uncommitted Worktree
`mnt003-v5-continuation-20260730`) wird NICHT weiterverfolgt — der Apparat war um
Größenordnungen zu schwer für „fünf Task-Actions reparieren". Seit 2026-07-31 05:42Z
ist die Factory ON; alle fünf Tasks sind ENABLED und feuern in der interaktiven
Session. Der Defekt manifestiert sich in Disconnect-/Lock-Szenarien.

## Aufgaben (strikt read-only gegenüber Task-Scheduler!)

1. **Ist-Vermessung:** Für die fünf Tasks über die nächsten Zyklen (mind. 2 h Fenster):
   XML-Definition exportieren (`Export-ScheduledTask`), Principal/LogonType/RunLevel,
   Trigger, Action; `Get-ScheduledTaskInfo` LastRunTime/LastTaskResult-Verlauf; Event-Log
   `Microsoft-Windows-TaskScheduler/Operational` nach 0x800710E0-Instanzen je Task.
   Beleg: Roh-XML + Query-Outputs ins Evidence-Verzeichnis.
2. **Root-Cause je Task bestätigen oder verwerfen** (nicht pauschal „interactive böse"):
   welcher LogonType/Trigger-Zustand produziert 0x800710E0 konkret, und warum sind
   andere interaktive QM-Tasks (z. B. Pump_5min) nicht betroffen — oder sind sie es?
3. **Minimal-Plan:** pro Task die kleinste Kontraktänderung, die die Fehlerklasse
   schließt (z. B. LogonType/pythonw-Direct-Action wie beim Purge-Task-Fix — prüfe, wie
   `QM_StrategyFarm_TesterCachePurge` nach seinem 0x800710E0-Fix konfiguriert wurde,
   Memory-Referenz: Direct-Run brauchte SYSTEM). Plan als EIN JSON
   (`before`/`after` je Task, Rollback = exaktes Before-XML-Reimport) + EIN
   Apply-Skript ≤300 Zeilen, das ausschließlich `Register-ScheduledTask`/
   `Set-ScheduledTask` mit den Plan-Daten nutzt. WhatIf-Modus, der NUR liest und den
   Diff druckt. KEINE Envelopes, KEINE Holds, KEINE Receipts über das eine
   Evidence-JSON hinaus, KEINE neuen Verzeichnisbäume auf D:.
4. WhatIf ausführen, Output ins Deliverable.

## Do NOT

- KEIN Apply. Kein Enable/Disable/Start/Stop irgendeines Tasks.
- Kein Factory_OFF/ON; laufende Backtests nicht stören; niemals T5/T_Live/FTMO-Tasks.
- V5-/V6-Artefakte weder ausführen noch erweitern; nicht auf deren Receipts aufbauen.
- Keine Interpretation von „Factory ON = alles gesund" — messen.

## Deliverable

`docs/ops/evidence/2026-07-31_mnt003_minimal_plan.md` + Plan-JSON + Apply/WhatIf-Skript
(committed, mit Pathspecs). Danach `update-task <id> --state REVIEW --artifact-path
<deliverable> --verdict "<kurz>"`. Apply erfolgt erst nach meinem close-review
APPROVED in einem Folgeticket.
