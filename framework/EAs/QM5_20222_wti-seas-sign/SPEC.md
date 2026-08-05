# QM5_20222_wti-seas-sign - Strategy Spec

**EA ID:** QM5_20222

**Slug:** `wti-seas-sign`

**Source:** `BURAKOV-PAPAILIAS-WTI-SEASIGN-2026`

**Author:** Research+Development

**Last revised:** 2026-08-05

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of every broker month, reconstruct
thirteen consecutive completed month-end closes. Convert the twelve monthly
returns to binary signs, assigning one to non-negative returns. The return-sign
state is long when their mean is at least 0.40 and short otherwise. The fixed
seasonal state is long November-May and short June-October. Open a package only
when the two directions agree; otherwise remain flat for that month.

Close the prior package before every monthly decision. Persist each calendar
month before fallible gates so a blocked, stopped, failed, or disagreeing
attempt cannot retry after restart. Use a frozen `3.5 * ATR(20,D1)` hard stop,
no target, and a forty-day stale guard. Friday close is disabled because the
monthly source hold spans weekends.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_winter_first_month` | 11 | November seasonal-long start |
| `strategy_winter_last_month` | 5 | May seasonal-long end |
| `strategy_lookback_months` | 12 | Binary monthly-return window |
| `strategy_positive_threshold` | 0.40 | Return-sign direction threshold |
| `strategy_history_bars` | 500 | Bounded D1 reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | Maximum WTI entry spread |

Every value is locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Magic slot: 0 (`202220000`).
- No companion symbol, conversion history, or external runtime input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first processed D1 bar of every new broker month.
- Seasonal state: long November-May; short June-October.
- Formation: thirteen consecutive completed broker-month endpoints.

## 5. Expected Behaviour

Maximum cadence is twelve decisions per full post-warm-up year. The
predeclared expectation is six to nine concordant packages/year; Q02 retires
below five completed packages/year. Exposure normally spans one broker month
and disagreement months remain flat. Principal risks are interaction decay,
filter-induced under-frequency, WTI gaps and rolls, futures-to-CFD basis,
financing, stop-outs, source inconsistencies/adverse drawdown, and realized
book correlation.

## 6. Source Citation

Burakov, D., Freidin, M., and Solovyev, Y. (2018), "The Halloween Effect on
Energy Markets: An Empirical Study," *International Journal of Energy
Economics and Policy* 8(2), 121-126. Papailias, F., Liu, J., and Thomakos,
D. D. (2021), "Return Signal Momentum," *Journal of Banking & Finance* 124,
106063, DOI `10.1016/j.jbankfin.2021.106063`.

The governed composite is
`strategy-seeds/sources/BURAKOV-PAPAILIAS-WTI-SEASIGN-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20222_wti-seas-sign_card.md`. The sources
supply the seasonal and return-sign parent states, not this interaction's WTI
CFD performance.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and Friday close are OFF. Every trade has
a server-side ATR hard stop. There is no manual backtest, live/demo/shadow
setfile, live authorization, deploy manifest, portfolio admission, or
portfolio-gate change.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-05 | Initial build from approved G0 card | Q01 strict compile/build PASS; 0 errors, warnings, failures, or build warnings |
