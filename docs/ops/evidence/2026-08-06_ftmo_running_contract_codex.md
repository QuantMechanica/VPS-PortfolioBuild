# FTMO expected-state contract flip - Codex evidence

Date: 2026-08-06

Router task: `7a75c2c6-3865-4065-b701-5477e2669fb9`

Verdict: `REVIEW_REQUIRED`. The source and runtime evidence support the OWNER-
ratified `RUNNING` recovery contract; reviewer approval remains separate.

## Deployed-reality precheck

The FTMO terminal remained PID 10400, session 1, created at 06:25:16 local,
using executable `C:/Program Files/FTMO Global Markets MT5 Terminal/terminal64.exe`.
Its data directory reports account 1514165262, server `FTMO-Demo`, profile
`Default`, and Experts Enabled=1.

The old launcher verifier targeted retired account 1513845506 and the 12-leg
Round25 profile. The saved profile currently contains `chart01.chr` through
`chart07.chr` plus `order.wnd`: AccountMonitor, five attached instrumentation
sleeves, and a blank XAUUSD/H1 chart. The sixth staged XAUUSD/H4 sleeve is not
attached. Recovery now pins this exact deployed state rather than the retired
book or an inferred sixth attachment.

The new read-only verifier returned:

`VERIFIED: FTMO account 1514165262 / Default = AccountMonitor + five SHA-pinned instrumentation sleeves + blank XAUUSD chart`

## Runtime verification

`T_Live_Watchdog.ps1 -NoReboot` completed at `2026-08-06T06:43:17Z` with:

- status `healthy`;
- expected DXZ/FTMO states `RUNNING` / `RUNNING`;
- FTMO profile expected/observed `Default` / `Default`;
- FTMO running PID 10400 in session 1;
- DXZ running PID 9872 in session 1;
- Experts Enabled=1 on both terminals;
- recovery-task contract ready;
- session supervisor ready;
- zero errors and zero actions.

Both terminal PIDs were identical before and after the watchdog run.

The headless invocation of `FTMO_ON.ps1` then returned exit 0 with
`FTMO terminal already running - no action`. FTMO remained the single PID
10400 with the same creation time. No terminal was started, stopped, or
restarted.

## Focused verification

- Windows PowerShell parser: PASS for the new verifier and all three changed
  recovery scripts.
- Read-only FTMO contract verifier: PASS.
- Live uptime, silent-failure, alarm-mailer, and morning-safety tests: 37 PASS.
- ASCII/Windows PowerShell 5.1 safety tests are included in that set.
- `install_live_uptime_tasks.ps1` was not run or modified; runtime contract
  verification reports no drift.

No T_Live write, AutoTrading toggle, live-process intervention, or pipeline
verdict occurred.
