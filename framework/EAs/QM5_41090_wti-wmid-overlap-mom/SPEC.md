# QM5_41090_wti-wmid-overlap-mom - Strategy Spec

**EA ID:** QM5_41090

**Slug:** `wti-wmid-overlap-mom`

**Strategy ID:** `MOP-WTI-WMID-OVERLAP-MOM-2026_S01`

**Source:** `MOP-WTI-WMID-OVERLAP-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, aggregate the
high and low of the two immediately preceding consecutive completed
Monday-anchored broker weeks. Each package must contain three to five unique
completed sessions under one uniform energy-label convention.

Require the two weekly price intervals to share a strictly positive overlap.
Compute each center as `low + 0.5 * (high - low)`. Buy when the newest center
is strictly higher; sell when it is strictly lower. Equal centers, touch-only
or disjoint ranges, incomplete packages, and malformed high/low geometry
consume the week flat. Hold one broker week with fixed-dollar risk and a
frozen completed-bar ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 weekly high/low buffer |
| `strategy_required_weeks` | 2 | exact consecutive completed packages |
| `strategy_min_week_bars` | 3 | minimum sessions per package |
| `strategy_max_week_bars` | 5 | maximum sessions per package |
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
- Magic: `410900000`.
- No signal, hedge, conversion, ratio, or companion symbol exists.

## 4. Timeframe And Lifecycle

- Signal and execution timeframe: D1.
- Formation: two immediately completed consecutive broker-week high/low
  packages; the current week contributes no signal price.
- Trigger: strict positive interval overlap plus strict weekly-midpoint drift.
- Hold: until the first tick of the next broker week, with ten-day stale repair.
- Attempt: persist the current Monday anchor before every fallible signal or
  execution gate; never retry within that week.

## 5. Expected Behaviour

- Approximately twenty to forty completed WTI positions per full post-warm-up
  year; Q02 retires below five.
- Symmetric direct-WTI weekly structural continuation.
- One fixed-risk position and one consumed attempt per broker week.
- A different carrier and mechanic do not establish decorrelation; Q09 owns
  the realized portfolio-correlation verdict.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WMID-OVERLAP-MOM-2026/source.md`.

The paper supplies own-price continuation lineage and includes WTI. The weekly
auction-midpoint and overlap state is a disclosed QM hypothesis; no paper
result transfers to this standalone continuous-CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy manifest, portfolio admission, correlation waiver,
portfolio-gate change, current-week signal price, open/close signal input,
external feed, retry, scale-in, grid, martingale, pyramid, target, trail,
break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `1cd9eafe8`; EA-ID reservation `baca6a1bf`; G0 card `84da6d784`; governed magic `410900000` |
