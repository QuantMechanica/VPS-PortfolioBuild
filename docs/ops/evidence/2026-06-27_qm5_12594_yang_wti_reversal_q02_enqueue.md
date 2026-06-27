# QM5_12594 Yang WTI Reversal Q02 Enqueue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, deploy manifest, portfolio gate, or AutoTrading changes.

## Built

- `QM5_12594_yang-wti-reversal`
  - Edge: `XTIUSD.DWX` D1 weekly medium-term commodity reversal.
  - Source lineage: Yang, Goncu, and Pantelous, "Momentum and Reversal in Commodity Futures", SSRN.
  - Runtime data: Darwinex MT5 OHLC only; no futures curve, CFTC data, inventory feed, analyst forecast, CSV, API, ML, grid, or martingale.
  - Logic: on Monday D1 bars, fade a fixed 63-day WTI return extreme only after 5-day reversal confirmation and ATR/SMA stretch; exit at SMA(63) mean reversion or 15-day max hold.
  - Dedup: not `QM5_12567` RSI pullback, not `QM5_12563` Turtle/Donchian trend, not XAU/XAG or XTI/XNG ratio basket, and not the EIA WTI calendar/WPSR/hurricane/refinery family.
  - Risk: RISK_FIXED backtest setfile, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Validation

- ID registry: `12594,yang-wti-reversal,05abad87-420d-5a51-8a9b-3c35ad795385,active,Development,2026-06-27`.
- Magic registry: `12594,yang-wti-reversal,0,XTIUSD.DWX,125940000,2026-06-27,Development,active`.
- DWX matrix: `XTIUSD.DWX` present.
- SPEC validation:
  - command: `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12594_yang-wti-reversal`
  - result: PASS.
- Strict compile:
  - command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12594_yang-wti-reversal/QM5_12594_yang-wti-reversal.mq5 -Strict`
  - result: PASS
  - errors: 0
  - warnings: 0
  - log: `C:/QM/repo/framework/build/compile/20260627_004005/QM5_12594_yang-wti-reversal.compile.log`
- EA-local build check:
  - command: `framework/scripts/build_check.ps1 QM5_12594_yang-wti-reversal -Strict -SkipCompile`
  - result: PASS
  - failures: 0
  - warnings: 16 existing framework include advisories, no EA-local failure.
  - report: `D:/QM/reports/framework/21/build_check_20260627_004019.json`

## Farm Queue

- Farm build task: `9ad19442-9958-4acf-9ef7-5da1bb9dec9a`
- Build result artifact: `artifacts/qm5_12594_build_result.json`
- Q02 work item: `b0e0704c-3e8a-43ae-83ff-a69136a008c8`
- Symbol/timeframe: `XTIUSD.DWX` D1
- Setfile: `framework/EAs/QM5_12594_yang-wti-reversal/sets/QM5_12594_yang-wti-reversal_XTIUSD.DWX_D1_backtest.set`
- Status after enqueue check: `pending`.

## Notes

- Full backtest results were not read or acted on in this build turn.
- The paced farm owns Q02 dispatch; no manual MT5 run was launched.
