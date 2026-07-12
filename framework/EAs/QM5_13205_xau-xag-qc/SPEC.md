# QM5_13205_xau-xag-qc - Strategy Spec

**EA ID:** QM5_13205
**Slug:** `xau-xag-qc`
**Strategy ID:** `SCHWEIKERT-QC-2018_XAU_XAG_S01`
**Source:** `SCHWEIKERT-QC-2018`
**Author of this spec:** Codex
**Last revised:** 2026-07-12

## 1. Strategy Logic

The EA runs one XAU/XAG D1 logical basket from `XAUUSD.DWX`. On the first
tradable host D1 bar of each broker month it loads 505 synchronized completed
XAU/XAG closes, holds the newest pair out, and fits three simple conditional
quantile regressions to the older 504 log-price pairs:

`ln(XAG) = alpha_tau + beta_tau * ln(XAU)` for
`tau = 0.10, 0.50, 0.90`.

On initialization, the EA finds the first host D1 bar of the current broker
month and rebuilds from the history strictly preceding that anchor. This
reproduces the same frozen month window after a mid-month restart instead of
silently sliding the estimator forward.

For each tau, alpha at a candidate beta is the empirical tau residual
quantile. The constrained exact beta is selected from the sorted pairwise
observation slopes plus `[0.25, 3.00]` bounds by binary search of the convex
profiled asymmetric check loss. Boundary solutions, crossed conditional lines,
too-narrow envelopes, and absent positive upper-minus-lower beta asymmetry fail
closed.

On each first tradable host D1 bar of a broker week, silver above the frozen
monthly 90% line opens BUY XAU plus SELL XAG; silver below the 10% line opens
SELL XAU plus BUY XAG. The applicable beta defines the XAU:XAG dollar-notional
target. Both lots are jointly scaled to no more than one `RISK_FIXED` package
at their frozen ATR stops.

Both legs close on a weekly conditional-median cross, after 70 calendar days,
or immediately on invalid composition or an orphan. Position and deal history
plus a terminal-global attempted-week marker prevent a restart, full broker
rejection, or stopped leg from reopening in the same broker week. A marker
from a future tester date is discarded when a replay moves calendar time
backward.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_formation_bars` | 504 | locked | prior completed QR formation pairs |
| `strategy_history_bars` | 700 | 650, 700, 800 | bounded synchronization buffer |
| `strategy_beta_min` | 0.25 | locked | constrained slope floor |
| `strategy_beta_max` | 3.00 | locked | constrained slope ceiling |
| `strategy_slope_unique_epsilon` | 1e-10 | locked | slope de-duplication tolerance |
| `strategy_min_beta_span` | 0.05 | locked | QM asymmetry gate |
| `strategy_min_band_width` | 0.010 | locked | 10%-90% envelope-width floor |
| `strategy_entry_band_mult` | 0.00 | 0.00, 0.10, 0.25 | tail-boundary extension |
| `strategy_max_endpoint_gap_days` | 10 | 7, 10 | completed endpoint freshness |
| `strategy_atr_period_d1` | 20 | 14, 20, 30 | D1 hard-stop ATR period |
| `strategy_atr_sl_mult` | 4.0 | 3.0, 4.0, 5.0 | frozen stop multiple |
| `strategy_max_hold_days` | 70 | 42, 70 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | 1000, 1500, 2500 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 500 | 300, 500, 800 | XAG entry spread cap |
| `strategy_max_hedge_error_pct` | 20.0 | 10.0, 20.0, 30.0 | post-rounding beta-notional error cap |
| `strategy_deviation_points` | 20 | 10, 20, 50 | paired-order deviation |

The 504-pair held-out design, 10/50/90 quantiles, asymmetric check-loss
objective, exact constrained pairwise-slope solve, beta-span gate, monthly
fit, weekly signals, paired direction, beta-target notional sizing, and median
exit are locked for Q02.

## 3. Symbol Universe

**Designed for:**

- `XAUUSD.DWX` - gold CFD, host and traded magic slot 0.
- `XAGUSD.DWX` - silver CFD, traded magic slot 1.

**Explicitly NOT for:**

- Standalone XAU or XAG evaluation; Q02 must test the logical package.
- Other symbols or timeframes.

Logical symbol: `QM5_13205_XAU_XAG_QC_D1`.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Formation | 504 synchronized completed pairs, newest pair held out |
| Model cadence | first tradable D1 host bar of each broker month |
| Signal/exit cadence | first tradable D1 host bar of each broker week |

Current open bars never enter the fit or signal.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6-12 packages after warm-up; retire below five |
| Typical hold time | one to several weeks; maximum 70 calendar days |
| Expected drawdown profile | high; XAG gaps, state instability, and legging can dominate |
| Regime preference | positive upper-vs-lower conditional beta asymmetry |
| Win rate target | unknown; Q02 must establish |

The beta-target notional package reduces common metal direction by design but
does not prove realized book decorrelation or neutrality.

## 6. Source Citation

**Source ID:** `SCHWEIKERT-QC-2018`
**Source type:** peer-reviewed paper / complete author preprint
**Pointer:** `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`
**Primary DOI:** https://doi.org/10.1016/j.jbankfin.2017.11.010
**R1-R4 verdict:** all PASS; see
`strategy-seeds/cards/xau-xag-qc_card.md`.

The paper estimates state-dependent quantile cointegration but explicitly does
not provide a direct forecasting rule. Logs, the rolling sample, quantiles,
beta-span threshold, cadence, trading envelope, exits, and risk model are QM
mechanizations. Constant-vector rejection and upper-tail fragility are kill
risks, not waiver grounds.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 combined package stop risk |
| Live burn-in | not authorized | no live setfile |
| Full live | not authorized | portfolio allocation required |

Desired XAU:XAG dollar notionals are `beta:1`. Framework full-risk capacities
at each ATR stop are combined to scale both lots to at most one package budget,
then rounded down. There is no TP, trail, break-even, partial close, scale-in,
grid, martingale, pyramiding, external runtime feed, banned indicator, or ML.

## 8. Four-Module Mapping

- **No-Trade:** exact host/timeframe/slot, bounded synchronized history,
  endpoint freshness, candidate-slope domain, exact check-loss fit, interior
  betas, line ordering across the formation X domain, tail width, beta span,
  spread, ATR, lot, magic, package, and persisted weekly-attempt guards.
- **Entry:** weekly 10%/90% conditional-envelope breach, opposite XAU/XAG
  orders, beta-target notionals, joint fixed-risk scaling, and frozen stops.
- **Management:** monthly refit, weekly conditional-median close, 70-day stale
  close, exact month-anchor restart reconstruction, composition validation,
  restart-safe attempt guard, and orphan repair. Unauthorized inputs block
  model/entry work without bypassing composition or time-stop management.
- **Close:** framework package-close helper plus broker hard stops.

## 9. Safety Boundary

No live setfile, `T_Live` change, AutoTrading action, deploy manifest,
portfolio gate change, admission artifact, portfolio KPI path, external
runtime feed, or manual tester run is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-12 | Initial build from approved card | OWNER mission; restart-safe month anchor and attempt marker |
