# QM5_1207_bbadx-index-skew

## Build Scope

- Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1207_bbadx-index-skew.md`
- V5 EA: `framework/EAs/QM5_1207_bbadx-index-skew/QM5_1207_bbadx-index-skew.mq5`
- Build-only implementation. No backtests or pipeline phases are included.

## Mechanical Mapping

- Entry: on D1 new bar, evaluates the prior closed D1 close against Bollinger Bands `SMA(20) +/- 2.0 stdev`; trades only when `ADX(14) >= 20`.
- Long: prior D1 close above upper band.
- Short: prior D1 close below lower band.
- Exit: close long when prior D1 close returns below Bollinger middle/SMA; close short when prior D1 close returns above middle/SMA.
- Timeout: close after `strategy_max_hold_bars`, default 5 D1 bars.
- Stop: opposite Bollinger band at entry, capped to no more than `3.0 * ATR(20)` distance from entry.
- Warmup: requires at least 60 D1 bars.

## Symbols and Slots

| Slot | Symbol | Purpose |
| --- | --- | --- |
| 0 | `GER40.DWX` | Primary DAX proxy |
| 1 | `UK100.DWX` | Optional source-index test route |
| 2 | `JPN225.DWX` | Optional source-index test route |

## Notes

- Full holidays naturally produce no new D1 bar. No external holiday or early-close calendar is called by the EA.
- News/Friday-close behavior uses V5 framework defaults.
- `SP500.DWX` is not part of this card implementation.
