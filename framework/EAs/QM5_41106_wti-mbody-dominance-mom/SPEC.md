# QM5_41106_wti-mbody-dominance-mom - Strategy Spec

**EA ID:** QM5_41106

**Slug:** `wti-mbody-dominance-mom`

**Strategy ID:** `MOP-WTI-MBODY-DOMINANCE-MOM-2026_S01`

**Source:** `MOP-WTI-MBODY-DOMINANCE-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-22

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
aggregate the immediately preceding completed month. It must contain 17
through 23 unique completed sessions under one uniform energy-label
convention.

Buy when the completed month's open-to-close real body is positive and
strictly greater than one half of its aggregate high-low range. Sell when the
body is negative and passes the same strict majority test. Threshold equality,
zero body, incomplete history, or malformed geometry consumes the month flat.
The position follows the completed body direction for one broker month, using
one fixed-risk budget and a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_history_bars_d1` | 40 | bounded D1 monthly-OHLC buffer |
| `strategy_min_month_sessions` | 17 | minimum sessions in the completed month |
| `strategy_max_month_sessions` | 23 | maximum sessions in the completed month |
| `strategy_body_numerator` | 2 | exact integer left side of the strict ratio |
| `strategy_range_multiplier` | 1 | exact integer right side of the strict ratio |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411060000` (governed slot-0 allocation for `XTIUSD.DWX`).
- No signal, hedge, conversion, ratio, or external companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: the immediately completed broker-calendar month's first open,
  final close, aggregate high, and aggregate low.
- Trigger: strict `2*abs(close-open)>high-low`, with own-body direction.
- Hold: until the first tick of the next normalized broker month, with a
  forty-day stale repair.

## 5. Expected Behaviour

- Approximately five to nine completed WTI positions per full post-warm-up
  year; Q02 retires below five.
- Symmetric direct-WTI monthly structural continuation.
- One fixed-risk position and one consumed attempt per broker month.
- The direct-WTI carrier adds exposure absent from the certified
  XAU/SP500/NDX/XNG book; Q09 alone owns realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-MBODY-DOMINANCE-MOM-2026/source.md`.

The paper supplies monthly own-price continuation lineage, one-month holding
tests, and explicit WTI membership. Completed-month OHLC aggregation and the
strict majority-body state are disclosed QM hypotheses; no paper or sibling
result transfers to this continuous-CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or `T_Live` manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, current-month signal price,
external feed, retry, scale-in, grid, martingale, pyramid, target, trail,
break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-22 | approved build-directory identity | source approval `e0eb12c16`; EA-ID reservation `9fb6f1548`; Q00 card `813b6dea4`; governed magic `411060000` |
