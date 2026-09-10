# QM5_41409_xng-summer-w2fade - Strategy Spec

**EA ID:** QM5_41409  
**Slug:** `xng-summer-w2fade`  
**Strategy ID:** `EIA-YANG-XNG-SUMMER-W2FADE-20260910_S01`  
**Source:** `EIA-YANG-XNG-SUMMER-W2FADE-20260910`  
**Last revised:** 2026-09-10

## 1. Strategy Logic

At the first tradable `XNGUSD.DWX` D1 bar of a normalized broker week whose
Monday anchor lies in June, July, or August, read only the two immediately
completed adjacent three-to-five-session weeks. Compute each
`ln(final_close / first_open)` and trade opposite their common sign only when
both weeks strictly agree. Mixed signs, exact zero, invalid history,
ineligible months, late restarts, and failed gates consume the week flat.

Hold at most one position until the next normalized week. A ten-calendar-day
limit repairs stale state only. Risk uses a frozen `3.5*ATR(20,D1)` hard stop,
no target, and a fixed-dollar Q02 preset.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_symbol` | setfile-bound `XNGUSD.DWX` |
| `strategy_label_offset_seconds` | 0 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 24 |
| `strategy_summer_month_1..3` | 6 / 7 / 8 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Framework RNG seed, news, Friday-close, stress rejection, and portfolio weight
are not equality-pinned by strategy validation. Stress rejection is checked
only for finiteness and inclusive `0..1`. The risk contract requires
`RISK_PERCENT=0` and finite `RISK_FIXED>0`.

## 3. Symbol Universe

Trade exactly the setfile-bound `XNGUSD.DWX` D1 carrier in slot zero, magic
`414090000`. The symbol is an input; no executable symbol literal is embedded
in the EA. There are no companion markets or basket legs.

## 4. Timeframe

The chart, signal, ATR, and execution timeframe is D1. Native zero-offset D1
labels map to broker session dates and normalized Monday-anchored weeks. Entry
is allowed only on the first tradable D1 bar of a new eligible week within the
180-minute grace window.

## 5. Expected Behaviour

Consume one persistent attempt at the first normalized D1 bar of every broker
week. Only June-through-August anchors may continue. Validate the two
immediately prior adjacent weeks and fade their common sign only on strict
agreement. Require no owned position or same-week entry deal, spread at or
below 1,500 points, valid quote/ATR/stop, and framework clearance.

Close on the first processed tick of the next normalized broker week, after
ten elapsed days as stale repair, on malformed owned exposure, on the frozen
broker hard stop, or on the framework kill switch. There is no target, signal
flip, trail, break-even, partial close, or discretionary exit.

## 6. Source Citation

The source-of-record packet is
`strategy-seeds/sources/EIA-YANG-XNG-SUMMER-W2FADE-20260910/source.md`.
It joins a completely reviewed official EIA natural-gas seasonality record
with a completely reviewed academic commodity-reversal record. The exact
two-week summer interaction, continuous-CFD efficacy, and portfolio
decorrelation are not source claims.

### Framework Alignment

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/strategy checks; news/Friday inputs remain framework-governed |
| entry | summer calendar, two completed-week packages, strict agreement, inverse side, durable attempt, spread and frozen ATR stop |
| management | one-position integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk Model

| Environment | Active risk mode | Inactive risk mode |
|---|---|---|
| Backtest | `RISK_FIXED=1000` | `RISK_PERCENT=0` |
| Live packaging | `RISK_PERCENT>0` | `RISK_FIXED=0` |

This build and setfile are backtest-only. XNG gaps/slippage, continuous-CFD
basis/roll and financing, label sensitivity, seasonal instability, reversal
crashes, horizon translation, and book correlation remain explicit risks.
Q09 alone may establish realized diversification.

No live setfile, deployment, portfolio admission, `T_Live`, or AutoTrading
operation is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-09-10 | Initial build from approved card | OWNER pacer mission |
