# QM5_10350 et-sp-adx15

## Strategy Logic
The EA trades a completed-bar M30 channel breakout on index CFDs. It only opens a new position when ADX(14) on M30 is below 25. A long entry is triggered when the last completed bar breaks above the highest high of the prior 15 completed bars. A short entry is triggered when the last completed bar breaks below the lowest low of the prior 15 completed bars.

Long exits use a break below the lowest low of the previous 5 completed bars. Short exits use a break above the highest high of the previous 5 completed bars. The protective stop is maintained at the same 5-bar opposite channel.

## Parameters
| Input | Default | Meaning |
|---|---:|---|
| strategy_tf | PERIOD_M30 | Base timeframe. |
| strategy_adx_period | 14 | ADX period. |
| strategy_adx_max | 25.0 | Maximum ADX allowed for new entries. |
| strategy_entry_channel | 15 | Entry channel lookback in completed bars. |
| strategy_exit_channel | 5 | Exit/stop channel lookback in completed bars. |
| strategy_atr_period | 14 | ATR period for stop cap. |
| strategy_max_stop_atr_mult | 3.0 | Maximum stop distance as ATR multiple. |
| strategy_min_stop_spreads | 4.0 | Minimum stop distance as current-spread multiple. |
| strategy_max_spread_mult | 2.5 | Maximum current spread versus rolling median spread. |
| strategy_spread_window | 31 | Rolling spread samples retained by the EA. |
| strategy_session_start_h | 1 | Broker-hour liquid-session start. |
| strategy_session_end_h | 23 | Broker-hour liquid-session end. |

## Symbol Universe
Registered P2 basket: SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX. Card aliases GER40.DWX and STOXX50.DWX are not present in the matrix; GDAXI.DWX and UK100.DWX are used as available DWX index ports.

## Timeframe
M30 only.

## Expected Behaviour
The card estimates about 75 trades per year per symbol before pipeline filtering. The strategy should prefer low-ADX pre-breakout regimes and can suffer false breakouts and fast reversals.

## Source Citation
Elite Trader thread "SP trend following System", author `acrary`, 2002-10-14.

## Risk Model
Backtests use RISK_FIXED = 1000. Live setfiles use RISK_PERCENT after approval per V5 risk conventions.
