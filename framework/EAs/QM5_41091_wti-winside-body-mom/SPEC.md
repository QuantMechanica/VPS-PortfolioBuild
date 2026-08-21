# QM5_41091_wti-winside-body-mom - Strategy Spec

**EA ID:** QM5_41091

**Slug:** `wti-winside-body-mom`

**Strategy ID:** `MOP-WTI-WINSIDE-BODY-MOM-2026_S01`

**Source:** `MOP-WTI-WINSIDE-BODY-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, aggregate the
OHLC of the two immediately preceding consecutive completed Monday-anchored
broker weeks. Each package must contain three to five unique completed
sessions under one uniform energy-label convention.

Require the newest completed week's high to be strictly below its parent's
high and its low to be strictly above its parent's low. Buy when that contained
week's final close is strictly above its first-session open; sell when it is
strictly below. Equal endpoints, equal open/close, non-inside geometry,
incomplete packages, and malformed history consume the week flat. Hold one
broker week with fixed-dollar risk and a frozen completed-bar ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_label_offset_seconds` | 86400 | uniform raw-to-energy-session label offset |
| `strategy_entry_lateness_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 weekly OHLC buffer |
| `strategy_required_weeks` | 2 | exact consecutive completed packages |
| `strategy_min_week_bars` | 3 | minimum sessions per package |
| `strategy_max_week_bars` | 5 | maximum sessions per package |
| `strategy_atr_period` | 20 | completed-bar risk range |
| `strategy_atr_stop_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_calendar_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-week ownership |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are frozen for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `410910000`.
- No signal, hedge, conversion, ratio, or companion symbol exists.

## 4. Timeframe And Lifecycle

- Signal and execution timeframe: D1.
- Formation: two immediately completed consecutive broker-week OHLC packages;
  the current week contributes no signal price.
- Trigger: strict full containment plus strict contained-week open-to-close
  body direction.
- Hold: until the first tick of the next broker week, with ten-day stale repair.
- Attempt: persist the current Monday anchor before every fallible signal or
  execution gate; never retry within that week.

## 5. Expected Behaviour

- Approximately six to fifteen completed WTI positions per full post-warm-up
  year; Q02 owns the binding activity verdict.
- Symmetric direct-WTI weekly structural continuation after compression.
- One fixed-risk position and one consumed attempt per broker week.
- A different carrier and mechanic do not establish decorrelation; Q09 owns
  the realized portfolio-correlation verdict.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WINSIDE-BODY-MOM-2026/source.md`.

The paper supplies own-price continuation lineage and includes WTI. Strict
weekly containment and contained-week body direction are disclosed QM
hypotheses; no paper result transfers to this standalone continuous-CFD
implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy manifest, portfolio admission, correlation waiver,
portfolio-gate change, current-week signal price, breakout, parent-close
return, midpoint, close-location threshold, external feed, retry, scale-in,
grid, martingale, pyramid, target, trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `9f47d0a0d`; source packet `70ab22cd8`; EA-ID reservation `df65b49a4`; Q00 card `8ba0e1d6a`; governed magic `410910000` |
| v1 | 2026-08-21 | governed V5 implementation | strict compile 0/0; V5 build check PASS; 13 reference checks PASS; static P1 PASS |
