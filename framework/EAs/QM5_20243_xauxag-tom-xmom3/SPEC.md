# QM5_20243_xauxag-tom-xmom3 - Strategy Spec

**EA ID:** QM5_20243

**Slug:** `xauxag-tom-xmom3`

**Sources:** `VANHEMERT-MOMTOM-2014` and `FMR-MOMTS-2010`

**Author:** Research+Development

**Last revised:** 2026-08-06

## 1. Strategy Logic

On each new `XAUUSD.DWX` D1 host bar, map the broker date into a TOM cycle:
the last two dates of month `t` and the first date of `t+1` share the key `t`.
Consume that cycle before fallible entry gates. Reconstruct four synchronized
XAU and XAG completed month ends ending at `t-1`, average exactly three simple
monthly returns per leg, buy the higher-return metal, and short the lower.

One package risk budget is split equally across frozen
`3.5 * ATR(20,D1)` hard stops. There is no target. Close the package at the
first D1 bar outside the same cycle, after six calendar days, or immediately
on an orphan/invalid package. Friday close is disabled so the source window
can cross a weekend.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_tom_pre_days` | 2 | Final calendar dates in cycle month |
| `strategy_tom_post_days` | 1 | First calendar date after month end |
| `strategy_return_window_months` | 3 | Completed monthly returns per leg |
| `strategy_history_bars` | 500 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 6 | TOM stale guard |
| `strategy_xau_max_spread_pts` | 1500 | Maximum XAU entry spread |
| `strategy_xag_max_spread_pts` | 3000 | Maximum XAG entry spread |
| `strategy_deviation_points` | 20 | Order deviation |

All strategy values are locked for Q02. No baseline parameter sweep is
authorized.

## 3. Symbol Universe

- Logical basket: `QM5_20243_XAU_XAG_TOM_XMOM3_D1`.
- Host/slot 0: `XAUUSD.DWX`, magic `202430000`.
- Companion/slot 1: `XAGUSD.DWX`, magic `202430001`.
- Exactly one opposite-direction pair; standalone-leg evaluation is invalid.

## 4. Timeframe

- Exact host timeframe: D1.
- Formation: four synchronized month ends ending before the cycle month.
- Signal: arithmetic average of exactly three simple monthly returns per leg.
- Lifecycle: one attempted package per last-two/first-one broker-date cycle.

## 5. Expected Behaviour

Expected cadence is approximately 8-12 complete packages per year after
warm-up; Q02 retires below five/year. Typical exposure is one to four calendar
days and is capped at six. Principal risks are calendar-date versus trading-day
translation, XAU/XAG legging and financing, lot granularity, futures-to-CFD
basis, common-metal and industrial-silver factors, and realized correlation
with the incumbent XAU sleeve.

## 6. Source Citation

van Hemert, O. (2014), "The MOM-TOM Effect: Detecting the Market Impact of CTA
Trading," SSRN 2515900.

Fuertes, A.-M., Miffre, J., and Rallis, G. (2010), "Tactical Allocation in
Commodity Futures Markets: Combining Momentum and Term Structure Signals,"
*Journal of Banking & Finance* 34(10), 2530-2548, DOI
`10.1016/j.jbankfin.2010.04.009`.

The governed composite record is
`strategy-seeds/sources/VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20243_xauxag-tom-xmom3_card.md`. Neither
source tests this exact intersection or two continuous precious-metals CFDs.

## 7. Risk Model

Backtests use one logical-basket setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Both legs share the one fixed
budget equally by hard-stop risk. Both news axes, stress rejection, and Friday
close are OFF.

There is no manual backtest, live/demo/shadow setfile, AutoTrading action,
`T_Live` access, deploy manifest, portfolio admission, or portfolio-gate
change.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Initial build from approved G0 card | Q01 strict compile PASS; 0 errors and 0 warnings |
