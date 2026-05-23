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
- `QM_StrategyFarm_Repair_Hourly` is **permanently disabled** (added
  2026-05-23 after VPS crash investigation, see "Crash-gap closure" below).
- `Factory_ON.ps1` spawns the 10 daemons directly inside the calling
  session via `& python start_terminal_workers.py --dedupe`. The daemons
  inherit the operator's RDP session; every `terminal64.exe` they later
  spawn shows as a window on the desktop. Factory_ON then runs
  `farmctl.py repair` ONCE synchronously in the same session (one-shot
  replacement for the recurring Repair_Hourly task).
- `Factory_OFF.ps1` only disables `Pump_5min` + `Tick_5min`; the two
  permanently-disabled tasks (TerminalWorkers, Repair) are not touched.

`QM_StrategyFarm_Pump_5min` and `_Tick_5min` keep running as `SYSTEM`
scheduled tasks while Factory_ON is active — they only dispatch /
tick and never spawn terminals, so the headless context is fine for
them. Factory_OFF disables them again so they don't fire between
sessions.

## Crash-gap closure (2026-05-23)

A VPS crash mid-Factory_ON-session left `Repair_Hourly` in the
`Enabled` state (Windows preserves last task state across reboots).
On reboot, before OWNER logged in via RDP, Repair_Hourly fired as
`SYSTEM`, called `farmctl.py repair`, which auto-spawned the 10
missing daemons — in session 0, the same headless violation the
TerminalWorkers_AT_STARTUP retirement was supposed to eliminate.

Fix: Repair_Hourly is now permanently disabled, joining
TerminalWorkers_AT_STARTUP. Factory_ON invokes the repair logic
inline as a one-shot. Result: NO scheduled task can spawn worker
daemons; only an explicit human-clicked Factory_ON does, and only
in the user RDP session.

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
- `Enable-ScheduledTask -TaskName QM_StrategyFarm_Repair_Hourly`
- Restore the original `Factory_ON.ps1` / `Factory_OFF.ps1` lines that
  triggered the tasks and listed them in the enable/disable arrays.
- Remove the inline `farmctl.py repair` call from Factory_ON.ps1.
