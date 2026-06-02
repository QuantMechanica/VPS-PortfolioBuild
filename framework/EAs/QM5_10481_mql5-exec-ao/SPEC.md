# QM5_10481 MQL5 Executor AO Momentum Bend

## Strategy logic

The EA evaluates only closed bars for entry. Awesome Oscillator is computed as SMA(5, median price) minus SMA(34, median price). A long entry fires when the most recent closed AO value is at least `strategy_min_ao_atr_frac * ATR(14)` away from zero and forms an upward bend: AO[1] > AO[2] and AO[2] < AO[3]. A short entry is the mirror: AO[1] < AO[2] and AO[2] > AO[3].

Open positions are closed by broker SL/TP, by an opposite AO bend, or by the 24-bar time stop. There is no pyramiding, grid, martingale, averaging, ML, or adaptive parameter logic.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ao_fast_period` | 5 | > 0 | Fast SMA period for AO median-price calculation. |
| `strategy_ao_slow_period` | 34 | > fast | Slow SMA period for AO median-price calculation. |
| `strategy_atr_period` | 14 | > 0 | ATR period for the AO indent normalization and stop distance. |
| `strategy_min_ao_atr_frac` | 0.10 | >= 0 | Minimum absolute AO distance from zero as a fraction of ATR. |
| `strategy_atr_sl_mult` | 1.50 | > 0 | Stop loss distance in ATR multiples. |
| `strategy_take_profit_r` | 2.00 | > 0 | Take profit as R multiple from entry to SL. |
| `strategy_time_stop_bars` | 24 | >= 0 | Close after this many chart bars if SL/TP/opposite signal has not closed the trade. |

## Symbol universe

The card targets liquid DWX FX majors, XAUUSD, oil, and liquid index CFDs. Because the approved card's R3 row states AO, ATR, and OHLC are available on DWX symbols without a single-symbol restriction, the build registers every symbol present in `framework/registry/dwx_symbol_matrix.csv`, including SP500.DWX as backtest-only.

## Timeframe

Primary timeframe is M15. The card also allows H1, but baseline P2 setfiles are generated on M15.

## Expected behaviour

The card estimates roughly 100 trades per year per symbol. Typical holding time is intraday to 24 bars, bounded by the M15 time stop. The strategy is a momentum-turn / oscillator-bend system and should be most active in oscillating momentum regimes.

## Source citation

Approved source: MQL5 CodeBase, "Executor AO - expert for MetaTrader 5", idea by Alex, code by Vladimir Karputov / barabashkakvn, published 2018-12-18.

## Risk model

Backtests use `RISK_FIXED=1000` USD per trade. Live deployment uses `RISK_PERCENT=0.5` via signed manifest and live setfiles after pipeline approval. The EA exposes both risk inputs through the V5 framework.

## Build notes

The card says the exact source minimum AO indent can be confirmed during build. This implementation uses the literal V5 baseline stated in the card: minimum AO indent equals `0.10 * ATR(14)`.
