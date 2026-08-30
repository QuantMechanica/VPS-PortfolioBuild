# QM5_41210_xauxag-samecal-tstat - Strategy Spec

**EA ID:** QM5_41210

Slug: `xauxag-samecal-tstat`

Strategy ID: `KELOHARJU-RCORE-XAUXAG-SAMECAL-TSTAT-2026_S01`

Source: `KELOHARJU-RCORE-XAUXAG-SAMECAL-TSTAT-2026`

Author: Development

Last revised: 2026-08-30

## 1. Strategy Logic

On the first tradable `XAUUSD.DWX` D1 bar after each normalized broker-month
transition, inspect the same target calendar month in exact years `Y-1`
through `Y-10`. Keep only years with strict adjacent-month endpoints that
match across XAU and XAG, and require at least five paired log returns
`d=r_xau-r_xag`.

Compute the arithmetic mean, sample variance with denominator `n-1`,
standard error `sqrt(variance/n)`, and `t=mean/se`. A score strictly above
`1.0+1e-10` buys XAU and sells XAG; a score strictly below
`-1.0-1e-10` reverses both legs. Invalid state and the inclusive confidence
band consume the month flat. An opened package closes at the next month.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | exact companion leg |
| `strategy_history_years` | 10 | exact prior same-calendar years inspected |
| `strategy_min_observations` | 5 | synchronized-pair floor |
| `strategy_t_threshold` | 1.0 | strict absolute score gate |
| `strategy_signal_tolerance` | 1e-10 | equality buffer |
| `strategy_history_bars_d1` | 3000 | bounded D1 reconstruction buffer per leg |
| `strategy_atr_period_d1` | 20 | completed per-leg ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | stale survivor repair |
| `strategy_xau_max_spread_points` | 1500 | XAU entry spread cap |
| `strategy_xag_max_spread_points` | 3000 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | basket market-order deviation |

All values are locked; no parameter sweep is authorized.

## 3. Symbol Universe

- Logical basket: `QM5_41210_XAU_XAG_SAMECAL_TSTAT_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, magic `412100000`.
- Companion/traded slot 1: `XAGUSD.DWX`, magic `412100001`.
- No third traded symbol or external runtime dependency.

## 4. Timeframe

- Host and both signal inputs: D1.
- Decision/reset: first genuine D1 bar after a normalized broker-month
  transition.
- History work runs only after new-bar, month-boundary, and consumed-attempt
  gates.

## 5. Expected Behaviour

- Approximately five to nine two-leg packages/year after warm-up; Q02 retires
  below five completed packages in any full scored year.
- Direction: exactly one long metal and one short metal.
- Risk: one `RISK_FIXED=1000` package budget split equally by stop risk.
- Hold: next broker month, capped by 40 days, malformed repair, or per-leg
  broker stop.
- Friday close and both news axes are disabled for the monthly native-price
  Q02 baseline.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), “Return Seasonalities,” *Journal of
Finance* 71(4), 1557–1590, supplies recurring same-calendar commodity-return
information and the five-year floor. Fuertes, Miffre, and Rallis (2010),
“Tactical Allocation in Commodity Futures Markets,” *Journal of Banking &
Finance* 34(10), 2530–2548, supplies the governed XAU/XAG carrier and monthly
hold. Commit-pinned R Core `stats::t.test` source supplies the mean,
sample-variance, standard-error, and one-sample-score arithmetic.

The complete evidence boundary is
`strategy-seeds/sources/KELOHARJU-RCORE-XAUXAG-SAMECAL-TSTAT-2026/source.md`;
the approved card is
`strategy-seeds/cards/approved/QM5_41210_xauxag-samecal-tstat_card.md`.
No source tests this exact paired CFD basket, threshold, or decorrelation.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg receives half the package stop-risk budget
and a frozen `3.5*ATR(20,D1)` hard stop. If either leg cannot be prepared or
the second leg fails, the package stands down or is flattened immediately.

No live setfile, live authorization, deploy manifest, `T_Live` change,
portfolio admission, correlation waiver, or portfolio-gate change exists.

## 8. Framework Alignment

- No-Trade: exact host/slot/input, normalized label convention, synchronized
  endpoint, sample, finite t-score, spread, quote, stop, lot, package, and
  consumed-month guards.
- Entry: strict t-score side, opposite legs, shared fixed risk, and frozen
  stops.
- Management: next-month, 40-day stale, orphan, direction, magic, duplicate,
  and stop repair before any new entry.
- Close: framework basket close, per-leg broker stops, and kill switch.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-30 | Initial build from approved G0 card | Q01 pending |

