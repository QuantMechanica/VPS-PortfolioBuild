# QM5_13203_energy-downbeta - Strategy Spec

**EA ID:** QM5_13203
**Slug:** `energy-downbeta`
**Strategy ID:** `HOLLSTEIN-DOWNBETA-2021_XTI_XNG_S01`
**Source:** `HOLLSTEIN-DOWNBETA-2021`
**Author of this spec:** Codex
**Last revised:** 2026-07-12

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On the first host bar of
each broker month, it reconstructs 252 synchronized completed daily simple
returns for XTI, XNG, and the read-only `SP500.DWX` market factor. A downside
market day is a completed observation whose SP500 return is strictly below the
mean of all 252 SP500 returns. The estimator requires at least 100 such
observations.

For each traded energy leg, downside beta is the covariance of its return with
the SP500 return divided by SP500 return variance, using downside days only.
The package buys the lower-downside-beta energy leg and shorts the
higher-downside-beta leg. Fixed package risk is split equally, and both legs
receive frozen `ATR(20) * 3.5` hard stops.

The package closes at the next broker-month transition, after 40 calendar
days, or immediately on an orphan or invalid composition. Position and deal
history prevent a restart or stopped leg from opening a second package in the
same broker month.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_lookback_d1` | 252 | baseline locked | synchronized completed D1 return observations |
| `strategy_min_down_days` | 100 | baseline locked | minimum below-mean SP500 observations |
| `strategy_beta_tie_epsilon` | 1e-8 | baseline locked | numerical no-trade guard for indistinguishable betas |
| `strategy_history_bars` | 420 | baseline locked | bounded retrieval and warm-up buffer |
| `strategy_max_endpoint_gap_days` | 10 | baseline locked | maximum age of the latest completed synchronized endpoint |
| `strategy_atr_period_d1` | 20 | baseline locked | D1 hard-stop ATR period |
| `strategy_atr_sl_mult` | 3.5 | baseline locked | frozen stop multiple |
| `strategy_max_hold_days` | 40 | baseline locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | baseline locked | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | baseline locked | XNG entry spread cap |
| `strategy_deviation_points` | 20 | baseline locked | paired-order deviation |

The 252-observation window, below-mean SP500 day definition, 100-observation
floor, `1e-8` beta-tie guard, low-minus-high direction, monthly cadence, equal
half-risk carrier, and no same-month re-entry are locked for Q02.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - WTI crude-oil CFD, host and traded magic slot 0.
- `XNGUSD.DWX` - natural-gas CFD, traded magic slot 1.
- `SP500.DWX` - synchronized read-only downside-market factor; never traded.

**Explicitly NOT for:**

- Standalone XTI, XNG, or SP500 testing - Q02 must evaluate the logical paired
  package.
- Other symbols or timeframes - no mapping beyond the approved carrier is
  authorized.

Logical symbol: `QM5_13203_XTI_XNG_DOWNBETA_D1`.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-symbol refs | synchronized XTI, XNG, and read-only SP500 D1 closes |
| Bar gating | new `XTIUSD.DWX` D1 host bar |
| Signal cadence | first tradable host bar of each broker month |

The current open D1 bar is excluded from all return and downside-beta inputs.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 12 package entries after warm-up; retire below five |
| Typical hold time | one broker month, maximum 40 calendar days |
| Expected drawdown profile | high; XNG gaps, energy/index decoupling, and legging can dominate |
| Regime preference | persistent dispersion in energy downside sensitivity to the equity factor |
| Win rate target (qualitative) | unknown; Q02 must establish |

The basket is opposite-side and equal fixed-risk. It is not guaranteed dollar,
beta, volatility, factor, or portfolio neutral, and later portfolio gates alone
may establish realized book correlation.

## 6. Source Citation

**Source ID:** `HOLLSTEIN-DOWNBETA-2021`
**Source type:** peer-reviewed paper / institutional accepted manuscript
**Pointer:** `strategy-seeds/sources/HOLLSTEIN-DOWNBETA-2021/source.md`
**Primary DOI:** https://doi.org/10.1142/S2010139221500178
**R1-R4 verdict (Q00):** all PASS; see
`strategy-seeds/cards/energy-downbeta_card.md`.

The source studies a broad commodity-futures cross-section. Its reported
high-minus-low downside-beta spread is negative but statistically
insignificant, so the approved carrier uses the source-sign low-minus-high
translation with a deliberately low prior. This implementation narrows the
test to two continuous energy CFDs and a read-only SP500 CFD factor. No source
return, significance, drawdown, cost, correlation, or diversification claim is
imported into Q02.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per package, split equally |
| Live burn-in | not authorized | no live setfile |
| Full live | not authorized | portfolio allocation required |

Both traded legs use framework risk sizing with a 0.5 package share and frozen
ATR hard stops. A failed second order immediately flattens the first. There is
no take-profit, trail, break-even, partial close, scale-in, grid, martingale,
pyramiding, external runtime feed, banned indicator, or ML.

## 8. Four-Module Mapping

- **No-Trade:** exact host and timeframe, locked estimator, synchronized
  history, endpoint freshness, downside-observation count, finite beta,
  nonzero factor variance, beta-tie epsilon, spread, ATR, lot, magic, package,
  and prior-attempt guards.
- **Entry:** downside-only XTI/XNG beta rank against read-only SP500, paired
  low-minus-high orders, equal fixed-risk allocation, and frozen hard stops.
- **Management:** next-month close, 40-day stale close, deal-history
  same-month suppression, composition validation, and orphan cleanup.
- **Close:** framework package-close helper plus broker hard stops.

## 9. Safety Boundary

No live setfile, `T_Live` change, AutoTrading action, deploy manifest,
portfolio gate change, admission artifact, portfolio KPI path, or external
runtime data is authorized. `SP500.DWX` is read-only and must never receive an
order or magic slot.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-12 | Initial build from approved card | OWNER commodity-sleeve mission |
