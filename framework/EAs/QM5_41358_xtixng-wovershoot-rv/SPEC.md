# QM5_41358_xtixng-wovershoot-rv - Strategy Spec

**EA ID:** QM5_41358

**Slug:** `xtixng-wovershoot-rv`

**Strategy ID:** `AI-CODEX-XTIXNG-WOVERSHOOT-RV-20260906_S01`

**Source:** `AI-CODEX-XTIXNG-WOVERSHOOT-RV-20260906`

**Author:** Codex

**Last revised:** 2026-09-06

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
three consecutive completed synchronized XTI/XNG broker-week-end closes.
Compute the two adjacent, non-overlapping weekly changes in
`ln(XTI)-ln(XNG)`.

When the relative returns have strict opposite signs and the newest absolute
move is strictly larger than the older move, fade the newest reversal for one
broker week. A dominant positive newest return opens SELL XTI / BUY XNG; a
dominant negative newest return opens BUY XTI / SELL XNG. Equality, same sign,
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
| `strategy_xti_max_spread_points` | 1500 | XTI entry cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG entry cost guard |
| `qm_friday_close_enabled` | false | preserve the complete next-week hold |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and first leg: exact `XTIUSD.DWX`, D1, slot 0.
- Companion and second leg: exact `XNGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41358_XTI_XNG_WOVERSHOOT_RV_D1`.
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
- Symmetric, opposite-leg oil/gas relative reversion after a dominant
  weekly reversal overshoot.
- One fixed-risk package and one consumed attempt per broker week.
- Mechanic and equal-notional construction do not prove neutrality or
  decorrelation; Q09 alone owns realized portfolio correlation.

## 6. Source Citation

Villar, J. A. and Joutz, F. L. (2006), *The Relationship Between Crude Oil
and Natural Gas Prices*, U.S. Energy Information Administration; Ramberg,
D. J. and Parsons, J. E. (2012), "The Weak Tie Between Natural Gas and Oil
Prices," *The Energy Journal* 33(2), 13-35, DOI
`10.5547/01956574.33.2.2`.

Canonical bounded source packet:
`strategy-seeds/sources/AI-CODEX-XTIXNG-WOVERSHOOT-RV-20260906/source.md`.

The sources supply weak, time-varying oil/gas relationship evidence and
material adverse instability. The weekly opposite-sign newest-dominance fade
is a disclosed QM hypothesis; no source result transfers to this CFD
implementation.

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
| v1 | 2026-09-06 | approved build-directory identity | source approval `5f191d7cd4`; EA ID/card `1c7de04746`; active basket magics `512d126638` |

