# QM5_41110_xauxag-moutside-res-rv - Strategy Spec

**EA ID:** QM5_41110
**Slug:** `xauxag-moutside-res-rv`
**Strategy ID:** `SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026_S01`
**Source:** `SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026`
**Author:** Development
**Last revised:** 2026-08-22

## 1. Strategy Logic

At the first exact synchronized XAU/XAG D1 boundary of a new broker month,
the EA reconstructs the fixed unit daily-close log ratio in the immediately
completed and parent consecutive calendar months:

```text
r[d] = log(XAU_close[d]) - log(XAG_close[d])
```

It takes the parent month's observed ratio minimum and maximum. If at least
five newest-month ratios are strictly above the parent maximum, none is below
the parent minimum, and the chronologically final newest-month ratio remains
above the parent maximum, the package fades the displacement by selling XAU
and buying XAG. The exact lower-side mirror buys XAU and sells XAG. Equality,
an opposite boundary breach, fewer than five outside observations, an inside
final close, incomplete or non-adjacent months, asynchronous data, or invalid
arithmetic consumes the month flat.

The attempt is persisted before all fallible signal and execution gates. The
two opposite legs target equal absolute USD notionals, share one fixed-dollar
risk budget, use frozen `3.5 * ATR(20,D1)` hard stops, have no profit target,
and close together at the first observed boundary of the following month.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion route |
| `strategy_history_bars_d1` | 70 | bounded completed-history scan |
| `strategy_min_month_sessions` | 17 | minimum sessions in each month |
| `strategy_max_month_sessions` | 23 | maximum sessions in each month |
| `strategy_min_outside_sessions` | 5 | one-sided parent-range residence floor |
| `strategy_entry_grace_minutes` | 180 | first-new-month entry window |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen stop distance per leg |
| `strategy_notional_ratio` | 1.0 | XAU/XAG absolute-notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | rounded package tolerance |
| `strategy_max_hold_days` | 40 | stale-package guard |
| `strategy_xau_max_spread_points` | 1500 | XAU entry spread ceiling |
| `strategy_xag_max_spread_points` | 500 | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | market-order deviation ceiling |

Every Q02 baseline parameter is locked; there is no optimization surface.

## 3. Symbol Universe

- Logical basket: `QM5_41110_XAU_XAG_MOUTSIDE_RES_RV_D1`.
- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411100000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411100001`.
- Both legs form one package. Neither leg is a standalone strategy.

## 4. Timeframe

- Host and signal timeframe: D1.
- Formation: every synchronized completed close in the immediately prior two
  broker-calendar months, with 17 through 23 sessions in each.
- Decision cadence: one durable attempt per broker month, within 180 raw
  session minutes of its first exact D1 bar.
- Hold: through the first observed next-month boundary, with a 40-day stale
  repair guard.

## 5. Expected Behaviour

- Approximately five to nine completed packages per full post-warm-up year;
  Q02 retires below five rather than tuning the rule.
- Persistent upper outside-range residence produces SELL XAU / BUY XAG; the
  exact lower mirror produces BUY XAU / SELL XAG.
- One aggregate fixed-risk, opposite-side, equal-notional package at a time,
  with immediate orphan or malformed-package repair.
- Equal notionals do not establish neutrality or low correlation. Q09 alone
  owns any realized portfolio-correlation finding.

## 6. Source Citation

Schweikert, Karsten (2018), "Are gold and silver cointegrated? New evidence
from quantile cointegrating regressions," *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`; and CME Group, "Gold & Silver
Ratio Spread."

The bounded composite packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026/source.md`.
The sources support a state-dependent gold/silver relationship and the ratio
carrier. The completed-month residence fade is a disclosed QM hypothesis; no
source return, hedge ratio, or CFD result transfers.

## 7. Risk Model

Q02 uses one logical `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both leg volumes are solved jointly from final broker-
normalized stops so combined normalized stop risk cannot exceed that package
budget while rounded absolute notionals remain within 20%. Signal magnitude
never scales risk. Both news axes and framework Friday close are OFF.

No live, demo, shadow, stress, or optimization preset; AutoTrading action;
`T_Live` or deploy manifest; portfolio admission; correlation waiver; or
portfolio-gate change is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | approved build identity | source, G0 card, EA-ID, and two deterministic magic rows complete |
