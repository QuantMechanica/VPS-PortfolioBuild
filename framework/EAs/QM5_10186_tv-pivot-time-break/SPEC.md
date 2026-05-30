# QM5_10186 tv-pivot-time-break

## Strategy Logic

The EA trades confirmed pivot breakouts on the chart timeframe. A pivot high is confirmed after `strategy_pivot_right` closed bars to its right and `strategy_pivot_left` bars to its left. The latest confirmed pivot high becomes the long breakout level; the latest confirmed pivot low becomes the short breakout level.

Long entry requires the prior close to cross above the active pivot high and close above EMA(100). Short entry requires the prior close to cross below the active pivot low and close below EMA(100). Entries are market orders on the next bar with ATR stop and fixed RR take profit. Opposite exposure for this EA magic is closed before a reversal entry is allowed.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pivot_left` | 5 | `>=1` | Bars to the left of a pivot candidate. |
| `strategy_pivot_right` | 5 | `>=1` | Bars to the right required for pivot confirmation. |
| `strategy_ma_period` | 100 | `>=1` | EMA trend filter period. |
| `strategy_atr_period` | 14 | `>=1` | ATR period for stop distance. |
| `strategy_atr_sl_mult` | 1.5 | `>0` | ATR stop multiplier. |
| `strategy_rr_mult` | 2.0 | `>0` | Take-profit multiple of stop risk. |
| `strategy_max_spread_stop_frac` | 0.15 | `>0` | Maximum spread as a fraction of stop distance. |
| `strategy_index_start_hour/minute` | 16:30 | broker time | Index/metals session start. |
| `strategy_index_end_hour/minute` | 23:00 | broker time | Index/metals session end. |
| `strategy_fx_start_hour/minute` | 15:00 | broker time | FX London/New York overlap start. |
| `strategy_fx_end_hour/minute` | 19:00 | broker time | FX London/New York overlap end. |

## Symbol Universe

Registered symbols are `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `XAUUSD.DWX`, and `EURUSD.DWX`. The approved card listed `GER40.DWX`; the verified DWX matrix symbol for DAX is `GDAXI.DWX`, so the build uses `GDAXI.DWX`.

## Timeframe

Primary build timeframe is H1. The card permits M15 or H1; this build uses H1 for Q01 smoke and P2 setfiles.

## Expected Behaviour

The approved card estimates about 100 trades per year per symbol. The EA is a session-filtered breakout strategy and should be more active in directional or expanding-volatility regimes. Positions close by SL, TP, framework Friday close, or session end.

## Source Citation

TradingView script `Breakouts With Timefilter Strategy [LuciTech]`, author `TradesLuci`, published 2025-03-01. Source ID: `30591366-874b-5bee-b47c-da2fca20b728`.

## Risk Model

Backtests use `RISK_FIXED = 1000.0` and `RISK_PERCENT = 0.0`. Live deployment uses `RISK_PERCENT` through a signed manifest after pipeline approval; the EA keeps both user-visible inputs per HR4.
