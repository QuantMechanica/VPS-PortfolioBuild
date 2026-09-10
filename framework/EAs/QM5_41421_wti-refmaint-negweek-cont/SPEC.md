# QM5_41421_wti-refmaint-negweek-cont - Strategy Spec

**EA ID:** QM5_41421

**Slug:** `wti-refmaint-negweek-cont`

**Strategy ID:** `EIA-MOP-WTI-REFMAINT-NEGWEEK-CONT-20260910_S01`

**Source:** `EIA-MOP-WTI-REFMAINT-NEGWEEK-CONT-20260910`

## 1. Strategy Logic

At the first tradable `XTIUSD.DWX` D1 bar of a normalized broker week whose
Monday anchor lies in February, March, September, or October, read only the
immediately completed three-to-five-session week. Compute
`ln(final_close / first_open)` and sell only when it is strictly negative.
Positive, exact zero, invalid history, ineligible months, late restarts, and
failed gates consume the week flat. There is no long branch.

Hold at most one short position until the next normalized week. A
ten-calendar-day limit repairs stale state only. Risk uses a frozen
`3.5*ATR(20,D1)` hard stop, no target, and the Q02 preset is fixed-dollar.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_symbol` | setfile-bound `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 16 |
| `strategy_maintenance_month_1..4` | 2 / 3 / 9 / 10 |
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

## 3. Symbol Universe And Timeframe

Trade exactly the setfile-bound `XTIUSD.DWX` D1 carrier in slot zero, magic
`414210000`. The symbol is an input; no executable symbol literal is embedded
in the EA. The chart, signal, ATR, and execution timeframe is D1.

The normalized calendar maps configured custom-symbol D1 labels to broker
session dates and groups them into Monday-anchored weeks. Entry is allowed only
on the first tradable D1 bar of a new eligible week within the 180-minute grace
window.

## 4. Expected Behaviour

Consume one persistent attempt at the first normalized D1 bar of every broker
week. Only February-March and September-October anchors may continue. Validate
the immediately prior week, compute its open-to-close log return, and sell only
after a strict loss. Require no owned position or same-week entry deal, spread
at or below 1,500 points, valid quote/ATR/stop, and framework clearance.

Close on the first processed tick of the next normalized broker week, after ten
elapsed days as stale repair, on malformed or non-short owned exposure, on the
frozen broker hard stop, or on the framework kill switch. There is no target,
signal flip, trail, break-even, partial close, scale-in, pyramid, grid,
martingale, or discretionary exit.

Expected cadence is approximately 7-10 completed positions per full year. Q02
retires below five in any full scored post-warm-up year or on nonpositive
governed economics; tuning is not a rescue path.

## 5. Source And Framework Alignment

The source-of-record packet is
`strategy-seeds/sources/EIA-MOP-WTI-REFMAINT-NEGWEEK-CONT-20260910/source.md`.
It joins official EIA refinery-maintenance context with the completely read
peer-reviewed Moskowitz-Ooi-Pedersen momentum paper. The exact short-only
weekly conjunction, continuous-CFD efficacy, and portfolio decorrelation are
not source claims.

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/strategy checks; news/Friday inputs remain framework-governed |
| entry | maintenance calendar, one completed-week package, strict negative sign, short-only side, durable attempt, spread and frozen ATR stop |
| management | one-short-position integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 6. Risk And Safety

| Environment | Active risk mode | Inactive risk mode |
|---|---|---|
| Backtest | `RISK_FIXED=1000` | `RISK_PERCENT=0` |
| Live packaging | `RISK_PERCENT>0` | `RISK_FIXED=0` |

This build and its canonical setfile are backtest-only. WTI gaps and slippage
can exceed modeled loss. Continuous-CFD basis/roll, financing, week-label
sensitivity, maintenance-regime instability, horizon translation, and
correlation with other WTI sleeves remain explicit. Q09 alone may establish
realized diversification.

No live setfile, deployment, portfolio admission, `T_Live`, or AutoTrading
operation is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-09-10 | Initial build from approved card | OWNER pacer mission |
| v1-q01 | 2026-09-10 | Governed compile and strict build check PASS (`1d13cb7f-fcf7-4c04-8079-06fe036e0775`) | OWNER pacer mission |
| v1-q02 | 2026-09-10 | One fixed-risk paced canary enqueued (`290e9de5-3b60-4166-983b-fab2bd11ab23`) | OWNER pacer mission |
