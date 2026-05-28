# QM5_10132 tv-mtf-body-bos

## Strategy Logic
Trades a closed-bar body break with break-of-structure confirmation. A long signal requires the last closed candle close to be above the prior candle body high, above the highest high of the prior 20 bars, and above a higher-timeframe SMA(50) regime filter. A short signal is the symmetric close below prior body low, below the lowest low of the prior 20 bars, and below the higher-timeframe SMA(50).

Positions exit through the broker 2R target, stop loss, framework Friday close, or a strategy exit when a long closes back below the prior candle body low or a short closes back above the prior candle body high.

## Parameters
| Input | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_structure_lookback` | 20 | `>=1` | Prior-bar high/low lookback for BOS confirmation. |
| `strategy_atr_period` | 14 | `>=1` | ATR period for stop placement. |
| `strategy_htf_sma_period` | 50 | `>=1` | SMA period on the 4x higher timeframe. |
| `strategy_atr_stop_mult` | 1.5 | `>0` | ATR distance used for the entry-relative stop candidate. |
| `strategy_signal_atr_buffer` | 0.25 | `>=0` | ATR buffer beyond the signal candle high/low. |
| `strategy_take_profit_rr` | 2.0 | `>0` | Fixed reward/risk target. |
| `strategy_max_spread_stop_fraction` | 0.10 | `>=0` | Reject entry if spread exceeds this fraction of stop distance. |

## Symbol Universe
Designed for the approved P2 basket: `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`, `NDX.DWX`. These are all present in `framework/registry/dwx_symbol_matrix.csv`.

## Timeframe
Primary timeframe is `M15`. Robustness setfiles are also generated for `H1`. The higher-timeframe filter uses the 4x timeframe: `M15 -> H1`, `H1 -> H4`.

## Expected Behaviour
The card estimates roughly 60-120 trades per year per symbol after the MTF filter, with an expected center near 80 trades per year per symbol. It is a breakout and market-structure strategy that prefers directional continuation after candle-body expansion.

## Source Citation
JK, "Body Close Outside Prior Body - BOS Filtered (MTF)", TradingView, accessed 2026-05-19, URL: https://www.tradingview.com/script/OcVKeqc2-Body-Close-Outside-Prior-Body-BOS-Filtered-MTF-by-JK/.

## Risk Model
Backtests use fixed risk with `RISK_FIXED = 1000` and `RISK_PERCENT = 0`. Live promotion uses percent risk through the deployment manifest, conventionally `RISK_PERCENT = 0.5`, after the full pipeline and OWNER-signed manifest.
