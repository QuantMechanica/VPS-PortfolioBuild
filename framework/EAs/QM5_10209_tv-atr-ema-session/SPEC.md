# QM5_10209 tv-atr-ema-session

## Strategy Logic

Trades closed-bar EMA(50) crosses during the configured 09:00-17:30 broker-time session. Long entries require price to cross above EMA(50) while ATR(25), normalized to points, is below the long threshold. Short entries require price to cross below EMA(50) while ATR(25), normalized to points, is above the short threshold.

Positions exit through broker TP/SL or at session end.

## Parameters

| Input | Default | Meaning |
|---|---:|---|
| `strategy_signal_tf` | `PERIOD_CURRENT` | Signal timeframe; smoke/setfiles run M15 unless overridden. |
| `strategy_atr_period` | `25` | ATR lookback. |
| `strategy_ema_period` | `50` | EMA lookback. |
| `strategy_long_atr_points_max` | `20.0` | Longs allowed only below this ATR-in-points threshold. |
| `strategy_short_atr_points_min` | `25.0` | Shorts allowed only above this ATR-in-points threshold. |
| `strategy_sl_atr_mult` | `10.0` | Stop distance in ATR multiples. |
| `strategy_tp_atr_mult` | `5.0` | Take-profit distance in ATR multiples. |
| `strategy_session_start_hour/min` | `09:00` | Session start in broker time. |
| `strategy_session_end_hour/min` | `17:30` | Session end in broker time. |
| `strategy_max_daily_trades` | `3` | Maximum entries per broker day. |
| `strategy_spread_stop_fraction` | `0.10` | Max spread as a fraction of ATR stop distance. |

## Symbol Universe

Approved card symbols are `GER40.DWX`, `NDX.DWX`, `WS30.DWX`, `XAUUSD.DWX`, and `EURUSD.DWX`. `GER40.DWX` is not in the DWX matrix, so the build registers canonical DAX `GDAXI.DWX` plus the remaining card symbols.

## Timeframe

The source card specifies M15 or M30. This build uses `PERIOD_CURRENT` by default and generates M15 and M30 setfiles.

## Expected Behaviour

The card expects about 120 trades per year per symbol. The EA is intraday momentum with volatility-regime switching, fixed ATR exits, and session-end flat behaviour.

## Source Citation

TradingView script `ATR EMA Strategy`, author `whitebear28`, published 2026-04-13. Card source ID: `30591366-874b-5bee-b47c-da2fca20b728`.

## Risk Model

Backtests use `RISK_FIXED = 1000.0` and `RISK_PERCENT = 0.0`. Live promotion uses separate manifest/setfile risk with `RISK_PERCENT = 0.5` after the full pipeline and OWNER approval.
