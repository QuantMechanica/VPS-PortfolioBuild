# CODEX BRIEF — MNT-003 R2: 0x80070002-Diagnose auf Wegwerf-Klon (KEIN Apply)

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude (close-review)
**Kontext:** Apply-Ticket `4ac50dcd` APPROVED-as-executed: der SYSTEM+Helper-
Kontrakt scheiterte am ERSTEN regulären Trigger (AgyGovernor, Event 201,
`0x80070002` = ERROR_FILE_NOT_FOUND, Laufzeit ~2 s) und wurde exakt
zurückgerollt (5/5 Before-XML-Hash-Match, unabhängig verifiziert). Die fünf
Live-Tasks laufen wieder unter `qm-admin/Interactive/Highest` — **sie werden in
diesem Ticket NICHT angefasst.** Evidenz:
`docs/ops/evidence/2026-07-31_mnt003_apply_observe.md`.

## Aufgabe: Root-Cause von 0x80070002 beweisen — offline, auf Wegwerf-Klon

1. **Wegwerf-Task** `QM_TMP_MNT003_PROBE` anlegen (eigener Name, kein
   QM_StrategyFarm_*-Präfix, Trigger: on-demand only, disabled nach Gebrauch,
   am Ende LÖSCHEN): exakt die geplante AgyGovernor-Action aus dem Plan-JSON
   (SYSTEM/ServiceAccount/Highest + `run_in_console_session.ps1`-Helper +
   pythonw agy_governor.py). Manuell starten, Ergebnis + Kind-Prozess-Evidenz
   erfassen. Das reproduziert den Fehler ohne die Produktionskontrakte.
2. **Hypothesen einzeln falsifizieren/bestätigen (mit Beleg):**
   - **H1 Environment-Block:** Startet der Helper das Kind mit dem
     USER-Environment aus dem Token (CreateEnvironmentBlock/äquivalent) oder
     erbt das Kind SYSTEMs Env? Unter SYSTEM zeigt `%LOCALAPPDATA%` auf
     `systemprofile` — jeder darauf gebaute Pfad (z. B.
     `%LOCALAPPDATA%\agy\bin\agy.exe`) existiert dort nicht -> 0x80070002.
     Prüfe `run_in_console_session.ps1` Quelle + instrumentiere den Probe-Lauf
     (Kind loggt `$env:LOCALAPPDATA`, `$env:PATH`, `whoami`, Session-ID).
   - **H2 Pfad in Action/Helper:** Existieren alle in der geplanten Action
     referenzierten Dateien aus SYSTEM-Sicht (Helper-Pfad, pythonw-Pfad,
     agy_governor.py, WorkingDirectory)? `Test-Path` je Komponente als SYSTEM
     (der Probe-Task selbst kann das loggen).
   - **H3 Helper-Argumentkontrakt:** Vergleiche die geplante Action Zeile für
     Zeile mit der FUNKTIONIERENDEN TesterCachePurge-Action
     (`install_tester_cache_purge_scheduled_task.ps1`) — Parameterreihenfolge,
     Quoting, -File vs -Command, WorkingDirectory-Semantik.
   - Wichtig: `agy_governor.py` läuft mit cwd=C:\QM\repo und braucht den
     User-CredMan (`CredReadW`) — der Helper MUSS das User-Token liefern;
     ein SYSTEM-Fallback wäre kein Fix, sondern ein neuer Defekt.
3. **Fix-Vorschlag als Plan v2** (gleiches Minimal-Format wie
   `2026-07-31_mnt003_minimal_plan.json`): kleinste Kontraktänderung, die den
   bewiesenen Defekt schließt (z. B. Helper lädt Env-Block aus Token; oder alle
   Pfade absolut). WhatIf-Lauf beilegen. **KEIN Apply an den fünf Tasks** —
   Apply erst nach Claudes close-review APPROVED in einem Folgeticket.

## Do NOT

- Die fünf MNT-003-Tasks nicht verändern, nicht starten, nicht stoppen.
- Kein Enable/Disable anderer Tasks; kein Factory_OFF/ON; niemals T5/T_Live/FTMO.
- Probe-Task nach Abschluss restlos entfernen (Unregister), Nachweis beilegen.
- Keine PYTHONHOME-Setzung; Farm-Python braucht cwd=C:\QM\repo (prefix=cwd trägt).

## Deliverable

`docs/ops/evidence/2026-07-31_mnt003_r2_diagnosis.md`: Probe-Repro (Events,
Result), H1–H3-Verdikte mit Belegen, Plan v2 + WhatIf, Probe-Cleanup-Nachweis.
Danach `update-task <id> --state REVIEW --artifact-path <deliverable>
--verdict "<kurz>"`.
