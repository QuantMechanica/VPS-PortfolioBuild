# QM5_41101_xng-wrange-migrate-mom - Strategy Spec

**EA ID:** QM5_41101

**Slug:** `xng-wrange-migrate-mom`

**Strategy ID:** `MOP-XNG-WRANGE-MIGRATE-MOM-2026_S01`

**Source:** `MOP-XNG-WRANGE-MIGRATE-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-22

## 1. Strategy Logic

On the first tradable `XNGUSD.DWX` D1 bar of a new broker week, aggregate the
two immediately preceding consecutive completed Monday-anchored broker weeks.
Each week must contain three to five unique completed sessions under one
uniform energy-label convention.

Buy when the newest completed week has both a strict higher high and a strict
higher low than its parent. Sell when it has both a strict lower high and a
strict lower low. Equality, inside, outside, mixed, incomplete, or malformed
states consume the week flat. The position follows the completed auction-
range migration for one broker week, using one fixed-risk budget and a frozen
ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 weekly-OHLC buffer |
| `strategy_required_weeks` | 2 | exact consecutive completed packages |
| `strategy_min_week_bars` | 3 | minimum sessions per package |
| `strategy_max_week_bars` | 5 | maximum sessions per package |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | XNG entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-week ownership |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XNGUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411010000` (governed slot-0 allocation for `XNGUSD.DWX`).
- No signal, hedge, conversion, ratio, or external companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: the two immediately completed consecutive broker-week OHLC
  packages.
- Trigger: strict same-direction migration of both weekly range endpoints.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately twelve to twenty-four completed XNG positions per full post-
  warm-up year; Q02 retires below five.
- Symmetric direct-XNG weekly structural continuation.
- One fixed-risk position and one consumed attempt per broker week.
- The mechanic differs from certified `QM5_12567`; Q09 alone owns realized
  portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-XNG-WRANGE-MIGRATE-MOM-2026/source.md`.

The paper supplies own-price continuation lineage and includes natural gas.
The weekly range-state proxy is a disclosed QM hypothesis; no paper or WTI-
sibling result transfers to this continuous-CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or `T_Live` manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, current-week signal price,
external feed, retry, scale-in, grid, martingale, pyramid, target, trail,
break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-22 | approved build-directory identity | source approval `9169ec306`; EA-ID reservation `3a094005d`; Q00 card `2ba24719b`; governed magic `411010000` |
