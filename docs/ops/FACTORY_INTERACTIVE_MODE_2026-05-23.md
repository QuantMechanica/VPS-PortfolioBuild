# Factory Interactive (Visible) Mode — 2026-05-23

## Why

OWNER directive 2026-05-23: the MT5 factory must no longer run headless
in session-0. terminal64 windows have to be visible on the RDP desktop
so the operator can see what is running.

## Design

### Old (session-0 / headless)

`QM_StrategyFarm_TerminalWorkers_AT_STARTUP` ran as `SYSTEM` in session 0
on every boot and invoked `start_terminal_workers.py`. The 10 daemons
inherited session 0; `terminal64.exe` / `metatester64.exe` spawned by
them were invisible on the interactive desktop. The factory ran 24/7
regardless of whether anyone was logged in via RDP.

### New (interactive / visible)

- `QM_StrategyFarm_TerminalWorkers_AT_STARTUP` is **permanently disabled**.
- `Factory_ON.ps1` spawns the 10 daemons directly inside the calling
  session via `& python start_terminal_workers.py --dedupe`. The daemons
  inherit the operator's RDP session; every `terminal64.exe` they later
  spawn shows as a window on the desktop.
- `Factory_OFF.ps1` no longer touches the (already-disabled)
  `TerminalWorkers_AT_STARTUP` task.

`QM_StrategyFarm_Pump_5min`, `_Tick_5min`, and `_Repair_Hourly` keep
running as `SYSTEM` scheduled tasks — they only dispatch / repair and
do not spawn terminals, so the headless context is fine for them.

## Operational tradeoff

- The factory runs while the operator's RDP session is alive.
- **Disconnect** (closing the RDP window) is **OK** — the session stays
  active in the background and the factory keeps running.
- **Explicit logoff** kills the session and the factory dies with it.
- After a VPS reboot the factory does not auto-start — log in via RDP
  and click **QM Factory ON** on the desktop.

## How to verify after starting

- `Factory_ON.ps1` prints `worker daemons up : N / 10 (in session X: N)`.
  All 10 should be in your session (not session 0).
- On the desktop you will see `terminal64.exe` windows appear and
  disappear as backtests cycle.
- `metatester64.exe` is the actual backtest process (CPU-bound);
  `terminal64.exe` is just its controller.

## To revert (if 24/7 headless is ever wanted again)

- `Enable-ScheduledTask -TaskName QM_StrategyFarm_TerminalWorkers_AT_STARTUP`
- Restore the original `Factory_ON.ps1` / `Factory_OFF.ps1` lines that
  triggered the task and listed it in the enable/disable arrays.
