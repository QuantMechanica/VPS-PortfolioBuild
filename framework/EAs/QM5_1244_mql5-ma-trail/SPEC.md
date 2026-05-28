# QM5_1244 mql5-ma-trail

## Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1244_mql5-ma-trail.md`
- Local copy: `docs/strategy_card.md`
- Status: APPROVED / G0

## Framework Mapping

- No-trade: framework kill-switch, news gate, Friday-close handling, plus entry blocking inside the Friday pre-close window.
- Entry: H1 close-cross through SMA(50), with SMA(50) versus SMA(200) trend confirmation, minimum SMA gap of 0.3 ATR(14), minimum 260 H1 bars, and 20-day same-hour median-spread filter.
- Trade management: initial stop is 2.0 ATR(14), take-profit is 2.5R, and after +1.0R the stop trails to SMA(50) minus/plus 0.5 ATR(14) for long/short positions.
- Close: H1 close back through SMA(50), max hold of 96 H1 bars, or framework Friday close.

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
