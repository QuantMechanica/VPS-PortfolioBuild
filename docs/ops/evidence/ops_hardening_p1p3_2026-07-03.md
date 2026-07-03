# OPS HARDENING P1-P3 — Evidence

**Date:** 2026-07-03  
**Task:** b80ee365  
**Agent:** Claude  
**Branch:** agents/board-advisor (C:/QM/repo)

---

## Deliverable 1: FACTORY_OFF.flag master switch

**Flag path:** `D:/QM/strategy_farm/state/FACTORY_OFF.flag`  
**Flag content (JSON):** `{"off_at": "<timestamp>", "codex_parallel_before": "<N>"}`

### Changes

| File | What changed |
|------|-------------|
| `Factory_OFF.ps1` | Creates flag (saves codex_parallel); disables resurrection-vector tasks (watchdog/FactoryON_AtLogon/ReconcileOrphans); kills stray run_smoke pwsh wrappers (path-anchored, never T_Live); sets codex_parallel=0; prints always-on task list |
| `Factory_ON.ps1` | Removes flag (reads saved codex_parallel); re-enables resurrection-vector tasks; restores codex_parallel; warns about disabled_terminals entries outside T8-T10 |
| `factory_watchdog.ps1` | Added check at top: if FACTORY_OFF.flag exists → log `noop_factory_off_flag` + exit 0 |
| `reconcile_orphans.ps1` | Added check at top: if FACTORY_OFF.flag exists → log skip + exit 0 |
| `run_pump_task.py` | Added `FACTORY_OFF_FLAG` constant; `main()` returns 0 immediately if flag exists |
| `farmctl.py pump()` | Added check at start: returns `{"skipped": "FACTORY_OFF.flag set"}` if flag exists |
| `framework/scripts/run_smoke.ps1` | Post-run pump hook wrapped in `if (-not (Test-Path $factoryOffFlagPath))` guard |
| `sweep_enqueue_built_eas.py` | Added `_FACTORY_OFF_FLAG` check before module-level `APPLY` assignment |

### Resurrection-vector tasks disabled by Factory_OFF (new)

These were NOT in `$QM_FACTORY_TASKS` or `$QM_AI_TASKS` and therefore survived a plain Factory_OFF, allowing them to restart the factory:
- `QM_StrategyFarm_FactoryWatchdog_15min`
- `QM_StrategyFarm_FactoryON_AtLogon`
- `QM_StrategyFarm_ReconcileOrphans_Hourly`

Factory_ON re-enables all three.

---

## Deliverable 2: TestWindow scripts

**`TestWindow_OFF.ps1`**: Full quiesce wrapper (Rule 12, OPERATING_RULES_2026-07-03)
1. Calls Factory_OFF (disables all tasks, kills workers/terminals/run_smoke wrappers, writes flag)
2. Kills residual pythonw run_pump_task.py spawns from in-flight run_smoke fires
3. Prints quiesce verification checklist (6 checks: flag, codex_parallel, daemons, terminals, run_smoke, pump spawns)

**`TestWindow_ON.ps1`**: Full restore wrapper
1. Calls Factory_ON (removes flag, restores codex_parallel, re-enables all tasks, spawns workers, runs farmctl repair)
2. Prints restore verification checklist (3 checks: flag absent, codex_parallel != 0, daemons > 0)

---

## Deliverable 3: Agent-lane robustness

### 3a: Heartbeat file
`run_agent_orchestration_task.py`: Immediately after lock acquisition (slot start), writes  
`D:/QM/strategy_farm/state/lane_<agent>_heartbeat.json` → `{"agent", "slot", "pid", "at"}`

### 3b: Router disabled-lane guard
`agent_router.py`:
- New constant: `LANE_HEARTBEAT_STALE_HOURS = 2`
- New function `_lane_heartbeat_stale(root, agent_id)` → True only if heartbeat FILE EXISTS and is > 2h old (missing file = no-skip)
- `_eligible_agents()` accepts `root` parameter; skips agents with stale heartbeats
- `release_stale_in_progress()` extended: besides 6h unconditional release, also releases tasks where age > 2h AND lane heartbeat is stale (moves back to TODO for re-routing to a live lane)

### 3c: Tests verified
Existing agent_router tests all pass (pre-existing unrelated failure: `test_run_once_does_not_replenish_generic_research`). Missing heartbeat = don't skip (covers fresh deployments and factory-OFF states).

---

## Deliverable 4: Gemini G: path fix

**Root cause:** `QM_StrategyFarm_GeminiOrchestration_15min` runs as SYSTEM. Google Drive (`G:`) is mounted per-user; SYSTEM has no G: mount → PermissionError strands tasks IN_PROGRESS. Rule 13, OPERATING_RULES_2026-07-03.

**Fix:** `run_agent_orchestration_task.py build_prompt()`:
- Detects `agent == "gemini"`
- Skips G: drive vault paths (Operating State, Routing Contract, OPEN ITEMS)
- Claude/Codex still receive G: paths (they have G: access in their execution contexts)

**Note:** `agy` also has `G:\My Drive` in `command_for()` extra_dirs — this is for file ACCESS within agy's workspace tool. This existing G: reference in command_for is guarded by `if extra.exists()` so it self-silences when G: is unavailable (no code change needed there).

---

## Syntax verification

**Python (py_compile):**
```
run_pump_task.py          PASS
sweep_enqueue_built_eas.py PASS
run_agent_orchestration_task.py PASS
agent_router.py           PASS
farmctl.py (import check) PASS
```

**PowerShell (Parser::ParseFile):**
```
Factory_OFF.ps1           PASS
Factory_ON.ps1            PASS
factory_watchdog.ps1      PASS
reconcile_orphans.ps1     PASS
TestWindow_OFF.ps1        PASS
TestWindow_ON.ps1         PASS
run_smoke.ps1             PASS
```

**Test suite:** 271 passed (1 pre-existing unrelated failure), 0 new failures.

---

## Hard-rule compliance

- T_Live never killed: all process filters use `notmatch 'T_Live'`
- Terminal-process selection is path-anchored: `\mt5\T<n>\` patterns
- No factory restart triggered (flag + script changes take effect on next manual OFF/ON)
- OWNER retains full control: flag only set/removed by Factory_OFF.ps1 / Factory_ON.ps1 / TestWindow scripts
