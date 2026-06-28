# QM5_12733_xti-xng-xmom - Strategy Spec

**EA ID:** QM5_12733
**Slug:** `xti-xng-xmom`
**Source:** `SRC05_S10_XTI_XNG_XMOM_2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural energy relative-value sleeve as a
two-leg basket on `XTIUSD.DWX` and `XNGUSD.DWX`. On the first D1 bar of each
broker-calendar month it ranks both energy symbols by prior `strategy_lookback_d1`
log return, buys the stronger leg, and shorts the weaker leg. The package exits
at the next monthly rebalance, max-hold expiry, Friday close, broken-package
repair, or per-leg ATR hard stop.

This is not a duplicate of `QM5_12578_eia-oilgas-ratio`, which fades z-score
ratio extremes, or `QM5_12608_eia-oilgas-breakout`, which trades log-ratio
channel breakouts. It is also not `QM5_12567_cum-rsi2-commodity`, WTI
seasonality, WPSR/news timing, or single-instrument time-series momentum.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_d1` | 126 | 63-252 | Prior D1 return ranking lookback |
| `strategy_min_return_diff_pct` | 2.0 | 0.0-5.0 | Required XTI-minus-XNG return spread before entry |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 35 | 25-45 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 2500 | 1500-4000 | XNG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and magic slot 0.
- `XNGUSD.DWX` - hedge leg and magic slot 1.
- Logical basket symbol: `QM5_12733_XTI_XNG_XMOM_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` plus first-bar-of-month gate.

## 5. Expected Behaviour

- Expected spread packages/year: about 6-12.
- Typical hold: one calendar month.
- Regime preference: persistent relative momentum between crude oil and natural gas.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

The source lineage is Chan AT SRC05_S10, citing Daniel-Moskowitz cross-sectional
commodity futures momentum: rank futures by 12-month return, long the top rank,
and short the bottom rank. This build uses a Darwinex-native two-energy-symbol
realization with a 6-month default lookback to keep Q02 trade frequency above
the structural low-frequency floor.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
