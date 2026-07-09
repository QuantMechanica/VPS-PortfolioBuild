# QM5_1017 chan-pairs-stat-arb

**EA ID:** QM5_1017
**Slug:** chan-pairs-stat-arb
**Approved card:** `strategy-seeds/cards/chan-pairs-stat-arb_card.md` (`SRC02_S01`)
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA trades the approved Chan cointegration spread on `AUDUSD.DWX` and
`NZDUSD.DWX`. At the first closed D1 bar of each calendar year it fits
`AUDUSD - beta * NZDUSD` from the preceding 252 closed bars, then freezes the
OLS hedge ratio, spread mean, and spread standard deviation for that annual
walk-forward segment. Entry remains disabled unless the one-lag CADF statistic
passes the selected critical value and the fitted OU half-life is no greater
than 30 days.

The EA opens both legs when the frozen-model z-score reaches -2 or +2. A
partial fill is rolled back immediately. It closes both legs when absolute
z-score returns to 1 or less, or when the fitted OU half-life time stop expires.
Only one spread may be open. No ML, grid, pyramiding, trailing stop,
break-even, or native price stop is present.

## 2. Parameters

| Parameter | Default | Card range / role |
|---|---:|---|
| `pair_symbol_1` | `AUDUSD.DWX` | Approved Darwinex pair leg 1. |
| `pair_symbol_2` | `NZDUSD.DWX` | Approved Darwinex pair leg 2. |
| `cadf_gate_enabled` | `true` | Required structural deployment gate. |
| `cointegration_significance` | `0.05` | `0.01, 0.05, 0.10`. |
| `training_lookback` | `252` | `126, 189, 252, 378, 504` D1 bars. |
| `entry_z` | `2.0` | `1.0` through `2.5`. |
| `exit_z` | `1.0` | `0.0` through `1.25`, below entry z. |
| `deployment_halflife_cap_days` | `30` | `10, 20, 30, 60` days. |
| `time_stop_multiplier` | `1.0` | `0.5` through `3.0`. |
| `strategy_deviation_points` | `20` | Basket-order execution tolerance. |

## 3. Symbol Universe

The concrete Q02 basket is `AUDUSD.DWX` / `NZDUSD.DWX`, hosted on
`AUDUSD.DWX`. The symbols use active magic-registry slots 4 and 26 for EA 1017.
The card permits other CADF-qualified Darwinex pairs only as separately
declared pipeline variants; this build and manifest do not fan out to them.

Logical tester symbol:
`QM5_1017_AUDUSD_NZDUSD_COINTEGRATION_D1`.

## 4. Timeframe

The signal, model, and execution timeframe is D1. Pair history is read only
after the framework D1 new-bar gate. The annual refit consumes prior closed
bars only; the current closed signal bar is not included in its training
sample.

## 5. Expected Behaviour

The approved card estimates 25-50 entries per year per qualified pair with a
multi-day holding period. The Q02 economic floor remains authoritative. Risk
is market-neutral at entry through synchronized opposite legs and the fitted
hedge ratio; the primary failure regime is a structural cointegration break,
which the next annual CADF gate prevents from opening new positions.

## 6. Source Citation

Ernest P. Chan, *Quantitative Trading: How to Build Your Own Algorithmic
Trading Business* (Wiley, 2009), Example 3.6 pages 55-59 and Chapter 7 examples
7.2, 7.3, and 7.5 pages 126-142. Exact excerpts and MATLAB mechanics are
preserved in `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.
The card records this book as the quality-tier-A primary source and its G0
approval trail.

## 7. Risk Model

| Environment | Active risk mode | Value |
|---|---|---:|
| Q02-Q10 backtest | `RISK_FIXED` | `1000` |
| Live | `RISK_PERCENT` | Set only by the signed live deployment process. |

The card explicitly forbids a native reversal-model stop. For comparable
fixed-risk sizing, the EA uses the card-authorized four-sigma catastrophic
spread distance only to calculate paired lots; both order SL fields remain
zero. The two legs preserve the fitted unit ratio while their combined
synthetic tail loss consumes one fixed-risk budget.

## Q02 Packaging

`basket_manifest.json` declares the pair as one logical market-neutral work
item, hosted on `AUDUSD.DWX` D1. Historical component-symbol Q02 rows exercised
the former inert P1 scaffold and are not evidence for this completed build.
