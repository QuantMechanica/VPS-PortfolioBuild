# QM5_41430_wti-hurr-posweek-cont - Strategy Spec

**EA ID:** QM5_41430

**Slug:** `wti-hurr-posweek-cont`

**Strategy ID:** `EIA-MOP-WTI-HURR-POSWEEK-CONT-20260911_S01`

**Source:** `EIA-MOP-WTI-HURR-POSWEEK-CONT-20260911`

## 1. Strategy Logic

At the first tradable `XTIUSD.DWX` D1 bar of a normalized broker week whose
Monday anchor lies in August, September, or October, read only the
immediately completed three-to-five-session week. Compute
`ln(final_close / first_open)` and buy only when it is strictly positive.
Negative, exact zero, invalid history, ineligible months, late starts, and
failed gates consume the week flat. There is no short branch.

Hold at most one long position until the next normalized week. A
ten-calendar-day limit repairs stale state only. Risk uses a frozen
`3.5*ATR(20,D1)` hard stop, no target, and the Q02 preset is fixed-dollar.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_symbol` | setfile-bound `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 16 |
| `strategy_hurricane_month_1..3` | 8 / 9 / 10 |
| `strategy_required_weeks` | 1 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Framework RNG seed, news, Friday-close, stress rejection, and portfolio
weight are not equality-pinned by strategy validation. Stress rejection is
checked only for finiteness and inclusive `0..1`. The risk contract requires
`RISK_PERCENT=0` and finite `RISK_FIXED>0`.

## 3. Symbol Universe

Trade exactly the setfile-bound `XTIUSD.DWX` D1 carrier in slot zero, magic
`414300000`. The symbol is an input; no executable symbol literal is embedded
in the EA.

## 4. Timeframe

The chart, signal, ATR, and execution timeframe is D1. There are no
multi-timeframe dependencies.

The normalized calendar maps configured custom-symbol D1 labels to broker
session dates and groups them into Monday-anchored weeks. Entry is allowed only
on the first tradable D1 bar of a new eligible week within the 180-minute grace
window.

## 5. Expected Behaviour

Consume one persistent attempt at the first normalized D1 bar of every broker
week. Only August-October anchors may continue. Validate
the immediately prior week, compute its open-to-close log return, and buy only
after a strict gain. Require no owned position or same-week entry deal, spread
at or below 1,500 points, valid quote/ATR/stop, and framework clearance.

Close on the first processed tick of the next normalized broker week, after ten
elapsed days as stale repair, on malformed or non-long owned exposure, on the
frozen broker hard stop, or on the framework kill switch. There is no target,
signal flip, trail, break-even, partial close, scale-in, pyramid, grid,
martingale, or discretionary exit.

Expected cadence is approximately 5-8 completed positions per full year. Q02
retires below five in any full scored post-warm-up year or on nonpositive
governed economics; tuning is not a rescue path.

## 6. Source Citation

The source-of-record packet is
`strategy-seeds/sources/EIA-MOP-WTI-HURR-POSWEEK-CONT-20260911/source.md`.
It joins official EIA hurricane-season petroleum-supply risk context with the completely read
peer-reviewed Moskowitz-Ooi-Pedersen momentum paper. The exact long-only
weekly conjunction, continuous-CFD efficacy, and portfolio decorrelation are
not source claims.

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/strategy checks; news/Friday inputs remain framework-governed |
| entry | hurricane calendar, one completed-week package, strict positive sign, long-only side, durable attempt, spread and frozen ATR stop |
| management | one-long-position integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk Model

| Environment | Active risk mode | Inactive risk mode |
|---|---|---|
| Backtest | `RISK_FIXED=1000` | `RISK_PERCENT=0` |
| Live packaging | `RISK_PERCENT>0` | `RISK_FIXED=0` |

This build and its canonical setfile are backtest-only. WTI gaps and slippage
can exceed modeled loss. Continuous-CFD basis/roll, financing, week-label
sensitivity, hurricane-regime instability, horizon translation, and
correlation with other WTI sleeves remain explicit. Q09 alone may establish
realized diversification.

No live setfile, deployment, portfolio admission, `T_Live`, or AutoTrading
operation is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-09-11 | Initial build from approved card | OWNER pacer mission |
