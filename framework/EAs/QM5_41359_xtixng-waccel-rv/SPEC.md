# QM5_41359_xtixng-waccel-rv - Strategy Spec

**EA ID:** QM5_41359

**Slug:** `xtixng-waccel-rv`

**Strategy ID:** `AI-CODEX-XTIXNG-WACCEL-RV-20260906_S01`

**Source:** `AI-CODEX-XTIXNG-WACCEL-RV-20260906`

**Author:** Codex

**Last revised:** 2026-09-06

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
three consecutive completed synchronized XTI/XNG broker-week-end closes.
Compute the two adjacent, non-overlapping weekly changes in
`ln(XTI)-ln(XNG)`.

When both relative returns have the same strict sign and the newest absolute
move is strictly larger, fade that shared direction for one broker week. Two
positive moves open SELL XTI / BUY XNG; two negative moves open BUY XTI / SELL
XNG. Equality, opposed signs, zero, a non-larger newest move, malformed
history, or late attachment consumes the week flat. The paired package targets
equal absolute notionals, shares one fixed-risk budget, and carries frozen
per-leg ATR hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars_d1` | 30 | bounded D1 week-end buffer |
| `strategy_atr_period_d1` | 20 | completed-bar per-leg range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal absolute entry notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 10 | stale package repair |
| `strategy_xti_max_spread_points` | 1500 | XTI entry cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG entry cost guard |
| `qm_friday_close_enabled` | false | preserve complete next-week hold |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and first leg: exact `XTIUSD.DWX`, D1, slot 0.
- Companion and second leg: exact `XNGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41359_XTI_XNG_WACCEL_RV_D1`.
- The package is one two-leg research position; neither leg is standalone.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two adjacent completed broker-week relative returns from three
  synchronized completed week-end pairs.
- Trigger: strict same-sign agreement with strict newest acceleration.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately eight to eighteen completed packages per full post-warm-up
  year; Q02 retires below five.
- Symmetric, opposite-leg oil/gas relative reversion after accelerating weekly
  displacement.
- One fixed-risk package and one consumed attempt per broker week.
- Equal notional does not prove neutrality or decorrelation; Q09 alone owns
  realized portfolio correlation.

## 6. Source Citation

Villar, J. A. and Joutz, F. L. (2006), *The Relationship Between Crude Oil
and Natural Gas Prices*, U.S. Energy Information Administration; Ramberg,
D. J. and Parsons, J. E. (2012), "The Weak Tie Between Natural Gas and Oil
Prices," *The Energy Journal* 33(2), 13-35, DOI
`10.5547/01956574.33.2.2`.

Canonical bounded source packet:
`strategy-seeds/sources/AI-CODEX-XTIXNG-WACCEL-RV-20260906/source.md`.
The sources supply weak, time-varying oil/gas relationship evidence and
material adverse instability. The weekly same-sign acceleration fade is a
disclosed QM hypothesis; no source result transfers to this CFD build.

## 7. Risk Model And Scope

Q02 uses aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg has a frozen completed-bar ATR stop, and sizing
keeps combined normalized stop risk within the one package budget. Both news
axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, external feed, retry,
scale-in, grid, pyramid, target, trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-06 | approved build identity | source approval `b23ca8c8e2`; card approval `68bfc770e5`; active basket magics `c24c3d1cb7` |
