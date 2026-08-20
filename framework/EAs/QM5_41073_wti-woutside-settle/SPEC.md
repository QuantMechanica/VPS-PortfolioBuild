# QM5_41073_wti-woutside-settle - Strategy Spec

EA ID: `QM5_41073`

Slug: `wti-woutside-settle`

Strategy ID: `MOP-WTI-WOUTSIDE-SETTLE-2026_S01`

Source: `MOP-WTI-WOUTSIDE-SETTLE-2026`

Author: Codex

Last revised: 2026-08-20

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, aggregate the
immediately completed week and its consecutive parent week from completed D1
OHLC. Trade only when the newer week has both a strict higher high and strict
lower low, then closes beyond the matching parent extreme, in its own
directional outer quartile, and on the matching side of its first-session
open. Follow that completed outside-settlement direction for one broker week.

Equality, malformed history, a non-outside week, settlement inside the parent
range, a close on the wrong side of the weekly open, or a non-extreme close
consumes the week flat. The position uses one fixed-risk budget and a frozen
ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 weekly-OHLC buffer |
| `strategy_min_week_bars` | 3 | minimum completed sessions per week |
| `strategy_max_week_bars` | 5 | maximum completed sessions per week |
| `strategy_close_quartile` | 0.75 | strict directional close-location boundary |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve the complete next-week hold |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Magic: `410730000`, after governed allocation.
- No signal, hedge, conversion, or external companion symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two consecutive completed broker-week OHLC packages.
- Trigger: strict outside range plus completed-week own-direction settlement
  beyond the parent extreme and in the matching outer quartile.
- Direction: follow the completed outside week's open-to-close sign.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately three to ten completed positions per full post-warm-up year;
  Q02 retires below three.
- Symmetric WTI range-expansion continuation only after the completed breakout
  survives through the weekly settlement.
- One fixed-risk position and one consumed attempt per broker week.
- The WTI carrier and mechanic do not prove decorrelation; Q09 alone owns
  realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WOUTSIDE-SETTLE-2026/source.md`.

The source supplies own-return-sign continuation and WTI membership. The
weekly horizon, outside-range geometry, parent-extreme settlement, and strict
outer-quartile condition are disclosed QM hypotheses; no source result
transfers to this CFD implementation.

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
| v0 | 2026-08-20 | approved build-directory identity | source approval `c276afbdd`; deterministic registry reservation in the commit containing this spec |

