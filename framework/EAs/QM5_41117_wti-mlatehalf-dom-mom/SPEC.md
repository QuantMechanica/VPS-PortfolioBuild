# QM5_41117_wti-mlatehalf-dom-mom - Strategy Spec

**EA ID:** QM5_41117

**Slug:** `wti-mlatehalf-dom-mom`

**Strategy ID:** `MOP-WTI-MLATEHALF-DOM-MOM-2026_S01`

**Source:** `MOP-WTI-MLATEHALF-DOM-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-22

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
reconstruct the two immediately preceding consecutive completed months. Each
must contain 17 through 23 unique completed sessions under one uniform
energy-label convention.

Use the parent month's chronological final close as the anchor and order all
newest-month closes chronologically. With `n` newest-month sessions, set
`k=floor(n/2)`. The first cumulative leg is
`log(C[k-1]/parent_final)` and the second is
`log(C[n-1]/C[k-1])`. Trade only when the second leg's absolute return is
strictly larger than the first leg's. Buy when the second leg is positive and
sell when it is negative. Equality, a zero second leg, non-dominance, invalid
split, incomplete history, or malformed state consumes the month flat.

The shared midpoint is an endpoint and anchor, not a duplicated return. The
two legs therefore partition every adjacent completed close return from the
parent final close through the newest final close exactly once. The position
follows the late leg's direction for one broker month, using one fixed-risk
budget and a frozen ATR hard stop. Half-sign agreement is not required.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_history_bars_d1` | 70 | bounded two-month D1 close buffer |
| `strategy_min_month_sessions` | 17 | minimum sessions per package |
| `strategy_max_month_sessions` | 23 | maximum sessions per package |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline. The floor split,
strict magnitude comparison, equality handling, direction map, and hold are
not parameters.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411170000` (governed slot-0 allocation for `XTIUSD.DWX`).
- No signal, hedge, conversion, ratio, or external companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two immediately completed consecutive broker-calendar months.
- Path: parent final close to every chronological newest-month close.
- Trigger: the late half's absolute return strictly dominates the early half;
  direction is the late half's sign.
- Hold: until the first tick of the next normalized broker month, with a
  forty-day stale repair.

## 5. Expected Behaviour

- Approximately five to eight completed WTI positions per full post-warm-up
  year; Q02 retires below five.
- Symmetric direct-WTI monthly structural continuation after strict late-half
  path dominance.
- One fixed-risk position and one consumed attempt per broker month.
- Direct WTI supplies physical-energy exposure absent from the certified
  XAU/SP500/NDX/XNG book; Q09 alone owns realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-MLATEHALF-DOM-MOM-2026/source.md`.

The paper supplies monthly own-price continuation lineage, one-month holding
tests, and explicit WTI membership. Within-month late-half dominance is a
disclosed QM hypothesis; no paper or sibling result transfers to this
continuous-CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes and Friday
close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or `T_Live` manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, current-month signal price,
alternate split or magnitude comparison, individual daily-sign vote,
external feed, retry, scale-in, grid, martingale, pyramid, target, trail,
break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-22 | approved build-directory identity | source approval `30a262765`; EA-ID reservation `ac8cd835a`; Q00 card `7fba457e9`; governed magic `411170000` at `c2b7d5d0e` |
