# QM5_41069_wti-wpull-trend - Strategy Spec

**EA ID:** QM5_41069

**Slug:** `wti-wpull-trend`

**Strategy ID:** `MOP-WTI-WPULL-TREND-2026_S01`

**Source:** `MOP-WTI-WPULL-TREND-2026` (see `strategy-seeds/sources/MOP-WTI-WPULL-TREND-2026/`)

**Author of this spec:** Codex

**Last revised:** 2026-08-20

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
three consecutive completed broker-week-end closes. Compute the two adjacent,
non-overlapping weekly log returns.

Trade only when the returns have strict opposite signs and the newest
absolute move is strictly smaller than the older move. Treat the newest week
as a pullback: an older positive week followed by a smaller negative week buys
WTI; an older negative week followed by a smaller positive week sells WTI.
Equality, same signs, zero, a non-smaller newest move, malformed history, or
late attachment consumes the week flat. The position uses one fixed-risk
budget and a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 week-end buffer |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Magic: `410690000`, after governed allocation.
- No signal, hedge, conversion, or external companion symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two adjacent completed broker-week returns from three completed
  week-end closes.
- Trigger: strict sign opposition with a strictly smaller newest move at the
  new-week boundary.
- Direction: older completed-week sign.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately eight to eighteen completed positions per full post-warm-up
  year; Q02 retires below five.
- Symmetric WTI trend re-entry after a smaller completed-week pullback.
- One fixed-risk position and one consumed attempt per broker week.
- The WTI carrier and mechanic do not prove decorrelation; Q09 alone owns
  realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WPULL-TREND-2026/source.md`.

The source supplies own-return-sign continuation and WTI membership. The
weekly horizon, opposed-sign pullback, strict relative-magnitude condition,
and older-sign re-entry are disclosed QM timing hypotheses; no source result
transfers to this CFD implementation.

## 7. Risk Model

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
| v0 | 2026-08-20 | approved build-directory identity | source approval `c655c2d6a`; EA registry `af2e427b6`; magic registry `734c0f565` |
| v1-card | 2026-08-20 | G0-approved execution contract | `strategy-seeds/cards/approved/QM5_41069_wti-wpull-trend_card.md` |
| v1-build | 2026-08-20 | deterministic implementation and Q01 validation | 10-test reference suite; strict compile/build PASS; static P1 PASS |
