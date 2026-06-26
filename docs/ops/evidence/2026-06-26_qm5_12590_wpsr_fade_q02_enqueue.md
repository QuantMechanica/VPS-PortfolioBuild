# QM5_12590 WTI WPSR Fade Q02 Enqueue - 2026-06-26

Scope: branch `agents/board-advisor`; no `T_Live`, deploy manifest, portfolio gate, or AutoTrading changes.

## Built

- `QM5_12590_eia-wti-wpsr-fade`
  - Edge: `XTIUSD.DWX` D1 post-EIA WPSR exhaustion fade.
  - Source lineage: official EIA Weekly Petroleum Status Report and release schedule.
  - Runtime data: Darwinex MT5 OHLC only; no EIA API/feed, inventory surprise feed, analyst forecast, futures curve, ML, grid, or martingale.
  - Logic: after Wednesday/Thursday WPSR D1 event bars, fade only wide directional outer-tail closes stretched from SMA(50); exit on SMA mean reversion or 4-day max hold.
  - Dedup: not `QM5_12579` WPSR continuation, not `QM5_12576` monthly WTI seasonality, not RBOB/distillate seasonal sleeves, and not `QM5_12567` RSI commodity pullback.
  - Risk: RISK_FIXED backtest setfile, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Validation

- ID registry: `12590,eia-wti-wpsr-fade,EIA-WTI-WPSR-FADE-2026,active,Development,2026-06-26`.
- Magic registry: `12590,eia-wti-wpsr-fade,0,XTIUSD.DWX,125900000,2026-06-26,Development,active`.
- DWX matrix: `XTIUSD.DWX` present.
- Strict compile:
  - command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12590_eia-wti-wpsr-fade/QM5_12590_eia-wti-wpsr-fade.mq5 -Strict`
  - result: PASS
  - errors: 0
  - warnings: 0
  - log: `C:/QM/repo/framework/build/compile/20260626_215058/QM5_12590_eia-wti-wpsr-fade.compile.log`
- EA-local build check:
  - command: `framework/scripts/build_check.ps1 QM5_12590_eia-wti-wpsr-fade -Strict -SkipCompile`
  - result: PASS
  - failures: 0
  - warnings: 16 existing framework include advisories, no EA-local failure.
  - report: `D:/QM/reports/framework/21/build_check_20260626_215111.json`

## Farm Queue

- Farm build task: `f000e153-95a6-4489-be06-de819a0e27fb`
- Build result artifact: `artifacts/qm5_12590_build_result.json`
- Q02 work item: `ab4fa4ae-c0b3-459a-9f4f-937bacac8e24`
- Symbol/timeframe: `XTIUSD.DWX` D1
- Setfile: `framework/EAs/QM5_12590_eia-wti-wpsr-fade/sets/QM5_12590_eia-wti-wpsr-fade_XTIUSD.DWX_D1_backtest.set`
- Status after enqueue check: `pending`.

## Notes

- Full backtest results were not read or acted on in this build turn.
- The paced farm owns Q02 dispatch; no manual MT5 run was launched.
