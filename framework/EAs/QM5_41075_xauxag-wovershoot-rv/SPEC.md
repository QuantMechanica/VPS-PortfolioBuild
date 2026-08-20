# QM5_41075_xauxag-wovershoot-rv - Strategy Spec

**EA ID:** QM5_41075

**Slug:** `xauxag-wovershoot-rv`

**Strategy ID:** `SCHWEIKERT-CME-XAUXAG-WOVERSHOOT-RV-2026_S01`

**Source:** `SCHWEIKERT-CME-XAUXAG-WOVERSHOOT-RV-2026`

**Author:** Codex

**Last revised:** 2026-08-20

## 1. Strategy Logic

On the first tradable `XAUUSD.DWX` D1 bar of a new broker week, reconstruct
three consecutive completed synchronized XAU/XAG broker-week-end closes.
Compute the two adjacent, non-overlapping weekly changes in
`ln(XAU)-ln(XAG)`.

When the relative returns have strict opposite signs and the newest absolute
move is strictly larger than the older move, fade the newest reversal for one
broker week. A dominant positive newest return opens SELL XAU / BUY XAG; a
dominant negative newest return opens BUY XAU / SELL XAG. Equality, same sign,
zero, a smaller newest move, malformed history, or late attachment consumes
the week flat. The paired package targets equal absolute notionals, shares one
fixed-risk budget, and carries frozen per-leg ATR hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars_d1` | 30 | bounded D1 week-end buffer |
| `strategy_atr_period_d1` | 20 | completed-bar per-leg risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal absolute entry notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 10 | stale package repair |
| `strategy_xau_max_spread_points` | 1500 | XAU entry cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG entry cost guard |
| `qm_friday_close_enabled` | false | preserve the complete next-week hold |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and first leg: exact `XAUUSD.DWX`, D1, slot 0.
- Companion and second leg: exact `XAGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41075_XAU_XAG_WOVERSHOOT_RV_D1`.
- The package is one two-leg research position; neither leg is a standalone
  strategy.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two adjacent completed broker-week relative returns from three
  synchronized completed week-end pairs.
- Trigger: strict sign reversal with strict newest absolute dominance at the
  new-week boundary.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately ten to twenty completed packages per full post-warm-up year;
  Q02 retires below five.
- Symmetric, opposite-leg gold/silver relative reversion after a dominant
  weekly reversal overshoot.
- One fixed-risk package and one consumed attempt per broker week.
- Mechanic and equal-notional construction do not prove neutrality or
  decorrelation; Q09 alone owns realized portfolio correlation.

## 6. Source Citation

Schweikert, K. (2018), "Are gold and silver cointegrated? New evidence from
quantile cointegrating regressions," *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`; and CME Group, "Gold & Silver
Ratio Spread."

Canonical bounded source packet:
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WOVERSHOOT-RV-2026/source.md`.

The sources supply state-dependent gold/silver relationship and intermarket
carrier lineage. The weekly opposite-sign newest-dominance fade is a disclosed
QM hypothesis; no source result transfers to this CFD implementation.

## 7. Risk Model And Scope

Q02 uses aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg has a frozen completed-bar ATR stop, and sizing
must keep combined normalized stop risk within the one package budget. Both
news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, external feed, retry,
scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-20 | approved build-directory identity | source approval `9f30c75c8`; EA ID `ecc559ee0`; active basket magics `fe825090c` |
| v2 | 2026-08-20 | Q01 build complete | deterministic paired EA; 9 reference tests; strict compile/build and static P1 PASS |
| v3 | 2026-08-20 | paced Q02 capacity preflight | exact target query found no Q02 row; no enqueue because seven factory terminals and sampled host CPU reached the binding ceilings |
