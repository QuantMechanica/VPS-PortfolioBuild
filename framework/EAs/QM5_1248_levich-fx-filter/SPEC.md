# QM5_1248 levich-fx-filter

## Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1248_levich-fx-filter.md`
- Local copy: `docs/strategy_card.md`
- Status: APPROVED / G0

## Framework Mapping

- No-trade: framework kill-switch, DXZ news gate, Friday close, symbol-slot guard, H1/H4/D1 chart enforcement, Sunday 23:00 to Friday 18:00 broker-time window, and median-spread filter.
- Entry: closed-bar Levich-Thomas percent-filter breakout on FX majors. Default threshold is 0.5 percent from the maintained reference close range.
- Trade management: initial hard stop at `2.0 * ATR(timeframe, 48)`.
- Close: opposite percent-filter condition closes the current position. With reversal safety enabled as close-first behavior, the opposite side can enter on the next eligible bar.

## Symbols And Slots

| Slot | Symbol |
|---:|---|
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | USDCHF.DWX |

## Validation

- Build-only scope. No backtests or pipeline phases run from this build handoff.
- Required checks: `compile_one.ps1 -Strict`, `build_check.ps1 -Strict`, and registry validation.
