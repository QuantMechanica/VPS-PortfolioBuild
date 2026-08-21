# QM5_41084_wti-wdaybreadth-mom - Strategy Spec

**EA ID:** QM5_41084

**Slug:** `wti-wdaybreadth-mom`

**Strategy ID:** `MOP-WTI-WDAYBREADTH4-MOM-2026_S01`

**Source:** `MOP-WTI-WDAYBREADTH4-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
the parent completed week's final close and exactly five chronological closes
from the immediately completed broker week. Compute the five adjacent daily
close-to-close log returns and the full-week net return.

Buy only when at least four of five daily returns are strictly positive and
the weekly net return is strictly positive. Sell only when at least four are
strictly negative and the weekly net is strictly negative. Zero component
returns count toward neither side. A non-five-session week, disagreement,
equality, malformed history, or late attachment consumes the week flat. The
position uses one fixed-risk budget and a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 weekly-session buffer |
| `strategy_required_sessions` | 5 | exact newest completed week session count |
| `strategy_min_same_sign` | 4 | strict daily-sign breadth threshold |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve the complete next-week hold |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Magic: `410840000`, after governed allocation.
- No signal, hedge, conversion, or external companion symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: five adjacent daily return intervals spanning one exact
  five-session completed broker week.
- Trigger: at least four component returns share one strict sign and the
  complete weekly net return has that same strict sign.
- Direction: the agreeing daily-sign breadth and weekly-net sign.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately ten to twenty completed positions per full post-warm-up year;
  Q02 retires below five.
- Symmetric WTI continuation after broad within-week directional participation.
- One fixed-risk position and one consumed attempt per broker week.
- The WTI carrier and mechanic do not prove decorrelation; Q09 alone owns
  realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WDAYBREADTH4-MOM-2026/source.md`.

The source supplies own-return-sign continuation and WTI membership. The
weekly horizon, five daily intervals, four-of-five breadth threshold, and
weekly-net conjunction are disclosed QM timing hypotheses; no source result
transfers to this CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
The position has a frozen completed-bar ATR stop. Both news axes and Friday
close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, external feed, retry,
scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `8ca5ed7fa`; deterministic registry reservation `d34837b3e`; G0 approval `8e002c82e`; magic allocation `bd3b1d83a` |
| v1-build | 2026-08-21 | deterministic implementation and Q01 validation | 10-test reference suite; strict compile/build PASS; static P1 PASS |
| v1-q02-capacity | 2026-08-21 | paced Q02 preflight stopped at terminal-count ceiling | one fresh target-only row found; no enqueue mutation; evidence in `docs/ops/evidence/2026-08-21_qm5_41084_wti_weekly_daily_sign_breadth_q01_q02_cpu_ceiling_stop.md` |
