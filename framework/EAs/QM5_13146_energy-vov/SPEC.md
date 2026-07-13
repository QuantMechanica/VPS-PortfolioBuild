# QM5_13146_energy-vov - Strategy Spec

**EA ID:** QM5_13146
**Slug:** energy-vov
**Strategy ID:** HOLLSTEIN-VOV-2021_XTI_XNG_S01
**Source:** Hollstein, Prokopczuk, and Tharann (2021), DOI 10.1142/S2010139221500178
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from XTIUSD.DWX. On the first host bar of
each broker month, it builds 252 overlapping annualized realized-volatility
estimates for each energy leg. Each RV estimate uses exactly 20 completed D1
log returns and sample variance. Realized VoV is the population standard
deviation of those 252 RV estimates divided by their mean.

It buys the lower realized-VoV leg and shorts the higher realized-VoV leg.
Fixed package risk is split equally, both legs receive frozen ATR(20) times
3.5 hard stops, and the package closes at the next monthly transition, after
40 days, or immediately on an orphan or invalid composition.

This is an OHLC-only proxy. It does not reproduce the source's option-implied
volatility signal and inherits no source performance result.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| strategy_rv_window_d1 | 20 | locked | completed log returns per RV sample |
| strategy_vov_samples | 252 | locked | daily RV observations in VoV transform |
| strategy_history_bars | 320 | 300-400 | bounded D1 retrieval buffer |
| strategy_max_endpoint_gap_days | 10 | 7-10 | completed endpoint freshness |
| strategy_atr_period_d1 | 20 | 14-30 | D1 hard-stop ATR |
| strategy_atr_sl_mult | 3.5 | 2.5-5.0 | frozen stop multiple |
| strategy_max_hold_days | 40 | locked | stale package guard |
| strategy_xti_max_spread_pts | 1500 | 1000-2500 | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | 2000-4500 | XNG spread cap |
| strategy_deviation_points | 20 | 10-50 | basket order deviation |

The nested 20/252 windows, sample variance within RV, population dispersion
across RV, mean-RV denominator, low-minus-high direction, monthly cadence,
equal half-risk carrier, and no same-month re-entry are locked.

## 3. Symbol Universe

- Logical symbol: QM5_13146_XTI_XNG_VOV_D1.
- Host/traded slot 0: XTIUSD.DWX, D1, magic 131460000.
- Traded slot 1: XNGUSD.DWX, D1, magic 131460001.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. A signal forms only when the current
host bar enters a new broker calendar month and the immediately prior host bar
has a different month key. Current D1 bars are excluded.

## 5. Expected Behaviour

- Approximately twelve completed packages/year after warm-up; retire below
  five packages/year.
- Typical hold is one broker month, bounded by a 40-day stale guard.
- The carrier is opposite-side and equal fixed-risk, not guaranteed dollar or
  beta neutral.
- XNG gaps, legging, the realized/implied proxy, overlapping samples, and the
  narrow rank make risk high.
- Later portfolio gates alone may establish realized book correlation.

## 6. Source Citation And Evidence Boundary

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021), "Anomalies
in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017. DOI https://doi.org/10.1142/S2010139221500178.

The source ranks 26 commodity futures using 252 daily option-implied
volatility observations. The EA ranks two continuous CFDs using a nested
realized-volatility proxy and adds implementation risk controls. The source
sample ends in 2015 and its later-subperiod evidence is weaker. No source
performance, drawdown, cost, or correlation statistic is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | RISK_FIXED | 1000 per package, split 50/50 |
| Live | not authorized | none |

The EA calls QM_LotsForRisk and applies the 0.5 package share after framework
sizing. It validates broker volume metadata and flattens a failed two-leg
entry. There is no TP, trail, break-even, partial close, scale-in, grid,
martingale, or pyramiding.

## 8. Four-Module Mapping

- No-Trade: exact host, locked estimator, bounded history, endpoint freshness,
  positive finite arithmetic, spread, ATR, lot, magic, package, and prior-
  attempt guards.
- Entry: monthly low/high realized-VoV rank, paired orders, equal fixed-risk
  allocation, and frozen hard stops.
- Management: next-month close, 40-day time stop, deal-history same-month
  suppression, composition validation, and orphan cleanup.
- Close: QM_TM_ClosePosition for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.
