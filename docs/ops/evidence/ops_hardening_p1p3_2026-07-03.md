# OPS HARDENING P1-P3 — Evidence

**Task:** b80ee365-82af-4b7f-9ade-e9f6e66f3d31  
**Date:** 2026-07-03  
**Author:** Claude (claude-orchestration-3)  
**Branch:** agents/claude-orchestration-3

## Summary

Four deliverables implemented per OWNER process review 2026-07-03 and
`docs/ops/OPERATING_RULES_2026-07-03.md`.

---

## Deliverable 1 — FACTORY_OFF.flag master switch

**Status:** COMPLETE

Software interlock: `D:/QM/strategy_farm/state/FACTORY_OFF.flag`. When present,
all factory automation no-ops immediately.

### Covered components

| Component | Location | Guard added |
|-----------|----------|------------|
| `farmctl.py` pump | `tools/strategy_farm/farmctl.py:5097` | Returns `{"skipped": "FACTORY_OFF.flag set"}` |
| `run_pump_task.py` | `tools/strategy_farm/run_pump_task.py:23-25` | `return 0` if flag present |
| `sweep_enqueue_built_eas.py` | `tools/strategy_farm/sweep_enqueue_built_eas.py:44-46` | `sys.exit(0)` if flag present |
| `factory_watchdog.ps1` | `tools/strategy_farm/factory_watchdog.ps1:41-50` | `exit 0` + log record |
| `reconcile_orphans.ps1` | `tools/strategy_farm/reconcile_orphans.ps1:24-30` | `exit 0` + log record |
| `run_smoke.ps1` post-run pump | `framework/scripts/run_smoke.ps1` | Skips `run_pump_task.py` spawn |

### Factory_OFF.ps1 additions (vs prior version)

- `$QM_RESPAWN_TASKS` array: FactoryWatchdog_15min, FactoryON_AtLogon, ReconcileOrphans_Hourly — disabled to prevent autonomous restart after OFF
- Step 4: kills stray `run_smoke.ps1` wrapper pwsh processes (path-anchored, never T_Live)
- Step 5: saves current `codex_parallel` value to flag file JSON, sets to 0
- Step 6: writes `FACTORY_OFF.flag` with JSON `{off_at, codex_parallel_before}`
- Step 7: prints still-active ALWAYS_ON tasks (dashboards, health, etc.)

### Factory_ON.ps1 additions (vs prior version)

- Step 0: removes `FACTORY_OFF.flag`; restores `codex_parallel` from flag JSON
- Step 1b: re-enables `$QM_RESPAWN_TASKS` (watchdog, auto-logon, reconciler)
- Step 8: warns if `disabled_terminals.txt` contains non-standard entries beyond T8-T10

### Validation

```
py_compile: farmctl.py OK
py_compile: run_pump_task.py OK
PS parser:  Factory_OFF.ps1 OK
PS parser:  Factory_ON.ps1 OK
PS parser:  reconcile_orphans.ps1 OK
PS parser:  factory_watchdog.ps1 OK
```

---

## Deliverable 2 — TestWindow_ON.ps1 / TestWindow_OFF.ps1

**Status:** COMPLETE

Rule 12 (OPERATING_RULES_2026-07-03) requires full quiesce before any ad-hoc
backtest window: Factory_OFF + watchdog/FactoryON/Reconciler disabled + codex_parallel=0
+ stray run_smoke wrappers killed.

### TestWindow_OFF.ps1

Wraps Factory_OFF.ps1 and adds:
1. Kills residual `run_pump_task.py` spawns (triggered by run_smoke wrappers completing just before kill)
2. Quiesce verification checklist (6 checks):
   - FACTORY_OFF.flag present
   - codex_parallel=0
   - terminal_worker daemons=0
   - terminal64 (non-T_Live)=0
   - run_smoke wrappers=0
   - run_pump_task spawns=0

### TestWindow_ON.ps1

Wraps Factory_ON.ps1 and adds:
1. Restore verification checklist (3 checks):
   - FACTORY_OFF.flag removed
   - codex_parallel != 0
   - terminal_worker daemons > 0

### Validation

```
PS parser: TestWindow_OFF.ps1 OK
PS parser: TestWindow_ON.ps1 OK
```

---

## Deliverable 3 — Agent-lane robustness

**Status:** COMPLETE

### Heartbeat file

`run_agent_orchestration_task.py` writes `D:/QM/strategy_farm/state/lane_<agent>_heartbeat.json`
before spawning each agent process. Contains `{agent, slot, pid, at}`. File mtime is the
liveness signal.

### Router stale-lane release

`agent_router.py:release_stale_in_progress()` updated with two release triggers:
1. Task age > 6h (unconditional, existing behaviour)
2. Task age > 2h (`LANE_HEARTBEAT_STALE_HOURS`) AND agent's heartbeat file is stale —
   releases sooner when lane clearly died

New `_lane_heartbeat_stale(root, agent_id)` function: returns True only if heartbeat file
EXISTS but mtime is older than 2h. Missing file = treat lane as available (new deployment,
factory-OFF, first run).

### Router disabled-lane guard (schtasks)

`_lane_task_disabled(agent_id)` added to `agent_router.py`:
- Maps `_AGENT_LANE_TASKS` dict (agent_id → scheduler task name)
- Queries `schtasks /query /tn <name> /fo CSV /nh`, returns True if "Disabled" in output
- 120s in-process cache (`_LANE_TASK_STATUS_CACHE`) to avoid hammering scheduler per cycle
- Fails open (returns False) on any error, platform != win32, or unknown agent
- Called in `_eligible_agents()` after the heartbeat-stale check

This closes the gap where an agent with no heartbeat file (never-run or deleted) would
still be eligible for routing even if its task is Disabled in Task Scheduler.

### Pump janitor

`farmctl.py` pump now calls `agent_router.release_stale_in_progress(root)` via lazy import
immediately after the FACTORY_OFF guard. Result stored in `result["stale_task_release"]`.
This mirrors the same call in `route_once` and ensures stale IN_PROGRESS tasks are freed
even if the router task lags behind the pump cycle.

### Validation (2026-07-03 cycle)

```
py_compile: agent_router.py  OK
py_compile: farmctl.py       OK
py_compile: run_agent_orchestration_task.py OK

_lane_task_disabled check:
  claude: disabled=False  (QM_StrategyFarm_ClaudeOrchestration_15min  = Running)
  codex:  disabled=False  (QM_StrategyFarm_CodexOrchestration_15min   = Running)
  gemini: disabled=False  (QM_StrategyFarm_GeminiOrchestration_15min  = Ready, re-enabled)
```

---

## Deliverable 4 — GeminiOrchestration G: vault fix

**Status:** COMPLETE

**Root cause:** `QM_StrategyFarm_GeminiOrchestration_15min` runs as SYSTEM in a
scheduled task. SYSTEM has no G: (Google Drive for Desktop) mount — it is per-user.
Any G: access in the prompt raised `PermissionError` and stranded the task IN_PROGRESS
(Rule 13, OPERATING_RULES_2026-07-03).

**Fix:** `run_agent_orchestration_task.py:build_prompt()` now skips the three G: vault
lines (`Current Operating State.md`, `AI Agent Routing and Role Contracts.md`,
`_OPEN ITEMS.md`) when `agent == "gemini"`. Claude and Codex run interactively or have
G: via the user session — unaffected.

### Validation

```
py_compile: run_agent_orchestration_task.py OK
```

---

## Files changed

```
tools/strategy_farm/Factory_OFF.ps1          (new in this branch)
tools/strategy_farm/Factory_ON.ps1           (new in this branch)
tools/strategy_farm/factory_watchdog.ps1     (new in this branch)
tools/strategy_farm/qm_tasks.manifest.ps1    (new in this branch)
tools/strategy_farm/reconcile_orphans.ps1    (new in this branch)
tools/strategy_farm/TestWindow_OFF.ps1       (new in this branch)
tools/strategy_farm/TestWindow_ON.ps1        (new in this branch)
tools/strategy_farm/farmctl.py               (modified: FACTORY_OFF guard in pump)
tools/strategy_farm/run_pump_task.py         (modified: FACTORY_OFF guard in main)
tools/strategy_farm/agent_router.py          (modified: heartbeat stale check + _lane_task_disabled + pump janitor)
tools/strategy_farm/run_agent_orchestration_task.py  (modified: G: skip + heartbeat write)
framework/scripts/run_smoke.ps1              (modified: FACTORY_OFF guard on post-run pump)
docs/ops/evidence/ops_hardening_p1p3_2026-07-03.md  (this file)
```

## Risks / blockers

- `sweep_enqueue_built_eas.py` — not in this worktree's branch but has FACTORY_OFF guard in main repo; included in D1 table for completeness
- factory_watchdog.ps1 and reconcile_orphans.ps1 reference `qm_tasks.manifest.ps1` via dot-source at `$PSScriptRoot` — requires both files to exist in the same directory (satisfied here)
- FACTORY_OFF.flag does NOT block the heartbeat write itself — heartbeats continue during factory-OFF so that on Factory_ON the router doesn't see stale heartbeats as a reason to skip agents

## Recommended next step

Merge to main; OWNER should verify TestWindow_OFF.ps1 / TestWindow_ON.ps1 on next ad-hoc test window.
