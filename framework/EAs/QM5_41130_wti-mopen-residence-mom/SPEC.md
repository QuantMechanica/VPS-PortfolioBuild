# QM5_41130_wti-mopen-residence-mom - Strategy Spec

**EA ID:** QM5_41130

**Slug:** `wti-mopen-residence-mom`

**Strategy ID:** `MOP-WTI-MOPEN-RESIDENCE-MOM-2026_S01`

**Source:** `MOP-WTI-MOPEN-RESIDENCE-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-23

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
reconstruct every close in the immediately completed month. Require 17 through
23 unique month-session closes plus the most recent older close from the
adjacent preceding calendar month.

Treat the older close `P` as immutable. Count each completed-month close
strictly above or below `P`; an exact tie remains in the denominator and counts
to neither side. For `n` month closes, require `ceil(3*n/4)`, implemented by
integer arithmetic as `(3*n+3)//4`, on one side. Independently sum every
chronological log return from `P` through the final month close and require it
to equal `ln(Q_last/P)` within `1e-10`. Buy for qualified above residence and a
positive endpoint; sell for qualified below residence and a negative endpoint.
All other valid and malformed states consume the month flat.

The position follows the residence-confirmed endpoint for one broker month,
using one fixed-risk budget and a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_history_bars_d1` | 45 | bounded completed-month D1 buffer |
| `strategy_min_month_sessions` | 17 | minimum month closes |
| `strategy_max_month_sessions` | 23 | maximum month closes |
| `strategy_residence_numerator` | 3 | locked residence numerator |
| `strategy_residence_denominator` | 4 | locked residence denominator |
| `strategy_numerical_tolerance` | 1e-10 | absolute endpoint-identity tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `strategy_deviation_points` | 20 | framework order-deviation contract |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

Every strategy parameter is locked for the Q02 baseline; no optimization
surface is approved.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411300000`.
- No signal, hedge, conversion, ratio, or external companion symbol exists.

## 4. Timeframe And Lifecycle

- Signal and execution timeframe: D1.
- Formation: the immediately completed broker-calendar month plus one adjacent
  older boundary close; current-month closes are excluded.
- Trigger: three-quarter fixed-open close residence plus endpoint agreement.
- Attempt: persist the broker `yyyymm` before history, signal, news, spread,
  quote, ATR, sizing, or order gates; never retry within the month.
- Hold: close on the first tick in a later normalized broker month, with forty
  elapsed days as stale repair only.

## 5. Expected Behaviour

- Approximately seven to eight completed WTI positions per full post-warm-up
  year; Q02 retires below five in any scored full year.
- Symmetric direct-WTI monthly structural continuation after fixed-open
  residence confirmation.
- Zero or one fixed-risk position and one consumed attempt per broker month.
- Direct WTI supplies physical-energy exposure outside the certified
  XAU/SP500/NDX/XNG book; unchanged Q09 alone owns realized correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-MOPEN-RESIDENCE-MOM-2026/source.md`.

The paper supplies WTI membership, own-return continuation lineage, and the
monthly formation/holding clock. Fixed-open daily close residence, its
three-quarter threshold, the continuous CFD, and the risk/execution choices
are disclosed QM hypotheses; no source or sibling economics transfer here.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 fixed-stop-risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio admission,
decorrelation claim, correlation waiver, portfolio-gate change, current-month
signal price, fitted threshold, magnitude weighting, external feed, retry,
scale-in, grid, martingale, pyramid, target, trail, break-even move, or partial
exit.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk, news, Friday, and
  strategy inputs.
- trade_entry: consumed month attempt, exact calendar package, fixed anchor,
  exhaustive strict counts, integer ceiling, endpoint identity, spread, quote,
  ATR, stop, and one fixed-risk request.
- trade_management: malformed-position repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-23 | approved source build | source approval `751e7cc4d`; card `3f66b973a`; governed magic `411300000` |
