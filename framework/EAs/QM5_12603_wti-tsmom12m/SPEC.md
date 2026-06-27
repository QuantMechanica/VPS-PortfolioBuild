# QM5_12603_wti-tsmom12m - Strategy Spec

**EA ID:** QM5_12603
**Slug:** `wti-tsmom12m`
**Source:** `MOP-TSMOM-2012`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural WTI time-series-momentum sleeve
on `XTIUSD.DWX`. On the first new D1 bar of each broker-calendar month, it
computes the prior 12-month log return from completed D1 closes. A positive
return above the neutral band opens a monthly long package; a negative return
below the neutral band opens a monthly short package. Any open package is
flattened on the next monthly rebalance or by the max-hold stale-position guard.

The strategy is intentionally not a duplicate of the existing WTI family:
calendar weekday/month effects, broad EIA petroleum seasonality, WPSR setups,
hurricane supply risk, refinery fades, OPEC policy windows, CME expiry windows,
and medium-term reversal all use different timing or entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | 126-315 | Completed D1 bars used for 12-month return-sign signal |
| `strategy_min_abs_return_pct` | 1.0 | 0.0-5.0 | Neutral band around zero trailing return |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 31 | 21-45 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 8-12.
- Typical hold: one monthly package, capped at 31 calendar days by default.
- Regime preference: persistent WTI directional trends over a 12-month horizon.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H., "Time Series Momentum",
Journal of Financial Economics, 2012, URL
https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

