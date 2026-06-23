# Factory Watch-Loop + Recovery Runbook (2026-06-23)

Operational runbook for the autonomous strategy-farm watch loop and the wedge/disk
recovery procedures. Written down so the procedure survives the session (the `/loop`
itself is ephemeral — session-only — this file is its durable specification). Companion
to `docs/ops/QUOTA_GOVERNOR_AND_FACTORY_RECOVERY_2026-06-21.md` and `decisions/DL-076…md`.

## The watch loop — what each tick checks

Self-paced (`/loop`, dynamic mode), ~20-30 min cadence in steady state, tighter (~15 min)
during a recovery watch. Each tick:

1. **Health = verdict throughput, NOT terminal count.** Query real verdicts in the last
   5 min: `SELECT COUNT(*) FROM work_items WHERE status='done' AND verdict IS NOT NULL
   AND verdict!='INFRA_FAIL' AND updated_at>datetime('now','-5 minutes')`. A healthy
   factory produces hundreds/5min. **`Get-Process terminal64` count is misleading** — Q02
   prescreen runs are sub-second, so a point-sample reads 0 even at full production
   (mirrors `project_qm_mt5_queue_starvation`). Never conclude "wedge" from t64 alone.
2. **Disk D: free.** Stable/healthy is >~80GB (purge no-op zone). Watch the trend, not the
   absolute. Free-fall toward <15GB = danger (sqlite corruption at <4GB).
3. **INFRA trend.** Elevated INFRA right after a full purge is the expected cold-cache
   tail (all `.hcc` wiped → rebuild). Self-heals as caches warm, as long as real verdicts
   stay high. Not actionable unless it coincides with the wedge signature below.
4. **Survivors / portfolio frontier.** New PASS/PASS_SOFT/PASS_LOWFREQ at Q04, Q05+ inflow,
   distinct Q08 FAIL_SOFT sleeves (the portfolio-admission pool, target ~8-12).

## TRUE wedge signature (the only thing that warrants OFF/ON)

ALL of: **t64=0 sustained** (4 samples / 8s) **AND real-verdicts ≈ 0 in 5 min** **AND
fresh `launch_fault` in worker logs** (`ran_seconds` 0.05-0.09, `D:\QM\strategy_farm\logs\
terminal_worker_*.log`) **AND disk + RAM both free**. If real verdicts are still flowing,
it is NOT a wedge — do nothing (let cold-cache self-heal).

## Wedge / launch_fault recovery (sanctioned — never tscon/kill/reboot)

The factory runs in OWNER's interactive console session (autologon). Scripts self-elevate;
when already admin they run inline (so `Factory_OFF.ps1`'s trailing `Read-Host` needs a
piped Enter).

```powershell
# 1. (storm only) stop the re-wedge vector: the purge force-kills running terminals,
#    which re-leaks the OS resources (window-station/handles) that cause launch_fault.
Disable-ScheduledTask -TaskName 'QM_StrategyFarm_TesterCachePurge'
# 2. full teardown — the brief 0-process state releases the leaked resources
'' | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\Factory_OFF.ps1
Start-Sleep -Seconds 10      # settle
# 3. clean respawn (re-enables factory tasks, spawns 7 daemons, runs farmctl repair)
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\Factory_ON.ps1 -NoPause
# 4. verify recovery via VERDICT THROUGHPUT (not t64). When disk is healthy + factory
#    stable, RE-ENABLE the purge: Enable-ScheduledTask -TaskName 'QM_StrategyFarm_TesterCachePurge'
```
A worker-only restart does NOT clear a true wedge. Do NOT VPS-reboot (T_Live live trading)
unless OFF/ON fails repeatedly. The gentle purge (verify-loop kill + settle) is safe once
the storm is over — re-enabling it at 55GB reclaimed 55→452GB with no re-wedge.

## ★ The Q04 re-enqueue disk-storm lesson (2026-06-23)

**Q04 re-enqueue costs ~4× a Q02 re-run** — each Q04 item = 3 walk-forward folds + (DL-076)
a pooled pass = 3-4 COLD backtests. Bulk re-enqueuing 100/batch (×200) rebuilt ~600 cold
`.hcc` caches at once → D: 333GB→41GB → purge force-killed terminals → leaked-resource
launch_fault wedge. **RULE: re-enqueue Q04 only in TINY batches (10-15), watching disk
headroom.** Most bulk re-enqueued items INFRA'd (wasted) rather than producing clean
verdicts. Q04 is NOT covered by `sweep_enqueue_built_eas` (that meters Q02/Q03/Q08).

## DL-076 soft-pass recovery technique (re-grade, no backtest)

Q04 FAILs whose stored `aggregate.json` `folds[].pf_net` meet the PASS_SOFT profile
(≥2/3 folds >1.0, mean >1.10, min ≥0.80) can be **re-graded for free** — fold pf_net is
already under the DL-073 cost model, so re-grading == re-running, deterministically. Set
`verdict='PASS_SOFT'` on the latest Q04 row per (ea,sym); the cascade promotes them to Q05
(it dedups on (ea_id,symbol,setfile_path) and promotes `updated_at ASC LIMIT 10`/cycle, so
back-date `updated_at` to push a fresh re-grade to the front). The real upper gates
(Q05/Q06/Q08) then validate with live backtests. NOTE: forward Q04 flow no longer needs
this — the PASS_SOFT live-path bug is fixed (DL-076 B), so re-grade is a one-time backlog
recovery only.

## Quota: weekly-limit referencing + reset (OWNER directive 2026-06-23)

Spend governance keys off the **WEEKLY** window (`quota_governor.py`, weekly limits +
hysteresis), not the 5h window. `quota_pull.py` summary now prints **both** windows with
their **own** reset time — previously it showed the weekly % next to the 5h reset, which
read as a wrong "weekly reset" (repeatedly misread). The governor auto-RELEASES an
owned throttle flag when the weekly resets (used_pct drops → want_throttle false). When
reporting status, always cite the **weekly reset** for the weekly %, never the 5h reset.

## Operational hygiene

- Diagnostic/one-off scripts go to `D:\QM\reports\state\tmp_*.py`, **never** the repo
  working tree — any dirty file blocks ALL builds (`project_qm_dirty_guard_build_deadlock`).
- Always run `farmctl.py` from `C:/QM/repo` (worktrees lag main → false health readings).
- Headless python: `C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe`.
- PowerShell mangles inline `python -c` with quotes/backslashes — write a temp file instead.
