# QM5_12585 RBOB Pullback Q02 Enqueue - 2026-06-26

Scope: branch `agents/board-advisor`; no `T_Live`, deploy manifest, portfolio gate, or AutoTrading changes.

## Built

- `QM5_12585_eia-rbob-pullback`
  - Edge: `XTIUSD.DWX` D1 long-only gasoline crack-spread pullback continuation.
  - Source lineage: official EIA gasoline crack-spread / summer driving-season source.
  - Runtime data: Darwinex MT5 OHLC only; no EIA API/feed, RBOB feed, refinery feed, futures curve, ML, grid, or martingale.
  - Logic: March-August only; buy after three consecutive lower D1 closes while close remains above SMA(100), with pullback depth between 0.35 and 2.25 ATR(20); exit on bounce-high recovery, SMA trend break, date-window end, 14-day max hold, or framework Friday close.
  - Dedup: not a duplicate of `QM5_12576` monthly WTI season map, `QM5_12579` WPSR aftershock, `QM5_12581` RBOB channel breakout/breakdown, `QM5_12583` distillate winter breakout, or `QM5_12567` RSI commodity pullback.
  - Risk: RISK_FIXED backtest setfile, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Validation

- ID registry: `12585,eia-rbob-pullback,EIA-RBOB-PULLBACK-2026,active,Development,2026-06-26`.
- Magic registry: `12585,eia-rbob-pullback,0,XTIUSD.DWX,125850000,2026-06-26,Development,active`.
- DWX matrix: `XTIUSD.DWX` present.
- Strict compile:
  - command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12585_eia-rbob-pullback/QM5_12585_eia-rbob-pullback.mq5 -Strict`
  - result: PASS
  - errors: 0
  - warnings: 0
  - ex5: `framework/EAs/QM5_12585_eia-rbob-pullback/QM5_12585_eia-rbob-pullback.ex5`
- EA-local build check:
  - command: `framework/scripts/build_check.ps1 QM5_12585_eia-rbob-pullback -Strict -SkipCompile`
  - result: PASS
  - failures: 0
  - warnings: 16 existing framework include advisories, no EA-local failure.

## Farm Queue

- Queue database: `D:/QM/strategy_farm/state/farm_state.sqlite`.
- Queue state before enqueue: `pending=897`, `active=7`; below the hard backpressure limit of 10000 pending work items.
- Q02 work item: `79b87368-fa81-41ed-9b46-b5d40b0e6671`
- Symbol/timeframe: `XTIUSD.DWX` D1
- Setfile: `framework/EAs/QM5_12585_eia-rbob-pullback/sets/QM5_12585_eia-rbob-pullback_XTIUSD.DWX_D1_backtest.set`
- Status after enqueue: `pending`.

## Notes

- Full backtest results were not read or acted on in this build turn.
- A background pump committed the EA artifacts in `248f75193213028d0ea4be9e5d2d881fa5e9571a` while validation was in progress.
