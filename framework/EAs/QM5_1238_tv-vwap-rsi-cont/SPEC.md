# QM5_1238 tv-vwap-rsi-cont

## Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1238_tv-vwap-rsi-cont.md`
- Local copy: `docs/strategy_card.md`
- Status: APPROVED / G0

## Framework Mapping

- No-trade: framework kill-switch, news gate, Friday-close handling, plus entry blocking inside the Friday pre-close window.
- Entry: M15 session VWAP continuation. Long requires close above VWAP, prior-bar VWAP pullback touch, bullish closed bar, RSI(14) 50-70, London 07:00-17:00, minimum session range, and median-spread filter. Short mirrors below VWAP with RSI 30-50.
- Trade management: initial ATR stop and 1.5R take-profit are set on entry; stop moves to breakeven after +1.0R.
- Close: strategy exit on M15 close crossing back through session VWAP, max hold of 16 M15 bars, or framework Friday close.

## Symbols And Slots

| Slot | Symbol |
|---:|---|
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | AUDUSD.DWX |
| 4 | USDCAD.DWX |
| 5 | NZDUSD.DWX |
| 6 | XAUUSD.DWX |
| 7 | XTIUSD.DWX |
| 8 | NDX.DWX |
| 9 | WS30.DWX |
| 10 | GDAXI.DWX |
| 11 | UK100.DWX |

## Validation

- Build-only scope. No backtests or pipeline phases run from this build handoff.
- Required checks: `compile_one.ps1 -Strict`, `build_check.ps1 -Strict`, and registry validation.
