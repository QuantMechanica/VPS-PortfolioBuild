# Quota Governor + Factory Recovery Runbook (2026-06-21)

Operational reference for the automated quota governance and the factory
launch-fault recovery procedure introduced 2026-06-21. Filesystem is the source of
truth; this doc mirrors it for fresh-session/rebuild reproducibility.

## 1. Quota Governor (automated weekly-pace throttle)

**OWNER policy:** Codex AND Claude token spend should track their weekly limits.
Buffer present -> build/programme EAs (both agents). Buffer tight -> focus &
prioritise so at minimum the MT5 backtests keep running.

- **Script:** `tools/strategy_farm/quota_governor.py`
- **Task:** `QM_StrategyFarm_QuotaGovernor` — SYSTEM, every 15 min.
  Reinstall/rebuild: `tools/strategy_farm/install_quota_governor_scheduled_task.ps1`
- **Reads:** `D:/QM/strategy_farm/state/quota_snapshot.json` (written by
  `quota_pull.py`, the 5-min QM_StrategyFarm_QuotaPull task). Skips if >25 min stale.
- **Writes:** `D:/QM/reports/state/quota_governor_state.json` + `quota_governor.log`.

**Control law (per agent):** `pace_diff = weekly_used% - weekly_elapsed%` (elapsed
measured from the precise weekly reset minus 7d).
- `used% < 15` (FLOOR) -> never throttle (ample buffer).
- `used% >= 90` (HARD CEILING) -> always throttle.
- engage throttle at `pace_diff >= +12` pts; release at `pace_diff <= +4` pts (hysteresis).

**Levers (existing, honored by farmctl.py / agent_router.py):**
- Codex -> `D:/QM/strategy_farm/CODEX_LOW_TOKENS.flag` -> mass builds=0, G0
  mass-review=off, research=off, `MAX_PARALLEL_CODEX=1` (one slot left for the
  priority repair/orchestration).
- Claude -> `D:/QM/strategy_farm/CLAUDE_DISABLED.flag` -> headless claude builds=0,
  `MAX_PARALLEL_CLAUDE=0`. The interactive operator Claude session is a separate
  process and is NOT affected.
- **Lane boost:** when one agent is throttled and the other has buffer, the governor
  boosts the builder's parallelism (`state/claude_parallel.txt` /
  `state/codex_parallel.txt` -> 10) so it absorbs the backlog; restores to baseline
  (claude 3 / codex 6) after the boost cycle.
- **Ownership-tracked:** the governor only removes a flag it set itself (recorded in
  quota_governor_state.json), so a manually/externally set flag is never silently cleared.
- **MT5 terminal workers are NEVER throttled** -> backtests always run (cost $0 tokens).

**Note on Claude builds:** the headless Claude build lane runs **Sonnet** (separate,
cheap weekly limit), so Claude can build the card backlog while Codex rests WITHOUT
burning the Opus weekly budget. Documented in farmctl.py (`_cl_par`, "programmier du"
boost pattern, OWNER 2026-06-09).

## 2. Tester-cache purge (disk) — cadence tightened

- **Script:** `tools/strategy_farm/tester_cache_purge.ps1` (no-op SKIP while D: >= 80GB;
  when it acts: stop factory -> clear `T*\Tester\bases` + `Agent-*` -> restart).
- **Cadence: 20 min** (was 60 min). A fast cache-burn during high NO_HISTORY
  retry-churn (~2GB/min) dropped D: from ~150GB to 30GB inside one hour on 2026-06-21,
  below the 40GB worker circuit-breaker, which the hourly purge missed between runs.
  Reinstall/rebuild: `tools/strategy_farm/install_tester_cache_purge_scheduled_task.ps1`
  (default now `-EveryMinutes 20`).
- Safety layers: worker circuit-breaker pauses+purges at <40GB; factory_watchdog at <40GB.

## 3. NO_HISTORY root cause (do NOT re-import history)

`run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS` is a **first-attempt cold `.hcc`
tester-cache build transient**, NOT a coverage/card/symbol/EA defect. Proven
2026-06-20: every symbol+from_date has both real verdicts AND NO_HISTORY; ~96% of
NO_HISTORY is attempt0 and self-heals on retry; all factory symbols are the 37 in
`framework/registry/dwx_symbol_matrix.csv`. The sweep re-enqueue (MAX_INFRA_ATTEMPTS)
absorbs it today. Proper fix routed to Codex ops_issue **6e26c61f** (priority 90):
worker immediate single-retry on NO_HISTORY in `terminal_worker._run_claimed_item`
before INFRA classification. Brief: `D:/QM/reports/state/no_history_root_cause_2026-06-20.md`.

## 4. Factory recovery — launch-fault wedge (use OFF/ON, NOT reboot)

**Symptom:** terminal64 instant-exits (~0.06s, logged as `launch_fault` by the worker
guard), MT5 logs on affected terminals go stale, real-verdict rate collapses — while the
host is otherwise idle (CPU low, RAM free, handles fine, session Active, workers alive,
1/terminal). Triggered 2026-06-21 by the emergency purge force-killing all terminal64.

**A worker-only restart (FactoryWatchdog respawn) does NOT clear it.** The fix that works:

```
# admin in the visible session (session 1). Factory_OFF ends in Read-Host -> pipe Enter.
echo '' | powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\Factory_OFF.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\Factory_ON.ps1 -NoPause
```

`Factory_OFF.ps1` disables ALL factory+AI tasks + force-kills every worker+terminal64
(brief 0-process state frees session/process resources). `Factory_ON.ps1 -NoPause`
re-enables tasks, clean-slate respawns 10 workers in the session, runs `farmctl repair`
once (clears stale active claims), triggers the pump. Verified 2026-06-21: all 10
terminals fresh <2min, launch_fault 99%->13%, real ~22/5min.

**Do NOT VPS-reboot for this** — a reboot stops T_Live live trading (OWNER+Claude
authority). OFF/ON is the first-line recovery; reboot only if OFF/ON fails.

## 5. Quick health one-liners

```powershell
$PY = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe"
& $PY C:\QM\repo\tools\strategy_farm\quota_pull.py            # Codex+Claude 5h/week %
Get-Content D:\QM\reports\state\quota_governor.log -Tail 4    # governor decisions
Get-Content D:\QM\reports\state\tester_cache_purge.log -Tail 3
```

Related: `docs/ops/SCHEDULED_TASKS_INVENTORY.md`,
`project_qm_d_drive_tester_cache_2026-06-02` (memory),
`feedback_codex_quota_throttle_2026-06-21` (memory),
`project_qm_no_history_root_cause_2026-06-20` (memory).
