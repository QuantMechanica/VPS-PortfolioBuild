# QM5_41082_wti-wrunbreak-dom - Strategy Spec

EA ID: `QM5_41082`

Slug: `wti-wrunbreak-dom`

Strategy ID: `MOP-WTI-WRUNBREAK-DOM-2026_S01`

Source: `MOP-WTI-WRUNBREAK-DOM-2026`

Author: Codex

Last revised: 2026-08-21

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
four consecutive completed broker-week-end closes. Compute the three adjacent,
nonoverlapping weekly log returns in chronological order.

Trade only when the two older returns have the same strict sign, the newest
return has the opposite strict sign, and the newest absolute move is strictly
larger than the sum of both older absolute moves. Two positive weeks followed
by a dominant negative week sell WTI; two negative weeks followed by a
dominant positive week buy WTI. This combined-erasure rule guarantees the
cumulative three-week return has the newest sign. Equality, zero, another
path, failed dominance, malformed history, or late attachment consumes the
week flat. The position uses one fixed-risk budget and a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 40 | bounded D1 week-end buffer |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve the complete next-week hold |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Magic: `410820000`, after governed allocation.
- No signal, hedge, conversion, or external companion symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: three adjacent completed broker-week returns from four completed
  week-end closes.
- Trigger: same-sign two-week run followed by one opposed newest return whose
  absolute move strictly dominates the two older returns combined.
- Direction: the dominant newest sign, equivalently the cumulative three-
  week-return sign.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately two to six completed positions per full post-warm-up year;
  Q02 retires below two.
- Symmetric WTI continuation only after one completed opposed week strictly
  erases a two-week same-sign run.
- One fixed-risk position and one consumed attempt per broker week.
- The WTI carrier and mechanic do not prove decorrelation; Q09 alone owns
  realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WRUNBREAK-DOM-2026/source.md`.

The source supplies own-return-sign continuation and WTI membership. The
weekly horizon, three-week path, and strict combined-erasure condition are
disclosed QM timing hypotheses; no source result transfers to this CFD
implementation.

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
| v0 | 2026-08-21 | approved build-directory identity | source approval `f02d2a56e`; deterministic registry reservation and G0 card |
