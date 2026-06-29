# QM5_12809 Jet Fuel Breakout Q02 Enqueue - 2026-06-30

Scope: branch `agents/board-advisor`; no `T_Live`, deploy manifest, portfolio
gate, or AutoTrading changes.

## Built

- `QM5_12809_eia-jetfuel-brk`
  - Edge: `XTIUSD.DWX` D1 long-only WTI jet-fuel summer demand breakout.
  - Source lineage: official EIA jet-fuel refinery-output, consumption, and
    production analysis.
  - Runtime data: Darwinex MT5 OHLC, broker calendar, spread, ATR, and SMA only.
    No EIA API/feed, refinery feed, airline data, inventory feed, futures curve,
    ML, grid, or martingale.
  - Logic: May 15-August 31 only; buy D1 breakouts above the prior 15-bar high
    when the prior close is above SMA(100); exit on date-window expiry, SMA
    trend break, 8-bar Donchian exit low break, 45-day max hold, ATR stop, or
    framework Friday close.
  - Dedup: not a duplicate of `QM5_12567` RSI commodity pullback, `QM5_12576`
    broad WTI season map, RBOB/gasoline sleeves, distillate winter sleeve, WPSR,
    refinery-maintenance, hurricane, OPEC, roll, weekday, month, ratio, XNG, or
    XAU/XAG sleeves.
  - Risk: RISK_FIXED backtest setfile, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Validation

- ID registry: `12809,eia-jetfuel-brk,EIA-JETFUEL-SEASON-2026,active,Development,2026-06-30`.
- Magic registry: `12809,eia-jetfuel-brk,0,XTIUSD.DWX,128090000,2026-06-30,Development,active`.
- Card lint: PASS, no ML hits, no missing sections.
- SPEC validation: PASS, 1 PASS / 0 FAIL.
- Symbol scope: PASS, `SINGLE_SYMBOL_OK`, `n_violations=0`.
- Strict compile:
  - command: `python tools\strategy_farm\compile_ea.py --ea-label QM5_12809_eia-jetfuel-brk --force --json`
  - result: PASS, `COMPILED`
  - errors: 0
  - warnings: 0
  - ex5: `framework/EAs/QM5_12809_eia-jetfuel-brk/QM5_12809_eia-jetfuel-brk.ex5`
- EA-local build check:
  - command: `powershell -ExecutionPolicy Bypass -File framework\scripts\build_check.ps1 -EALabel QM5_12809_eia-jetfuel-brk -Strict -SkipCompile`
  - result: PASS
  - failures: 0
  - warnings: 16 existing shared framework include advisories, no EA-local
    failure.

## Farm Queue

- Queue database: `D:/QM/strategy_farm/state/farm_state.sqlite`.
- Queue state before enqueue: `pending=5571`; below the hard queue ceiling of
  10000.
- Q02 work item: `bf861753-130b-49d4-9f0b-3e6623d8f515`
- Symbol/timeframe: `XTIUSD.DWX` D1
- Setfile: `framework/EAs/QM5_12809_eia-jetfuel-brk/sets/QM5_12809_eia-jetfuel-brk_XTIUSD.DWX_D1_backtest.set`
- Status after enqueue: `pending`.

## Notes

- Full backtest results were not run or read in this build turn.
- Backtest CPU was not consumed beyond enqueueing the paced Q02 work item.
