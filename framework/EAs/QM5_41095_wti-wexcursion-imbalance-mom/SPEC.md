# QM5_41095_wti-wexcursion-imbalance-mom - Strategy Spec

**EA ID:** QM5_41095

**Slug:** `wti-wexcursion-imbalance-mom`

**Strategy ID:** `MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026_S01`

**Source:** `MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, aggregate the
OHLC of the exact immediately completed Monday-anchored broker week. The
package must contain three to five unique completed sessions under one uniform
energy-label convention.

Define `U = week_high - week_open` and `D = week_open - week_low`. Buy only
when `U > 2*D` and `week_close > week_open`. Sell only when `D > 2*U` and
`week_close < week_open`. Ratio equality, close/open equality,
excursion/settlement disagreement, incomplete packages, nonadjacent anchors,
and malformed history consume the week flat. Hold one broker week with fixed-
dollar risk and a frozen completed-bar ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_label_offset_seconds` | 86400 | uniform raw-to-energy-session label offset |
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 16 | bounded D1 weekly OHLC buffer |
| `strategy_required_weeks` | 1 | exact immediately completed package |
| `strategy_min_week_bars` | 3 | minimum sessions in the package |
| `strategy_max_week_bars` | 5 | maximum sessions in the package |
| `strategy_excursion_multiplier` | 2 | strict dominant/opposing excursion multiple |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-week ownership |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are frozen for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `410950000`.
- No signal, hedge, conversion, ratio, or companion symbol exists.

## 4. Timeframe And Lifecycle

- Signal and execution timeframe: D1.
- Formation: exact immediately completed broker-week OHLC; current-week price
  contributes no signal value.
- Trigger: strict open-centred two-to-one directional excursion plus matching
  final settlement sign.
- Hold: until the first tick of the next broker week, with ten-day stale repair.
- Attempt: persist the current Monday anchor before every fallible signal or
  execution gate; never retry within that week.

## 5. Expected Behaviour

- Approximately eight to twenty completed WTI positions per full post-warm-up
  year; Q02 owns the binding activity verdict.
- Symmetric direct-WTI weekly structural continuation after a one-sided
  completed auction.
- One fixed-risk position and one consumed attempt per broker week.
- A different carrier and mechanic do not establish decorrelation; Q09 owns
  the realized portfolio-correlation verdict.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026/source.md`.

The paper supplies own-price continuation lineage and includes WTI. Weekly
OHLC aggregation and the strict open-centred excursion condition are disclosed
QM hypotheses; no paper result transfers to this continuous-CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy manifest, portfolio admission, correlation waiver,
portfolio-gate change, parent-week comparison, current-week signal price,
body-share gate, wick gate, range rank, close-location threshold, return
channel, external feed, retry, scale-in, grid, martingale, pyramid, target,
trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `0f68d9807`; source packet `12e5ede4e`; EA-ID reservation `07d849d91`; Q00 card `98f19dfad`; governed magic `410950000` |
| v1 | 2026-08-21 | source-only build and capacity handoff | implementation commit `b74533ddb`; 12 reference checks and guardrails PASS; governed compile `c88b39a4-1220-4894-a2c3-9818651c763e` pending under rollout hold; Q02 not enqueued after CPU reached 100% |
