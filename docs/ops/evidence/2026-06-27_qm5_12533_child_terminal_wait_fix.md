# QM5_12533 Child-Terminal Wait Fix - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling 66-pair FX
cointegration scan. It documents only two strict-threshold FX cointegration survivors:

- `QM5_12533` EURJPY/GBPJPY D1 market-neutral cointegration basket.
- `QM5_12532` AUDUSD/NZDUSD D1 market-neutral cointegration basket.

There is no documented third unbuilt FX cointegration pair from that scan. `QM5_12532`
already has logical-basket Q02 `PASS`, so this action continues the `QM5_12533` Q02 unblock.

## Fix

The active `QM5_12533` Q02 work item exposed a runner-side CPU ceiling:

- Work item: `e9e4e602-77e2-441f-8709-a13ec0285496`.
- Logical symbol: `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`.
- Host: `EURJPY.DWX`, `D1`; tester currency `JPY`.
- The work-item log reached `run_smoke.stage=terminal_exit` while the corresponding
  T1 `metatester64.exe` process from the same test remained active and consuming CPU.
- A later retry of the same work item started another T1 terminal/metatester run, creating
  overlapping tester load.

Root cause: `framework/scripts/run_smoke.ps1` used `Start-Process`'s returned process as the
wait target. On MT5 this can be a launcher/stub process; the real spawned `terminal64.exe`
is already discovered separately by `Wait-TerminalSpawn`. The runner now waits on the spawned
child terminal process and uses that child terminal's exit code. On timeout it stops the child
terminal first and then the launcher process if they differ.

Regression test added:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-RunSmokeWaitsForChildTerminal.ps1
```

## Current Queue State

No duplicate Q02 work item was inserted. The existing logical-basket Q02 row remains active:

| Field | Value |
|---|---|
| Work item | `e9e4e602-77e2-441f-8709-a13ec0285496` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Status at check | `active` |
| Claimed by | `T1` |
| Last checked | `2026-06-26T23:16:43+00:00` DB update; local inspection `2026-06-27T01:18+02:00` |

Backtest CPU was already saturated by the overlapping tester processes, so no new manual
backtest was launched.

## Validation

- `powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-RunSmokeWaitsForChildTerminal.ps1`: `PASS`.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-TerminalSpawnWatchdog.ps1`: `PASS`.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-RunSmokeRealTicksReportEvidence.ps1`: `PASS`.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-RunSmokeOnInitTradeScope.ps1`: `PASS`.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-RunSmokeNoHistoryScope.ps1`: `PASS`.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12533_edgelab-eurjpy-gbpjpy-cointegration -SkipCompile`: `PASS`, 0 failures, 16 existing framework include advisory warnings.
