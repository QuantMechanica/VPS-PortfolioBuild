# QM5_41122_wti-mextreme-sequence-mom - Strategy Spec

**EA ID:** QM5_41122

**Slug:** `wti-mextreme-sequence-mom`

**Strategy ID:** `MOP-WTI-MEXTREME-SEQUENCE-MOM-2026_S01`

**Source:** `MOP-WTI-MEXTREME-SEQUENCE-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-23

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new raw broker-calendar
month, reconstruct the immediately completed month from 17 through 23 valid
completed D1 sessions. Require one adjacent older-month bar to prove that the
package is complete, and require exactly one session carrying the aggregate
monthly high and exactly one carrying the aggregate monthly low.

Let `O` be the first chronological session open, `C` the final session close,
`iH` the unique aggregate-high session index, and `iL` the unique
aggregate-low session index. Buy only when `iL < iH` and `C > O`. Sell only
when `iH < iL` and `C < O`. Repeated extrema, same-session extrema, equality,
order/body disagreement, incomplete history, or malformed OHLC consumes the
month flat.

The position follows that completed-month auction path through the next raw
broker month. It uses one fixed-risk budget, a frozen ATR hard stop, no
take-profit, and one durable attempt per month.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_history_bars_d1` | 45 | bounded completed-month OHLC buffer |
| `strategy_min_month_sessions` | 17 | minimum sessions in the package |
| `strategy_max_month_sessions` | 23 | maximum sessions in the package |
| `strategy_require_unique_extremes` | true | repeated aggregate extrema stay flat |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All parameters are locked for the Q02 baseline. Extreme order, body
agreement, ambiguity handling, raw month labels, attempt timing, and hold are
not optimization surfaces.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411220000` (governed slot-0 allocation for `XTIUSD.DWX`).
- No signal, hedge, conversion, ratio, or external companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: the exact immediately completed raw broker-calendar month.
- Trigger: unique aggregate-extreme chronology plus matching first-open to
  final-close body sign.
- Hold: until the first tick of the next raw broker month, with a forty-day
  stale repair.

## 5. Expected Behaviour

- Approximately six to ten completed WTI positions per full post-warm-up
  year; Q02 retires below five in any scored full year.
- Symmetric direct-WTI monthly structural continuation after an unambiguous
  auction path and body-sign agreement.
- One fixed-risk position and one consumed attempt per broker month.
- WTI supplies direct physical-energy exposure distinct from the certified
  XAU/SP500/NDX/XNG carriers; Q09 alone owns realized decorrelation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-MEXTREME-SEQUENCE-MOM-2026/source.md`.

The paper supplies monthly own-price continuation lineage, a one-month
formation/holding test, and explicit WTI membership. Monthly extreme-session
chronology, uniqueness, body agreement, continuous-CFD execution, and all
risk controls are disclosed QM interpretations. No source performance or
correlation statistic transfers to this implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses one frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes and Friday
close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, current-month signal OHLC,
parent-month comparison, retry, scale-in, grid, martingale, pyramid, target,
trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-23 | approved build-directory identity | source approval `d066ac822`; EA-ID reservation `1d5d4a383`; approved card `b31560f08`; governed magic `411220000` |
