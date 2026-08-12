# CODEX BRIEF — MNT-003 Apply v2 + Observe (nach bestätigter Root-Cause R2)

**Ticket-Klasse:** ops_issue · **Autorisierung:** Claude close-review APPROVED
auf R2-Diagnose `c913effd` (Root-Cause = literale Apostrophe im rohen
`-Arguments`-Wert; Kandidat ohne Wrapper exit 0 auf identischem
SYSTEM→qm-admin-Pfad). Plan:
`docs/ops/evidence/2026-07-31_mnt003_minimal_plan_v2.json` (WhatIf 5/5
Hash-Match, exit 0). Rollback-Autorität inklusive — bei JEDEM Fehlverhalten
sofort exaktes Before-XML-Rollback.

## Aufgaben

1. **Pre-Apply:** WhatIf gegen den v2-Plan erneut ausführen; Abbruch bei
   irgendeinem Hash-Drift.
2. **Apply:** `Apply-Mnt003MinimalPlan.ps1 -Mode Apply -PlanPath <v2.json>`
   (PS5.1 elevated). KEINE Task-Stops/Starts.
3. **Observe:** AgyGovernor/CodexFleetPacer/GeminiOrchestration je ≥2 reguläre
   Zyklen (≤1 h): LastTaskResult=0, Kind läuft in Session 1 unter
   qm-admin-Token (PID+Session+CommandLine-Beleg — ohne Apostrophe im
   Kind-Pfad!), keine 0x800710E0/0xC0000142/0x80070002-Events. WorkerDedupe +
   Mailbox: ersten regulären Post-Apply-Lauf dokumentieren (Mailbox 06:07
   täglich — nicht künstlich auslösen; falls außerhalb des Ticketfensters,
   explizit als offen ausweisen).
4. **Installer-Alignment:** Erst NACH bestandenem Observe der drei zyklischen
   Tasks die fünf Install-Skripte auf das v2-Muster ziehen (eigener Commit,
   korrekte `-Arguments`-Serialisierung — der R1-Fehler darf nicht in den
   Installern landen).
5. **Bekanntes Nebensignal:** AgyGovernor kann HTTP 401 loggen (separates
   agy-Credential-Thema, KEIN Task-Contract-Fehler). Result=0 mit 401 im Log
   gilt als Observe-PASS für den Task-Contract; 401 als Findings-Zeile
   rapportieren.

## Do NOT

- Kein Enable/Disable/Start/Stop; kein Factory_OFF/ON; niemals T5/T_Live/FTMO.
- Bei Partial-Apply: Auto-Rollback greifen lassen, dokumentieren, STOP→REVIEW.

## Deliverable

`docs/ops/evidence/2026-07-31_mnt003_apply_v2_observe.md`: Apply-Output,
Post-Apply-Hashes, Beobachtungstabelle je Task, Event-Log-Auszug,
Installer-Commit (falls erreicht). Danach `update-task <id> --state REVIEW
--artifact-path <deliverable> --verdict "<kurz>"`.
