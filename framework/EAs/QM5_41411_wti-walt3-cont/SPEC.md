# QM5_41411_wti-walt3-cont - Strategy Spec

**EA ID:** QM5_41411  
**Slug:** `wti-walt3-cont`  
**Strategy ID:** `KWON-WTI-WALT3-CONT-20260910_S01`  
**Source:** `KWON-WTI-WALT3-CONT-20260910`  
**Last revised:** 2026-09-10

## 1. Strategy Logic

At the first tradable `XTIUSD.DWX` D1 bar of a normalized broker week, read
only the three immediately completed adjacent three-to-five-session weeks.
Compute each `ln(final_close / first_open)`. Buy after the strict chronological
path `+,-,+`; sell after `-,+,-`. Every other path, invalid history, late
restart, or failed gate consumes the week flat.

Hold at most one position until the next normalized week. A ten-calendar-day
limit repairs stale state only. Risk uses a frozen `3.5*ATR(20,D1)` hard stop,
no target, and a fixed-dollar Q02 preset.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_symbol` | setfile-bound `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 35 |
| `strategy_required_weeks` | 3 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

The locked-configuration guard equality-pins only strategy inputs, EA ID,
slot, and the backtest risk mode (`RISK_FIXED>0`, `RISK_PERCENT=0`). RNG seed,
news, Friday-close, and portfolio weight remain framework-configurable. Stress
rejection is checked only for finiteness and inclusive `0..1`.

## 3. Symbol Universe

Trade exactly the setfile-bound `XTIUSD.DWX` D1 carrier in slot zero, magic
`414110000`. The symbol is an input; no executable symbol literal is embedded
in the EA. There are no companion markets or basket legs.

## 4. Timeframe

Chart, signal, ATR, and execution use D1. The configured custom-symbol label
offset maps D1 labels to broker session dates and Monday-anchored weeks. Entry
is allowed only on the first tradable bar within the 180-minute grace window.

## 5. Expected Behaviour

Consume one persistent attempt at the first normalized D1 bar of every broker
week. Validate three immediately prior adjacent weeks, require strict sign
alternation, and follow the newest return sign. Require no owned position or
same-week entry deal, spread at or below 1,500 points, and valid quote/ATR/stop.

Close on the first processed tick of the next normalized week, after ten days
as stale repair, on malformed owned exposure, at the frozen broker hard stop,
or through the framework kill switch. There is no target, signal flip, trail,
break-even, partial close, scale-in, pyramid, grid, or martingale.

## 6. Source Citation

The approved source packet is
`strategy-seeds/sources/KWON-WTI-WALT3-CONT-20260910/source.md`. Kwon, Kang,
and Yun (2020), DOI `10.1016/j.frl.2019.101306`, supplies weekly commodity-
momentum and WTI lineage. It does not establish this standalone time-series
alternation filter, continuous-CFD efficacy, or portfolio decorrelation.

### Framework Alignment

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/strategy checks; other framework controls remain configurable |
| entry | three completed-week packages, strict alternation, newest-sign side, durable attempt, spread and frozen ATR stop |
| management | one-position integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk Model

| Environment | Active risk mode | Inactive risk mode |
|---|---|---|
| Backtest | `RISK_FIXED=1000` | `RISK_PERCENT=0` |

This build and setfile are backtest-only. WTI gaps/slippage, continuous-CFD
basis/roll and financing, label sensitivity, alternation whipsaw, horizon
translation, and book correlation remain explicit risks. Q09 alone may
establish realized diversification.

No live setfile, deployment, portfolio admission, `T_Live`, or AutoTrading
operation is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-09-10 | Initial build from approved card | OWNER pacer mission |
