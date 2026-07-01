# QM5_12849_brent-tsmom12m - Strategy Spec

**EA ID:** QM5_12849
**Slug:** `brent-tsmom12m`
**Source:** `MOP-TSMOM-2012_BRENT_S01`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency structural Brent time-series-momentum sleeve
on `XBRUSD.DWX`. On the first new D1 bar of each broker-calendar month, it
computes the prior 12-month log return from completed D1 closes. A positive
return above the neutral band opens a monthly long package; a negative return
below the neutral band opens a monthly short package. Any open package is
flattened on the next monthly rebalance or by the max-hold stale-position guard.

The strategy is intentionally distinct from the existing Brent family:
`QM5_12841_brent-thu-prem` is a one-day weekday seasonal, while
`QM5_12843_wti-brent-spread` and `QM5_12848_wti-brent-brk` are Brent/WTI
relative-value baskets. This EA is a single-symbol Brent directional sleeve.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | 126-315 | Completed D1 bars used for 12-month return-sign signal |
| `strategy_min_abs_return_pct` | 1.0 | 0.0-5.0 | Neutral band around zero trailing return |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 31 | 21-45 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1200 | 800-1800 | Entry spread cap |

## 3. Symbol Universe

- `XBRUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 8-12.
- Typical hold: one monthly package, capped at 31 calendar days by default.
- Regime preference: persistent Brent directional trends over a 12-month
  horizon.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H., "Time Series Momentum",
Journal of Financial Economics, 2012, 104(2), 228-250, URL
https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
