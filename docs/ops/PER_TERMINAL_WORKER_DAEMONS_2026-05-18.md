# Per-Terminal Worker Daemons

Date: 2026-05-18

Option C replaces pump-cron MT5 work-item dispatch with five long-running
workers, one for each terminal slot T1-T5.

## Architecture

- Worker: `tools/strategy_farm/terminal_worker.py`
- Starter: `tools/strategy_farm/start_terminal_workers.ps1`
- Scheduled-task installer: `tools/strategy_farm/install_terminal_workers_scheduled_task.ps1`
- PID registry: `D:/QM/strategy_farm/state/worker_pids.json`
- Logs: `D:/QM/strategy_farm/logs/terminal_worker_T1.log` through `terminal_worker_T5.log`

Each worker loops on a two-second poll. It atomically claims one pending
`work_items` row with `BEGIN IMMEDIATE`, respecting active per-symbol locks and
P2 DWX history-window availability, then runs `run_smoke.ps1` pinned to its
terminal. The worker blocks until the smoke process exits or the 30-minute
timeout expires, classifies the item from `summary.json`, releases the terminal,
and immediately polls again.

Pump-cron still runs research, build, G0, review, repair, cascade and legacy
non-work-item logic. Its direct `dispatch_work_items()` call is disabled because
the daemon fleet owns work-item dispatch.

## Start

Manual start or heartbeat restart:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\start_terminal_workers.ps1
```

Install the at-startup plus five-minute heartbeat scheduled task:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\install_terminal_workers_scheduled_task.ps1
```

The installer registers `QM_StrategyFarm_TerminalWorkers_AT_STARTUP` as SYSTEM.
It is intentionally a helper script; creating the task is an OWNER action.

## Stop

Stop workers by PID from the registry:

```powershell
$pids = Get-Content -Raw D:\QM\strategy_farm\state\worker_pids.json | ConvertFrom-Json
$pids.PSObject.Properties.Value | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
```

The next scheduled heartbeat will restart missing workers unless the scheduled
task is disabled.

## Troubleshooting

- Check `worker_pids.json` first. Missing or dead PIDs are recreated by
  `start_terminal_workers.ps1`.
- Check `terminal_worker_<T>.log` for claim and run-result JSON lines.
- A worker restart releases only stale active claims for its own terminal when
  the recorded smoke PID is gone.
- If a work item remains pending, check for another active row with the same
  symbol or missing P2 history-range coverage in
  `framework/registry/dwx_symbol_history_ranges.csv`.
- If all workers are alive but no work starts, inspect
  `D:/QM/strategy_farm/state/farm_state.sqlite` for active rows and recent
  `run_smoke.ps1` PIDs.
