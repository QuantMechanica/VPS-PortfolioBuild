# CODEX BRIEF — Review + Regression-Tests: Factory_ON/OFF Live-Fixes vom 2026-07-31

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude (close-review)
**Arbeitsverzeichnis:** dein Orchestration-Worktree; Factory-Ops-Kommandos sind NICHT Teil dieses Tickets.

## Kontext (Befund mit Beleg)

Die Factory wurde 2026-07-31 05:42Z erfolgreich gestartet (9/9 Worker, 7 Restart-Holds
released, Receipt im ON-Output; DB-SHA nach Release `3699f70625a9d229…`). Auf dem Weg
dorthin sind **fünf Live-Defekte** in den MNT-052-gehärteten Skripten gefixt worden,
die jede Aktivierung deterministisch blockierten. Die bestehenden Suites (46 passed)
haben KEINEN davon gefangen, weil sie die betroffenen Codepfade nie ausführen:

| Commit | Datei | Defekt |
|---|---|---|
| `f01423c07` | Factory_OFF.ps1 | `Assert-PublishedFactoryOffRecord` fütterte U+FEFF (BOM) in `ConvertFrom-Json` → PS5.1 „Invalid JSON primitive" NACH Flag-Publish; Lock+Request strandeten |
| `d052657f6` | Factory_ON.ps1 | `$allowed = @( ,$base, ,@($base+'-NoPause') )` → beide Kandidaten `Count=1`; `Assert-CanonicalFactoryOnHostProcess` konnte NIE matchen (auch nicht den eigenen Bootstrap) |
| `a8339d57c` | beide | Validator-JSON aus `2>&1`-Merge geparst; Interpreter-stderr („Could not find platform independent libraries") zerstörte den Parse → Last-Line-Binding |
| `26ab194ea` | beide | PS5.1 + EAP=Stop + `2>&1` = NativeCommandError beim ersten stderr-Byte (Pacer-Cleanup, Runtime-Validator-Capture, Rollback-Pacer) → EAP=Continue-Scoping |
| `fb885818d` | Factory_ON.ps1 | `.ContainsKey()` auf `[ordered]` (OrderedDictionary hat nur `.Contains()`) → Crash im Quiescence-Enable-Loop NACH Worker-Start → Voll-Rollback |
| `b9771f554` | Factory_ON.ps1 | Health-Gate-Timeout 300→1800 s (warmer Pump-Lauf gemessen ~257 s, Log `pump_task_20260729T071513Z.log`; Cold-Start über 2.188-Item-Backlog länger) |

Zusätzlich neu committed: `tools/strategy_farm/build_runtime_activation_decision.py`
(`12b830c45`) — hat die konsumierten Runtime-Decisions erzeugt (Nonce `f685ffd2…`).

**Wichtige Umgebungsfakten** (Memory-verankert, nicht „reparieren"):
- Das kanonische Python (AppData-Pfad) ist ein Torso; `sys.prefix` fällt auf CWD zurück
  und emittiert IMMER die Prefix-Warnung auf stderr. Der prefix=cwd-Fallback ist
  TRAGEND (`import framework` in terminal_worker.py). PYTHONHOME setzen ist verboten.
- Repo hat `core.autocrlf=true`; die 12 Source-Bindings vergleichen ROHE Worktree-Bytes
  gegen Blob — deshalb normalisiert der Builder auf Blob-Bytes (LF).

## Aufgaben

1. **Adversarialer Review der sechs Commits.** Prüfe insbesondere: Schwächt einer der
   Fixes einen Guard ab? (Anspruch: nein — Last-Line-Binding und EAP-Scoping ändern nur
   die Dekodier-/Fehlerkanal-Robustheit; Erfolgssemantik unverändert.) PS5.1- UND
   PS7-Semantik beider Skripte. Byte-Exaktheit des BOM-Handlings. EAP-Scoping-Leaks
   (finally-Pfad). Timeout-Kalibrierung: nenne Gegenargumente, falls 1800 s falsch ist.
2. **Regression-Tests, die die fünf Klassen WIRKLICH ausführen** (nicht AST-only), in
   `tools/strategy_farm/tests/`:
   - Kandidaten-Array-Shape von `Assert-CanonicalFactoryOnHostProcess` (Count 7/8, nicht 1).
   - BOM-Roundtrip durch `Assert-PublishedFactoryOffRecord` (BOM + BOM-los).
   - `2>&1`-Merge mit stderr-Noise vor kompaktem JSON → Parse liefert das JSON (beide Skript-Pfade).
   - EAP=Stop + native stderr → kein Terminieren an den drei geschirmten Stellen.
   - `[ordered]`-Map `.Contains`-Semantik im Quiescence-Loop-Extrakt.
   Pattern: Funktionen per Dot-Source in PS5.1-Subprozess laden und mit synthetischen
   Inputs ausführen (siehe bestehende `Test-*.ps1`-Harnesse bzw. pytest-Wrapper, die
   powershell.exe spawnen). Tests dürfen KEINE Factory-Prozesse/Tasks/Flags anfassen.
3. **Härtung `build_runtime_activation_decision.py`** + fokussierte pytest-Datei:
   argparse (--repo-root, --flag, --decision-id), Abbruch bei dirty repo (existiert),
   Abbruch wenn Preparation-Window abgelaufen wäre relevant? (begründen, nicht raten),
   Exit-Codes, kompakte Selbstverifikation via `factory_runtime_activation.validate_…`
   als Import statt Subprozess.

## Do NOT

- KEIN Factory_OFF/ON-Lauf, keine Scheduled-Task-, Flag-, DB- oder Prozess-Mutation.
- Laufende Backtests nicht stören; niemals T5, niemals T_Live.
- V5-/V6-Preactivation-Artefakte und Schema-v2-Successor-Worktrees NICHT anfassen.
- Keine Skip/XFail/Assertion-Abschwächung; Findings ehrlich rapportieren.
- Commits mit expliziten Pathspecs; nur Test-/Tool-/Doku-Dateien.

## Deliverable

`docs/ops/evidence/2026-07-31_factory_on_fix_review.md` mit: Verdikt je Commit
(CONFIRM/FINDING mit file:line), Testliste + Laufnachweis (Kommando + Summary),
offene Risiken. Danach `update-task <id> --state REVIEW --artifact-path <deliverable>
--verdict "<kurz>"`.
