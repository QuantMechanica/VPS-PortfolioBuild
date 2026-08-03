# QM5_20209_wti-winter-mom1 — Strategy Spec

**EA ID:** QM5_20209

**Slug:** `wti-winter-mom1`

**Source:** `BURAKOV-MOP-WTI-WINTER-MOM1-2026`

**Author:** Research+Development

**Last revised:** 2026-08-03

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of each November-May broker
month, reconstruct the two latest distinct, consecutive completed month-end
closes. Buy WTI when the exact prior-month log return is positive and short
WTI when it is negative. Equality or invalid history stays flat for the
consumed month. June through October is a forced-flat regime.

Close the prior package before each monthly renewal. Persist each eligible
month before fallible gates so a blocked, flat, stopped, or failed attempt
cannot retry after restart. Use a frozen `3.5 * ATR(20,D1)` hard stop, no
profit target, and a forty-day stale guard. Friday close is disabled because
the source hold spans weekends.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_first_active_month` | 11 | November regime start |
| `strategy_last_active_month` | 5 | May regime end |
| `strategy_history_bars` | 80 | Bounded D1 month-end reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | Maximum WTI entry spread |

Every value is locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Magic slot: 0 (`202090000`).
- No companion symbol, conversion-only history, or external runtime input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first processed D1 bar of each new broker month.
- Eligible clock: November through May only.
- Formation: exact two consecutive completed broker-month endpoints.

## 5. Expected Behaviour

Expected cadence is approximately seven completed packages per full
post-warm-up year; Q02 retires below five/year. Exposure normally spans one
broker month and is always flat June through October. Primary risks are
seasonal/momentum interaction decay, WTI gaps and rolls, futures-to-CFD basis,
financing, stop-outs, seven-decision sparsity, and realized book correlation.

## 6. Source Citation

Burakov, D., Freidin, M., and Solovyev, Y. (2018), “The Halloween Effect on
Energy Markets: An Empirical Study,” *International Journal of Energy
Economics and Policy* 8(2), 121–126. Moskowitz, T. J., Ooi, Y. H., and
Pedersen, L. H. (2012), “Time Series Momentum,” *Journal of Financial
Economics* 104(2), 228–250, DOI `10.1016/j.jfineco.2011.11.003`.

The governed composite is
`strategy-seeds/sources/BURAKOV-MOP-WTI-WINTER-MOM1-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20209_wti-winter-mom1_card.md`.
The sources supply the winter regime and the one-month commodity sign family,
not this WTI CFD conjunction or its performance.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and Friday close are OFF. Every trade has
a server-side ATR hard stop. There is no live/demo/shadow setfile, live
authorization, deploy manifest, portfolio admission, or portfolio-gate
change.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-03 | Initial build from approved G0 card | Q01 PASS: strict compile and V5 build check, 0 errors/warnings |
