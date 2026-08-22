# QM5_41107_wti-minside-body-mom - Strategy Spec

**EA ID:** QM5_41107

**Slug:** `wti-minside-body-mom`

**Strategy ID:** `MOP-WTI-MINSIDE-BODY-MOM-2026_S01`

**Source:** `MOP-WTI-MINSIDE-BODY-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-22

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
aggregate the two immediately preceding consecutive completed months. Each
month must contain 17 through 23 unique completed sessions under one uniform
energy-label convention.

Require the newest completed month's aggregate high to be strictly below its
parent's high and its aggregate low to be strictly above its parent's low.
Buy when that strictly contained month closes above its own first open; sell
when it closes below its own first open. Equality, non-inside, incomplete, or
malformed states consume the month flat. The position follows the contained
monthly body for one broker month, using one fixed-risk budget and a frozen
ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_history_bars_d1` | 70 | bounded two-month D1 OHLC buffer |
| `strategy_min_month_sessions` | 17 | minimum sessions per package |
| `strategy_max_month_sessions` | 23 | maximum sessions per package |
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
- Magic: `411070000` (governed slot-0 allocation for `XTIUSD.DWX`).
- No signal, hedge, conversion, ratio, or external companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: the two immediately completed consecutive broker-calendar month
  OHLC packages.
- Trigger: strict full containment plus the contained month's own body sign.
- Hold: until the first tick of the next normalized broker month, with a
  forty-day stale repair.

## 5. Expected Behaviour

- Approximately two to six completed WTI positions per full post-warm-up
  year; Q02 retires below two.
- Symmetric direct-WTI monthly structural continuation after compression.
- One fixed-risk position and one consumed attempt per broker month.
- The direct-WTI carrier adds exposure absent from the certified
  XAU/SP500/NDX/XNG book; Q09 alone owns realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-MINSIDE-BODY-MOM-2026/source.md`.

The paper supplies monthly own-price continuation lineage, one-month holding
tests, and explicit WTI membership. Strict monthly containment and the
contained-month body state are disclosed QM hypotheses; no paper or sibling
result transfers to this continuous-CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or `T_Live` manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, current-month signal price,
current-month breakout, external feed, retry, scale-in, grid, martingale,
pyramid, target, trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-22 | approved build-directory identity | source approval `dca99885d`; EA-ID reservation `5746329a5`; Q00 card `8e62b338a`; governed magic `411070000` |
