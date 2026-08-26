# QM5_41160_xauxag-mlad-rv - Strategy Spec

**EA ID:** QM5_41160

**Slug:** `xauxag-mlad-rv`

**Strategy ID:** `SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026_S01`

**Source:** `SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-26

## 1. Strategy Logic

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of a
new broker-calendar month, exclude the current month and select the latest
exactly timestamp-matched close pair in each of the immediately prior
thirteen consecutive broker months.

For every selected pair calculate `s=ln(XAU_close)-ln(XAG_close)`. In
chronological order enumerate every forward pair `0 <= i < j <= 12` and form
`b=(s[j]-s[i])/(j-i)`, producing exactly 78 candidate slopes. For each `b`,
sort the thirteen residuals `s[i]-b*i`, take zero-based median index 6 as the
intercept, and sum the thirteen absolute residual errors. Retain every slope
whose loss is within `1e-12` of the minimum and take their ordinary median.
Fade a strictly positive LAD slope with SELL XAU / BUY XAG and a strictly
negative slope with BUY XAU / SELL XAG. Exact zero and malformed states
consume the month flat. Endpoint displacement is diagnostic only.

The position is one atomic, opposite-side, equal-notional package held for
one broker month with one aggregate fixed-risk ceiling and frozen per-leg ATR
hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_month_end_count` | 13 | exact consecutive completed months |
| `strategy_history_bars_d1` | 500 | bounded synchronized D1 scan per symbol |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | immediately prior month freshness guard |
| `strategy_loss_tie_epsilon` | `1e-12` | fixed minimum-loss equality rule |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal target absolute notionals |
| `strategy_max_notional_mismatch_fraction` | 0.20 | package validity cap |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_xau_max_spread_points` | 1500 | XAU entry-cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG entry-cost guard |
| `strategy_deviation_points` | 20 | framework order deviation contract |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411600000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411600001`.
- Logical symbol: `QM5_41160_XAU_XAG_MLAD_RV_D1`.
- The two legs are one strategy package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: thirteen consecutive synchronized completed broker month ends.
- Estimator: exact profiled least-absolute-deviation slope over 78 breakpoints.
- Trigger: strict sign of the median minimum-loss slope, traded contrarian.
- Hold: first tick in a later broker month, with a forty-day stale repair.

## 5. Expected Behaviour

- Approximately 10 to 12 completed packages per full post-warm-up year; Q02
  retires below five.
- Symmetric contrarian gold/silver relative-value exposure.
- One aggregate fixed-risk package and one consumed attempt per broker month.
- The LAD objective is functionally nonduplicate: the locked counterexample
  yields `-0.002` while the existing Theil-Sen basket yields a positive slope
  and therefore requests the opposite package.
- Q09 alone owns any realized portfolio-correlation conclusion.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; Roger Koenker and Gilbert Bassett Jr.
(1978), *Econometrica* 46(1), 33-50; CME Group, "Gold & Silver Ratio Spread."

Canonical bounded packet:
`strategy-seeds/sources/SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026/source.md`.

The sources support the state-dependent relative carrier, least-absolute-
deviation/check-loss lineage, and exchange intermarket-spread lineage. The
governed method packet supplies the exact finite breakpoint, median residual,
loss, and tie arithmetic. The paired horizon, contrarian direction, CFD
mapping, execution, and risk are disclosed QM hypotheses; no source result
transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg begins at half of the aggregate frozen-stop
risk allowance; balancing may only reduce the larger target notional. The EA
requires no more than 20% realized notional mismatch. Both news axes and
Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio admission,
correlation waiver, portfolio-gate change, current-month signal price,
Theil-Sen/OLS/fitted-scale gate, signal-strength sizing, external feed, retry,
scale-in, grid, martingale, pyramid, target, trail, break-even move, or partial
exit.

## Framework Alignment

- no_trade: exact symbols/period/ID/slots and locked risk/news/Friday inputs.
- trade_entry: consumed month, exact synchronized month-end selection,
  chronological ratios, 78 breakpoint slopes, profiled median intercepts,
  absolute objectives, fixed tie face, minimizer median, contrarian sides,
  spread/quote/ATR/stop checks, equal-notional sizing, and atomic submission.
- trade_management: malformed-package repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-26 | approved source build | G0-approved card; governed magics `411600000`/`411600001`; one logical Q02 preset |
