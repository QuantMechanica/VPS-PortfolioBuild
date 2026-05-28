# QM5_1215_papailias-ma-trail

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1215_papailias-ma-trail.md`
- Source concept: Papailias-Thomakos long-only moving-average rule with dynamic ATR trailing threshold.

## Framework Alignment

- No-Trade: blocks unsupported symbols, non-D1 charts, wrong symbol slot, invalid inputs, thin history, disabled symbols, and excessive spread.
- Entry: opens one long position on the next D1 bar when the previous D1 close is above SMA(Close, N).
- Management: keeps a catastrophic stop at entry minus configured ATR multiple; no pyramiding.
- Exit: closes when previous D1 close is below the dynamic threshold based on highest closed D1 price since entry, or below SMA(Close, N).

## Symbols and Slots

| Slot | Symbol | Note |
| --- | --- | --- |
| 0 | SP500.DWX | P2 target, T6 broker-routability caveat |
| 1 | NDX.DWX | P2 target |
| 2 | GER40.DWX | P2 target |
| 3 | EURUSD.DWX | P2 target |
| 4 | GBPUSD.DWX | P2 target |

## Parameters

- `strategy_ma_period_d1=200`
- `strategy_atr_period_d1=20`
- `strategy_trail_atr_mult=2.0`
- `strategy_cat_stop_atr_mult=3.0`
- `strategy_min_history_d1_bars=220`

## Notes

- P3 sweep candidates from the card are represented by optimizer-ready inputs: MA length `{100,150,200}` and trail ATR multiple `{1.5,2.0,2.5}`.
- The EA uses only native MT5/DWX price series and framework risk/news/Friday-close controls.
- No backtests or pipeline phases are part of this build.
