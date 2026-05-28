# QM5_1214_vidal-holiday-effect

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1214_vidal-holiday-effect.md`
- Source concept: Vidal-Garcia holiday effect on major equity indices.

## Framework Alignment

- No-Trade: blocks unsupported symbols, non-H1 charts, wrong symbol slot, invalid inputs, thin history, and excessive spread.
- Entry: long-only H1 entry on deterministic exchange-holiday windows.
- Management: no trailing or discretionary management beyond the initial ATR stop.
- Exit: closes at configured broker exit hour on the holiday window's final full trading day, with a fallback time exit on the next session.

## Symbols and Slots

| Slot | Symbol | Leg |
| --- | --- | --- |
| 0 | SP500.DWX | U.S. pre-holiday, backtest/T6 caveat |
| 1 | NDX.DWX | U.S. pre-holiday |
| 2 | WS30.DWX | U.S. pre-holiday |
| 3 | GER40.DWX | German/Euronext post-holiday |

## Parameters

- `strategy_atr_period_h1=20`
- `strategy_atr_sl_mult=1.3`
- `strategy_entry_hour_broker=10`
- `strategy_exit_hour_broker=21`
- `strategy_us_close_only=false`
- `strategy_eu_prepost_two_day=false`

## Notes

- Holiday calendars are static deterministic tables embedded in the EA for 2021-2035.
- `SP500.DWX` remains a live-promotion caveat route; later T6 work needs parallel validation on `NDX.DWX` or `WS30.DWX`.
- No backtests or pipeline phases are part of this build.
