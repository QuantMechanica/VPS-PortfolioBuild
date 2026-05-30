# QM5_1227_neely-fx-channel

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1227_neely-fx-channel.md`
- Source: Neely, Weller, and Ulrich, "The Adaptive Markets Hypothesis: Evidence from the Foreign Exchange Market" (FRB St. Louis Working Paper No. 2006-046B / JFQA version).

## Framework Alignment

- No-Trade: blocks unsupported symbols, non-D1 charts, mismatched symbol slot, invalid inputs, insufficient warmup, and excessive spread.
- Entry: on each confirmed D1 close, computes the prior 60-day high/low channel. If flat, buys when close is above the prior 60-day high and sells when close is below the prior 60-day low.
- Management: no trailing, partial close, or break-even logic; the card specifies only the initial ATR safety stop.
- Exit: closes long when confirmed D1 close is below SMA(60), closes short when confirmed D1 close is above SMA(60), or exits after 90 D1 bars.

## Symbols and Slots

| Slot | Symbol |
| --- | --- |
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | USDCHF.DWX |

## Parameters

- `strategy_signal_tf=PERIOD_D1`
- `strategy_channel_lookback=60`
- `strategy_exit_sma_period=60`
- `strategy_atr_period_d1=20`
- `strategy_atr_sl_mult=2.50`
- `strategy_max_hold_bars=90`
- `strategy_min_bars=120`
- `strategy_max_active_symbols=3`

## Notes

- Entry uses the prior channel (`shift + 1` through `shift + lookback`) so the signal bar does not define its own breakout threshold.
- Basket exposure is capped at three simultaneously active 1227 positions across the four approved FX symbols.
- No backtests or pipeline phases are part of this build.
