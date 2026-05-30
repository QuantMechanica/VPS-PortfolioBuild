# QM5_1163 unger-dax-bb-multiday

## Card Mapping

- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1163_unger-dax-bb-multiday.md`
- Status: `APPROVED`
- Universe: `GDAXI.DWX` primary, `NDX.DWX` and `WS30.DWX` robustness ports.
- Timeframe: H1 baseline, H4 sweep via `strategy_timeframe_minutes`.

## Strategy Logic

- Entry long: completed strategy timeframe close crosses above Bollinger upper band.
- Entry short: completed strategy timeframe close crosses below Bollinger lower band.
- Bollinger defaults: period `40`, deviation `2.0`.
- Stop: `2.5 * ATR(14)`.
- Take profit: optional `5.0 * ATR(14)`.
- Trailing: optional ATR trailing stop with default `2.5 * ATR(14)`.
- Signal exit: close long below Bollinger middle band, close short above Bollinger middle band.
- Time exit: close after `40` completed strategy timeframe bars.
- Filters: supported symbol/slot only, H1/H4 only, spread cap, entry window, Friday late-entry cutoff, V5 news and Friday-close controls.

## Framework Alignment

- No-trade: symbol/slot, timeframe, parameter, spread and framework news/Friday filters.
- Entry: `Strategy_EntrySignal`.
- Management: `Strategy_ManageOpenPosition` optional ATR trailing.
- Close: `Strategy_ExitSignal` middle-band and max-hold exits.
- Magic: `QM_FrameworkMagic()` and setfile `qm_magic_slot_offset`.

## Validation Scope

Build only. No backtests or pipeline phases are part of this artifact.
