# QM5_12618 EURUSD Dual TSMOM Q02 Enqueue - 2026-06-30

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or live-manifest edits.

## Built

- `QM5_12618_tsmom-dual-confirm-3m-12m-eurusd`
  - Edge: `EURUSD.DWX` D1 time-series momentum with 63-bar and 252-bar return
    signs required to agree.
  - Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12618_tsmom-dual-confirm-3m-12m-eurusd.md`.
  - Runtime data: Darwinex MT5 OHLC/spread only; no ML, banned indicators,
    grids, martingale, or external feed.
  - Logic: monthly rebalance; long on dual positive momentum, short on dual
    negative momentum, flatten on disagreement; ATR(14) x 3 initial stop.
  - Risk: RISK_FIXED backtest setfile, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Validation

- Farm build task: `609f90d9-f907-41b9-8c02-da0510b28f41`, claimed by
  `codex:agents/board-advisor`.
- Magic registry: `12618,tsmom-dual-confirm-3m-12m-eurusd,0,EURUSD.DWX,126180000,2026-06-30,Development,active`.
- SPEC gate: `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12618_tsmom-dual-confirm-3m-12m-eurusd`
  -> `PASS`.
- Build check:
  - command: `framework/scripts/build_check.ps1 -EALabel QM5_12618_tsmom-dual-confirm-3m-12m-eurusd`
  - result: `PASS`
  - compile result: `PASS`, 0 errors, 0 warnings
  - report: `D:/QM/reports/framework/21/build_check_20260630_000751.json`
  - compile log: `framework/build/compile/20260630_000751/QM5_12618_tsmom-dual-confirm-3m-12m-eurusd.compile.log`
- Setfile:
  `framework/EAs/QM5_12618_tsmom-dual-confirm-3m-12m-eurusd/sets/QM5_12618_tsmom-dual-confirm-3m-12m-eurusd_EURUSD.DWX_D1_backtest.set`.

## Smoke

One build-smoke attempt was launched on `EURUSD.DWX` D1 for 2024 with
`-MinTrades 1`. It hit the 15-minute command timeout and was not rerun under
the CPU-ceiling constraint.

Partial smoke artifacts:
`D:/QM/reports/smoke/QM5_12618/20260630_000818`.

Recorded farm result: `deferred_p2_smoke` with
`smoke_skipped_reason=build_smoke_timeout_cpu_ceiling_after_15m`.

## Farm Queue

- Build result artifact:
  `D:/QM/strategy_farm/artifacts/builds/609f90d9-f907-41b9-8c02-da0510b28f41.json`.
- `record-build` status: `done`.
- Q02 work item: `eb4abcd4-4372-4329-a406-c02fcac4a1f1`.
- Symbol/timeframe: `EURUSD.DWX` D1.
- Q02 status after enqueue check: `pending`.

No manual portfolio gate, live manifest, `T_Live`, or AutoTrading changes were
made.
