# QM5_10180 tv-fut-ema-rsi-pull

## Strategy Logic

Trades a futures-style trend pullback continuation on the chart timeframe. EMA(100) defines trend direction on the last closed bar. Long entries require close > EMA(100) and RSI(14) <= 35. Short entries require close < EMA(100) and RSI(14) >= 65. Entries use market orders with ATR bracket exits fixed at entry. One position per magic is enforced by the framework.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 100 | >0 | Trend EMA period |
| `strategy_rsi_period` | 14 | >0 | Pullback RSI period |
| `strategy_rsi_long_level` | 35.0 | 0-100 | Long pullback threshold |
| `strategy_rsi_short_level` | 65.0 | 0-100 | Short pullback threshold |
| `strategy_atr_period` | 14 | >0 | ATR period for bracket exits |
| `strategy_atr_sl_mult` | 1.5 | >0 | Stop distance in ATR |
| `strategy_atr_tp_mult` | 2.0 | >0 | Target distance in ATR |
| `strategy_max_hold_bars` | 32 | >=1 | Time stop when session filter is disabled |
| `strategy_session_enabled` | false | bool | Optional configured-session gate |
| `strategy_session_start_h` | 0 | 0-23 | Session start hour, broker time |
| `strategy_session_end_h` | 23 | 0-23 | Session end hour, broker time |

## Symbol Universe

Primary DWX port: `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `XAUUSD.DWX`. The card states `GER40.DWX`; this build uses `GDAXI.DWX` because it is the matrix-valid DAX symbol. `SP500.DWX` is noted by the card as optional and backtest-only, but is not part of the primary registered basket.

## Timeframe

Primary build timeframe is M15, selected from the card phrase "M15 or M30" by taking the first listed timeframe. The EA uses the chart timeframe for all indicators and the 32-bar time stop.

## Expected Behaviour

The card estimates about 140 trades per year per symbol. Typical holding time is intraday to 32 bars unless SL or TP is hit first. The strategy should prefer directional markets with pullbacks into trend and can struggle in choppy sideways regimes.

## Source Citation

TradingView script `All-Day Futures Trend Pullback (EMA + RSI) [v5]`, author `bradenstrock`, published 2026-03-05. Source ID: `30591366-874b-5bee-b47c-da2fca20b728`.

## Risk Model

Backtests use V5 fixed risk via `RISK_FIXED = 1000.0` and `RISK_PERCENT = 0.0`. Live deployment uses `RISK_PERCENT = 0.5` with `RISK_FIXED = 0.0` in live setfiles after pipeline approval.
