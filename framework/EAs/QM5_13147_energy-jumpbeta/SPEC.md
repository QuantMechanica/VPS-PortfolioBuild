# QM5_13147_energy-jumpbeta - Strategy Spec

**EA ID:** QM5_13147
**Slug:** energy-jumpbeta
**Strategy ID:** HOLLSTEIN-AGGJUMP-2021_XTI_XNG_S01
**Source:** Hollstein, Prokopczuk, and Tharann (2021), DOI 10.1142/S2010139221500178
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from XTIUSD.DWX. On the first host bar of
each broker month, it forms 252 synchronized simple returns for XTI and XNG,
builds a fixed inverse-volatility energy benchmark, and marks benchmark
innovations at least two sample standard deviations from the mean as realized
common-jump observations.

For each leg it estimates a deterministic OLS regression on an intercept, the
continuous energy benchmark, and the realized-jump factor. It buys the lower
incremental jump-beta leg and shorts the higher jump-beta leg. Fixed package
risk is split equally, both legs receive frozen ATR(20) times 3.5 hard stops,
and the package closes at the next monthly transition, after 40 days, or
immediately on an orphan or invalid composition.

This is an OHLC-only proxy. It does not reproduce the source's option-derived
equity-market jump factor and inherits no source performance result.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| strategy_lookback_d1 | 252 | locked | synchronized completed simple returns |
| strategy_jump_z | 2.0 | locked | realized common-jump threshold |
| strategy_min_jump_days | 6 | locked | minimum nonzero jump-factor observations |
| strategy_history_bars | 320 | 300-400 | bounded D1 retrieval buffer |
| strategy_max_endpoint_gap_days | 10 | 7-10 | completed endpoint freshness |
| strategy_atr_period_d1 | 20 | 14-30 | D1 hard-stop ATR |
| strategy_atr_sl_mult | 3.5 | 2.5-5.0 | frozen stop multiple |
| strategy_max_hold_days | 40 | locked | stale package guard |
| strategy_xti_max_spread_pts | 1500 | 1000-2500 | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | 2000-4500 | XNG spread cap |
| strategy_deviation_points | 20 | 10-50 | basket order deviation |

The formation length, inverse-vol benchmark, two-sigma jump definition,
six-jump floor, continuous-factor control, OLS jump coefficient, low-minus-
high direction, monthly cadence, equal half-risk carrier, and no same-month
re-entry are locked.

## 3. Symbol Universe

- Logical symbol: QM5_13147_XTI_XNG_JBETA_D1.
- Host/traded slot 0: XTIUSD.DWX, D1, magic 131470000.
- Traded slot 1: XNGUSD.DWX, D1, magic 131470001.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. A signal forms only when framework
calendar keys show that the current host D1 bar is the first bar of a new
broker month. The current D1 bars are excluded from the 252-return estimator.

## 5. Expected Behaviour

- Approximately twelve completed packages/year after warm-up; retire below
  five packages/year.
- Typical hold is one broker month, bounded by a 40-day stale guard.
- The carrier is opposite-side and equal fixed-risk, not guaranteed dollar,
  beta, volatility, factor, jump, or realized market neutral.
- XNG gaps, legging, the option/realized proxy, endogenous two-name factor,
  regression instability, and continuous-CFD basis make risk high.
- Later portfolio gates alone may establish realized book correlation.

## 6. Source Citation And Evidence Boundary

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021), "Anomalies
in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017. DOI https://doi.org/10.1142/S2010139221500178. Approved-card and R1-R4
evidence: `strategy-seeds/cards/energy-jumpbeta_card.md`.

The source ranks 26 collateralized commodity futures using a stock-market
option-derived aggregate-jump factor. The EA ranks two continuous energy CFDs
using a price-native realized common-jump proxy and adds implementation risk
controls. No source return, drawdown, cost, significance, or correlation
statistic is imported.

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

- No-Trade: exact host, locked estimator, bounded synchronized history,
  endpoint freshness, finite arithmetic, minimum jump days, nonsingular OLS,
  spread, ATR, lot, magic, package, and prior-attempt guards.
- Entry: monthly low/high realized-jump-beta rank, paired orders, equal fixed-
  risk allocation, and frozen hard stops.
- Management: next-month close, 40-day time stop, deal-history same-month
  suppression, composition validation, and orphan cleanup.
- Close: QM_TM_ClosePosition for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-07-11 | Initial build from approved card | OWNER commodity-sleeve mission |
