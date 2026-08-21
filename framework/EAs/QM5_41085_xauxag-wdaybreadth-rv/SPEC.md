# QM5_41085_xauxag-wdaybreadth-rv - Strategy Spec

**EA ID:** QM5_41085

**Slug:** `xauxag-wdaybreadth-rv`

**Strategy ID:** `SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026_S01`

**Source:** `SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XAUUSD.DWX` D1 bar of a new broker week, reconstruct
the final synchronized XAU/XAG close pair from the parent week plus exactly
five synchronized closes from the immediately completed week. Compute the
five adjacent gold-minus-silver relative log returns and the full-week
relative return.

When at least four of five relative daily returns are strictly positive and
the weekly net is strictly positive, sell gold and buy silver. When at least
four are strictly negative and the weekly net is strictly negative, buy gold
and sell silver. Zero components count toward neither side. A non-five-session
week, disagreement, equality, malformed history, or late attachment consumes
the week flat. The equal-notional two-leg package shares one fixed-risk budget
and uses frozen per-leg ATR hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion leg |
| `strategy_history_bars_d1` | 30 | bounded synchronized D1 endpoint buffer |
| `strategy_required_sessions` | 5 | exact newest completed week session count |
| `strategy_min_same_sign` | 4 | strict relative daily-sign breadth threshold |
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard-stop distance |
| `strategy_notional_ratio` | 1.0 | target absolute XAU/XAG notional ratio |
| `strategy_max_notional_mismatch_pct` | 20.0 | fail-closed package tolerance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_xau_max_spread_points` | 1500 | host entry cost guard |
| `strategy_xag_max_spread_points` | 500 | companion entry cost guard |
| `strategy_deviation_points` | 20 | basket order deviation cap |
| `qm_friday_close_enabled` | false | preserve the complete next-week hold |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host: exact `XAUUSD.DWX`, D1, slot 0.
- Companion: exact `XAGUSD.DWX`, D1, slot 1.
- Logical basket: `QM5_41085_XAU_XAG_WDAYBREADTH_RV_D1`.
- Magics: deterministic registry allocation follows approved-card creation.
- Neither leg is a standalone strategy; Q02 evaluates combined package PnL.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: parent-week final synchronized close plus five exact synchronized
  sessions in the immediately completed week.
- Trigger: at least four component relative returns share one strict sign and
  the complete weekly relative return has that same strict sign.
- Direction: inverse of the agreeing daily-breadth and weekly-net sign.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately ten to twenty completed packages per full post-warm-up year;
  Q02 retires below five.
- Symmetric gold/silver relative-value reversion after broad within-week
  directional participation in the ratio.
- One aggregate fixed-risk package and one consumed attempt per broker week.
- Opposite equal-notional legs seek to remove common metal direction, but Q09
  alone owns any realized portfolio-correlation or neutrality conclusion.

## 6. Source Citation

Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence from
quantile cointegrating regressions," *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`; CME Group, "Gold & Silver Ratio Spread."

Canonical bounded source packet:
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026/source.md`.

The sources supply a state-dependent gold/silver relationship and an
intermarket-spread carrier. The exact week, daily-sign breadth, net
confirmation, contrarian side, and lifecycle are disclosed QM hypotheses; no
source result transfers to this CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` across
the whole package. Each leg has a frozen completed-bar ATR stop. Both news
axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, external feed, retry,
scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `25a9c6356`; registry reservation `648639751`; G0 approval `a28b27bad`; magic allocation `921bdc457` |
| v1-build | 2026-08-21 | deterministic implementation and Q01 validation | 10-test reference suite; strict compile/build PASS; static P1 PASS |
| v2-q02-capacity | 2026-08-21 | paced Q02 handoff | target-only preview selected one fresh row; enqueue withheld at the binding research-terminal ceiling |
