# EIA WTI Season Q02 Enqueue - 2026-06-26

Scope: branch `agents/board-advisor`; no T_Live, deploy manifest, portfolio gate, or AutoTrading changes.

## Built

- `QM5_12576_eia-wti-season`
  - Edge: `XTIUSD.DWX` D1 structural WTI product-demand seasonality.
  - Source lineage: official EIA gasoline and distillate/heating-oil seasonality material.
  - Runtime data: Darwinex MT5 OHLC only; no EIA API/feed, futures curve, inventory feed, ML, grid, or martingale.
  - Logic: monthly rebalance, long May-Aug/Dec-Jan when close > SMA(84) and ROC(21) > 0, short Sep-Oct when close < SMA(84) and ROC(21) < 0, flat otherwise.
  - Risk: RISK_FIXED backtest setfile, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Validation

- Dedup check: no exact slug or strategy-id duplicate; fuzzy sibling only to `eia-xng-season`.
- DWX matrix: `XTIUSD.DWX` present.
- Strict compile:
  - command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12576_eia-wti-season/QM5_12576_eia-wti-season.mq5 -Strict`
  - result: PASS
  - errors: 0
  - warnings: 0
  - ex5: `framework/EAs/QM5_12576_eia-wti-season/QM5_12576_eia-wti-season.ex5`
- EA-local build check:
  - command: `framework/scripts/build_check.ps1 QM5_12576_eia-wti-season -Strict -SkipCompile`
  - result: PASS
  - failures: 0
  - warnings: 16 existing framework include advisories, no EA-local failure.

## Farm Queue

- Q02 parent task: `a29da1e8-ca7b-487f-ab3e-0075f32c4e2d`
- Q02 work item: `8c452014-56ce-40e5-8388-bc5d9460f756`
- Symbol/timeframe: `XTIUSD.DWX` D1
- Setfile: `framework/EAs/QM5_12576_eia-wti-season/sets/QM5_12576_eia-wti-season_XTIUSD.DWX_D1_backtest.set`
- Status after enqueue check: `active`, claimed by `T3`.

## Notes

- Full `validate_registries.py` still fails on many unrelated pre-existing registry rows; the new `12576/eia-wti-season/XTIUSD.DWX` magic row was not among the reported issues.
- No backtest result was read or acted on in this build turn.
