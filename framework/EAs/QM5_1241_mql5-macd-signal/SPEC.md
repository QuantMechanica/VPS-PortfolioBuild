# QM5_1241 mql5-macd-signal

## Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1241_mql5-macd-signal.md`
- Local copy: `docs/strategy_card.md`
- Status: APPROVED / G0

## Framework Mapping

- No-trade: framework kill-switch, news gate, Friday-close handling, plus H1 chart enforcement.
- Entry: H1 closed-bar MACD main/signal cross, MACD late-entry guard, EMA(200) trend filter, ATR median floor, and median-spread filter.
- Trade management: initial 2.0 ATR stop and 2.0R take-profit are set on entry; stop moves to breakeven after +1.0R.
- Close: opposite MACD cross, EMA(50) close filter, max hold of 96 H1 bars, or framework Friday close.

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
