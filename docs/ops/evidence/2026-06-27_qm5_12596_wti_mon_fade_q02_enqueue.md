# QM5_12596 WTI Monday Fade Q02 Enqueue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, deploy manifest, portfolio gate, or AutoTrading changes.

## Built

- `QM5_12596_wti-mon-fade`
  - Edge: `XTIUSD.DWX` D1 weekday-seasonality sleeve.
  - Source lineage: peer-reviewed crude-oil day-of-week seasonality research, Quayyum et al., "Seasonality in crude oil returns", Soft Computing 24, 7857-7873 (2020), DOI https://doi.org/10.1007/s00500-019-04329-0.
  - Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed, inventory feed, CFTC data, futures curve, CSV, API, ML, grid, or martingale.
  - Logic: sell XTIUSD.DWX on the broker-calendar Monday D1 bar; flatten on the next D1 bar or one-calendar-day stale guard; ATR hard stop.
  - Dedup: not `QM5_12567` RSI commodity pullback, not `QM5_12563` Turtle/Donchian trend, not `QM5_12576` monthly WTI seasonality, not WPSR/refinery/hurricane family, not `QM5_12594` medium-term WTI reversal, and not XAU/XAG or XTI/XNG basket ratio logic.
  - Risk: RISK_FIXED backtest setfile, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Validation

- ID registry: `12596,wti-mon-fade,QUAY-WTI-DOW-2019,active,Development,2026-06-27`.
- Magic registry: `12596,wti-mon-fade,0,XTIUSD.DWX,125960000,2026-06-27,Development,active`.
- DWX matrix: `XTIUSD.DWX` present.
- SPEC validation:
  - command: `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12596_wti-mon-fade`
  - result: PASS.
- Strict compile:
  - command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12596_wti-mon-fade/QM5_12596_wti-mon-fade.mq5 -Strict`
  - result: PASS
  - errors: 0
  - warnings: 0
  - log: `C:/QM/repo/framework/build/compile/20260627_032222/QM5_12596_wti-mon-fade.compile.log`
- EA-local build check:
  - command: `framework/scripts/build_check.ps1 QM5_12596_wti-mon-fade -Strict -SkipCompile`
  - result: PASS
  - failures: 0
  - warnings: 16 existing framework include advisories, no EA-local failure.
  - report: `D:/QM/reports/framework/21/build_check_20260627_032306.json`

## Farm Queue

- Farm build task: `3c76300c-3a7b-4500-ae4a-3fc6f67cf4e7`
- Build result artifact: `artifacts/qm5_12596_build_result.json`
- Q02 work item: `3d55440d-0a2d-4473-9cab-c865926ef651`
- Symbol/timeframe: `XTIUSD.DWX` D1
- Setfile: `framework/EAs/QM5_12596_wti-mon-fade/sets/QM5_12596_wti-mon-fade_XTIUSD.DWX_D1_backtest.set`
- Status after enqueue check: `pending`.

## Notes

- Full backtest results were not read or acted on in this build turn.
- The paced farm owns Q02 dispatch; no manual MT5 run was launched.
