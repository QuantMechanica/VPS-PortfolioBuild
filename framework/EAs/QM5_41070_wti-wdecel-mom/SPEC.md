# QM5_41070_wti-wdecel-mom - Strategy Spec

EA ID: `QM5_41070`

Slug: `wti-wdecel-mom`

Strategy ID: `MOP-WTI-WDECEL-MOM-2026_S01`

Source: `MOP-WTI-WDECEL-MOM-2026`

Author: Codex

Last revised: 2026-08-20

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
three consecutive completed broker-week-end closes. Compute the two adjacent,
non-overlapping weekly log returns.

When both returns have the same strict sign and the newest absolute move is
strictly smaller than the older move, follow their shared direction for one
broker week. Two positive decelerating returns buy WTI; two negative
decelerating returns sell WTI. Equality, sign opposition, zero,
non-deceleration, malformed history, or late attachment consumes the week
flat. The position uses one fixed-risk budget and a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 week-end buffer |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve the complete next-week hold |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Magic: `410700000`, after governed allocation.
- No signal, hedge, conversion, or external companion symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two adjacent completed broker-week returns from three completed
  week-end closes.
- Trigger: strict same-sign movement with strict absolute deceleration at the
  new-week boundary.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately eight to eighteen completed positions per full post-warm-up
  year; Q02 retires below five.
- Symmetric WTI trend continuation after a weakening two-week move.
- One fixed-risk position and one consumed attempt per broker week.
- The WTI carrier and mechanic do not prove decorrelation; Q09 alone owns
  realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WDECEL-MOM-2026/source.md`.

The source supplies own-return-sign continuation and WTI membership. The
weekly horizon and same-sign deceleration condition are disclosed QM timing
hypotheses; no source result transfers to this CFD implementation.

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
| v0 | 2026-08-20 | approved build-directory identity | source approval `82b48303d`; deterministic registry reservation in the commit containing this spec |
| v1-card | 2026-08-20 | G0-approved execution contract | `strategy-seeds/cards/approved/QM5_41070_wti-wdecel-mom_card.md` |
| v1-build | 2026-08-20 | deterministic implementation and Q01 validation | 9-test reference suite; strict compile/build PASS; static P1 PASS |
| v1-q02-capacity | 2026-08-20 | paced Q02 handoff | target-only dry run selected one row; apply withheld at eight active research terminals and 99.99% average host CPU |
