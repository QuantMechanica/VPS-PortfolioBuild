# QM-TODO-20260821-202 — pipeline_state.json snapshot: reactivation

**Date:** 2026-08-21
**Router task:** 7e6048a1
**Decision:** REACTIVATE (file is actively consumed) — via a dedicated hourly rebuild task.

---

## 1. Consumer inventory (repo-wide grep for `pipeline_state.json`)

| Consumer | Reads content today? | Notes |
|---|---|---|
| `scripts/export_public_snapshot.ps1` | **YES — active, public** | Single source of truth for public-snapshot live fields (`by_phase`, `agents_watchdog`, `pipeline.*`) that feed `public-data` → quantmechanica.com. Throws if the file is missing. Runs **only inside** the `QM_Public_Snapshot_Hourly` wrapper, which rebuilds the file first (see §2). |
| `scripts/qm_pipeline_summary.py` | **YES — internal, dormant** | Reads `STATE_FILE` (`state.mt5`, `agents_watchdog`, `by_status`, `dispatch`) for the daily summary mail. `read_json_safe` with **no freshness check**. **Not wired to any scheduled task** and nothing else invokes it (grep: only self-reference) — dormant/manual. Would silently read stale state if run by hand. |
| `scripts/build_pipeline_state.py` | writes it | The builder. Read-only derivation from the `work_items` DB + disk artifacts; atomic write of `pipeline_state.json` only. |
| `scripts/backup_nightly.ps1` | backs it up | robocopy of `reports/state` json — does not read content. |
| `scripts/install_public_snapshot_scheduled_task.ps1` | — | Installs `QM_Public_Snapshot_Hourly`; description mentions the file. |
| `tools/strategy_farm/render_cockpit.py` | **NO — explicitly excluded** | Comment (lines 2304–2305): worker liveness comes from health.json, *"never from pipeline_state.json, whose content contradicted the DB in the 2026-07-19 audit."* |
| docs/* (COMPANY_AUDIT, MNT-040, source_harvest audit, evidence, CLAUDE.md) | — | Documentation references only. |

**Active content readers: 2** — `export_public_snapshot.ps1` (public) and `qm_pipeline_summary.py` (internal).

## 2. Root cause of the 23-day staleness (premise correction)

The task premise ("no matching `QM_*` scheduled task exists") is **incorrect**. Evidence:

- `Get-ScheduledTask` shows **`QM_Public_Snapshot_Hourly`** = *Ready*, hourly.
- Its wrapper `scripts/run_public_snapshot_task.ps1` **runs `build_pipeline_state.py` (line 123)** before exporting.
- But the wrapper runs `public_snapshot_incident_guard.py` **first (lines 88–121)**, and the guard **fail-closes the whole wrapper** — build step included — whenever a Q02-bypass incident hold is active.

Wrapper log `C:\Windows\Temp\qm_public_snapshot.log` (every hour today):
```
[2026-08-21T12:07:07Z] public_snapshot_task exit=1 error=public snapshot publication refused by
  incident guard (rc=3 valid=True holds=[STALE_BUILD_RESULT_AUTO_Q02_BYPASS:88ba4560-...] error=)
```

So `pipeline_state.json` froze at `generated_at 2026-07-29T12:07Z` because the publication guard (deliberately fail-closed for the **public** book) collaterally blocks the **internal** build. This matches the standing note *"Export fail-closed hinter 2 Q02-Bypass-Holds"*. **The guard is ROT-adjacent verdict/publication logic — not touched.**

## 3. What changed and why

Decoupled the **read-only internal state build** from **public publication** by adding a dedicated task that runs *only* `build_pipeline_state.py`:

- **New file:** `scripts/install_pipeline_state_scheduled_task.ps1`
- **New task:** `QM_StrategyFarm_PipelineState` — SYSTEM (S-1-5-18) / HighestAvailable, `pythonw.exe "…\build_pipeline_state.py"`, WorkingDirectory `C:\QM\repo`, TimeTrigger repetition **PT1H**, ExecutionTimeLimit 10 min, MultipleInstances IgnoreNew. Runtime shape mirrors sibling `QM_StrategyFarm_QuotaGovernor`.

Why this is safe and in-scope:
- `build_pipeline_state.py` derives state **read-only** and atomically writes **only** `pipeline_state.json`. It publishes nothing to `public-data`/git and changes no verdicts.
- It does **not** bypass the publication guard, which gates a *separate* export step. The public snapshot stays held while Q02-bypass holds stand; only the internal snapshot is refreshed.
- `pythonw.exe` = GUI-subsystem interpreter → no console window (CREATE_NO_WINDOW-equivalent), the canonical sibling pattern.

Acceptance ("no consumer silently reads a July snapshot anymore") is met by **fresh data + task**: the file is now current and stays current hourly, so both content readers — including the unguarded dormant `qm_pipeline_summary.py` — read live state.

## 4. Verification / measurements

Manual build once (cwd `C:\QM\repo`, plain python):
```
generated_at 07/29 → 08/21 14:47:45 (local) / 12:47Z  schema_version=1
by_phase {P2:1935, P3:934, P4:456, P5:252, P6:227, P7:172, P8:39, P9:31}
by_status {READY:34, BLOCKED:2602, IN_PROGRESS:209}   (legacy P* phase keys retained by design)
```

Task registered + triggered once (SYSTEM):
```
LastTaskResult=0 (success)   LastRunTime=2026-08-21 14:49:49
pipeline_state.json mtime 14:47:45 → 14:49:30 (rebuilt)   generated_at=14:49:30
```

Final cycle re-verification after installer tests:

```
LastTaskResult=0   LastRunTime=2026-08-21 14:52:52
generated_at=2026-08-21T12:52:43Z   schema_version=1
per_ea_source=work_items   by_phase present   by_status present
```

Registered XML confirms: `<UserId>S-1-5-18</UserId>`, `<RunLevel>HighestAvailable</RunLevel>`, `<Interval>PT1H</Interval>`, `pythonw.exe "C:\QM\repo\scripts\build_pipeline_state.py"`, `WorkingDirectory C:\QM\repo`.

Tests:
```
python -m pytest tools/strategy_farm/tests/test_pipeline_state_installer.py -x -q
5 passed in 1.77s
```
(task name / SYSTEM ServiceAccount / builder ref / no-window pythonw / hourly cadence / documented rollback / PS5.1 parse)

## 5. Residual / notes

- `qm_pipeline_summary.py` remains dormant (no scheduled task) and has no freshness guard. Risk is now moot at the source (file is kept fresh). If it is ever re-wired to a schedule, add a `generated_at` age assertion there — noted, not commissioned.
- No change to the publication guard, `QM_Public_Snapshot_Hourly`, gate thresholds, verdicts, or SQL phase keys.

## 6. Rollback

```
schtasks /delete /tn "QM_StrategyFarm_PipelineState" /f
```
Then remove `scripts/install_pipeline_state_scheduled_task.ps1` and
`tools/strategy_farm/tests/test_pipeline_state_installer.py` if fully reverting.
The manually-refreshed `pipeline_state.json` is a normal snapshot artifact; no restore needed
(the public wrapper rebuilds it whenever the incident holds clear).
