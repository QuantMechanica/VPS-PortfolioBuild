# CODEX BRIEF — MNT-003 Apply + Observe (nach APPROVED-Plan 1326c521)

**Ticket-Klasse:** ops_issue · **Autorisierung:** Claude close-review APPROVED auf
`1326c521` (Plan `docs/ops/evidence/2026-07-31_mnt003_minimal_plan.json`, WhatIf 5/5
hash-verifiziert, unabhängig re-run exit 0). Rollback-Autorität: inklusive — bei
JEDEM Fehlverhalten sofort exaktes Before-XML-Rollback, kein Debugging am offenen Herzen.

## Aufgaben

1. **Apply:** `Apply-Mnt003MinimalPlan.ps1 -Mode Apply -PlanPath <plan.json>` unter
   PS5.1 elevated. Vorher: Live-Hashes erneut prüfen (das Tool tut es — Abbruch bei
   Drift). Die Factory läuft; KEINE Task-Stops/Starts, kein Warten auf Trigger nötig.
2. **Observe:** Beobachtungsfenster über die betroffenen Trigger: AgyGovernor/
   CodexFleetPacer/GeminiOrchestration je ≥2 Zyklen (≤1 h), WorkerDedupe + Mailbox
   bis zum jeweils nächsten regulären Trigger (Mailbox 06:07 täglich → dokumentiere
   den ersten Post-Apply-Lauf; nicht künstlich auslösen). Kriterium: LastTaskResult=0,
   Kind läuft in Session 1 unter qm-admin-Token (Prozess-Evidenz: Session-ID +
   CommandLine), keine 0x800710E0/0xC0000142-Events im Operational-Log.
3. **Installer-Alignment:** Die Install-Skripte der fünf Tasks auf das neue
   SYSTEM+Helper-Muster nachziehen (eigener Commit, damit ein Reinstall MNT-003
   nicht wieder einführt). Betroffene Dateien laut Plan-Doc §Open risks.
4. **Rollback-Pfad testweise NICHT ausführen** — nur bei realem Fehlverhalten.

## Do NOT

- Kein Enable/Disable/Start/Stop; keine Trigger-/Settings-Änderung.
- Kein Factory_OFF/ON; laufende Backtests nicht stören; niemals T5/T_Live/FTMO.
- Bei Partial-Apply-Fehler: automatisches Rollback des Tools greifen lassen,
  Zustand dokumentieren, STOP → REVIEW mit Befund.

## Deliverable

`docs/ops/evidence/2026-07-31_mnt003_apply_observe.md`: Apply-Output, Post-Apply-
Hashes/XML-Diffs, Beobachtungstabelle je Task (Trigger-Zeit, Result, Kind-PID/Session),
Event-Log-Auszug, Installer-Commit. Danach `update-task → REVIEW`.
