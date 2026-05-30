# QM5_10010 rw-fx-ar10-rev Spec

## Strategy Logic
The EA trades short-horizon mean reversion on M10 FX bars. On each completed bar it computes a fixed AR(10) forecast from the last ten bar returns:

`pred_ret = intercept + sum(ar_lag_n * return_lag_n)`

A long entry is allowed when `pred_ret >= 0.15 * ATR(14) / close` and the latest absolute return is above the configured realized-volatility percentile. A short entry is allowed when the same threshold is crossed negatively. The EA exits on an opposite cached forecast signal, after six M10 bars, or at the configured New York session close proxy.

## Parameters
| Input | Default | Range | Meaning |
|---|---:|---|---|
| `qm_ea_id` | 10010 | fixed | V5 EA identifier. |
| `qm_magic_slot_offset` | 0 | 0-9999 | Symbol slot resolved through the magic registry. |
| `RISK_PERCENT` | 0.0 | >= 0 | Live percent risk input; off in backtests. |
| `RISK_FIXED` | 1000.0 | >= 0 | Backtest fixed risk per trade. |
| `PORTFOLIO_WEIGHT` | 1.0 | 0-1 | Portfolio sleeve weight. |
| `qm_news_temporal` | `QM_NEWS_TEMPORAL_PRE30_POST30` | enum | High-impact news pause mode. |
| `qm_news_compliance` | `QM_NEWS_COMPLIANCE_DXZ` | enum | Prop-firm compliance overlay. |
| `strategy_atr_period` | 14 | >= 1 | ATR period on chart timeframe. |
| `strategy_entry_threshold_atr` | 0.15 | > 0 | Forecast threshold as ATR fraction. |
| `strategy_sl_atr_mult` | 1.20 | > 0 | Initial stop distance in ATR multiples. |
| `strategy_tp_atr_mult` | 0.0 | >= 0 | Optional ATR take-profit; 0 disables baseline TP. |
| `strategy_vol_lookback_bars` | 60 | >= 2 | Realized-volatility percentile lookback. |
| `strategy_vol_percentile_min` | 50.0 | 0-100 | Minimum volatility percentile. |
| `strategy_max_spread_atr_fraction` | 0.20 | > 0 | Maximum spread as a fraction of ATR. |
| `strategy_max_hold_bars` | 6 | >= 1 | Time exit in bars. |
| `strategy_ny_close_hour_broker` | 23 | 0-23 | Broker-hour session close proxy. |
| `strategy_ny_close_minute_broker` | 50 | 0-59 | Broker-minute session close proxy. |
| `strategy_ar_intercept` | 0.0 | fixed coefficient | AR intercept. |
| `strategy_ar_lag1` ... `strategy_ar_lag10` | lag1 -0.10, lag2 -0.05, others 0.0 | fixed coefficients | Fixed AR(10) coefficients. |

## Symbol Universe
Primary P2 basket from the approved card: `AUDUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`. The EA is not intended for indices, metals, energy, or non-DWX symbols.

## Timeframe
Base timeframe: M10. No higher-timeframe references are used.

## Expected Behaviour
The approved card estimates about 80 trades per year per symbol after threshold, spread, volatility, session, and news filters. Typical hold time is intraday, capped at six M10 bars unless an opposite forecast or session-close exit fires first. The edge is mean-reversion and should prefer liquid, noisy FX periods with enough short-term volatility.

## Source Citation
Kris Longmore, Robot Wealth, "Trading FX using Autoregressive Models", 2020-11-24. Source ID: `dcbac84f-6ecf-5d21-9630-50faa69306ec`.

## Risk Model
Backtests use `RISK_FIXED = 1000` with `RISK_PERCENT = 0`. Live deployment, after full approval, uses percent risk according to the OWNER-signed manifest, conventionally 0.5%.

## Build Notes
The card states that AR coefficients are fit once on the P2 in-sample window but does not provide numeric coefficients in the approved artifact. The EA exposes the coefficients as fixed inputs so the build remains deterministic and non-adaptive.
