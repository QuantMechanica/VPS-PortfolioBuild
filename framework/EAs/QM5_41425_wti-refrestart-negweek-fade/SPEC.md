# QM5_41425_wti-refrestart-negweek-fade - Strategy Spec

**EA ID:** QM5_41425

**Slug:** `wti-refrestart-negweek-fade`

**Strategy ID:** `EIA-YANG-WTI-REFRESTART-NEGWEEK-FADE-20260910_S01`

**Source:** `EIA-YANG-WTI-REFRESTART-NEGWEEK-FADE-20260910`

## 1. Strategy Logic

At the first tradable `XTIUSD.DWX` D1 bar of a normalized broker week whose
Monday anchor lies in April or May, read only the
immediately completed three-to-five-session week. Compute
`ln(final_close / first_open)` and buy only when it is strictly negative.
Positive, exact zero, invalid history, ineligible months, late restarts, and
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
| `strategy_restart_month_1..2` | 4 / 5 |
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
`414250000`. The symbol is an input; no executable symbol literal is embedded
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
week. Only April-May anchors may continue. Validate
the immediately prior week, compute its open-to-close log return, and buy only
after a strict loss. Require no owned position or same-week entry deal, spread
at or below 1,500 points, valid quote/ATR/stop, and framework clearance.

Close on the first processed tick of the next normalized broker week, after ten
elapsed days as stale repair, on malformed or non-long owned exposure, on the
frozen broker hard stop, or on the framework kill switch. There is no target,
signal flip, trail, break-even, partial close, scale-in, pyramid, grid,
martingale, or discretionary exit.

Expected cadence is approximately 4-7 completed positions per full year. Q02
retires below five in any full scored post-warm-up year or on nonpositive
governed economics; tuning is not a rescue path.

## 6. Source Citation

The source-of-record packet is
`strategy-seeds/sources/EIA-YANG-WTI-REFRESTART-NEGWEEK-FADE-20260910/source.md`.
It joins official EIA refinery-maintenance/restart context with the completely read
academic Yang-Goncu-Pantelous commodity-reversal paper. The exact long-only
weekly conjunction, continuous-CFD efficacy, and portfolio decorrelation are
not source claims.

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/strategy checks; news/Friday inputs remain framework-governed |
| entry | restart calendar, one completed-week package, strict negative sign, long-only side, durable attempt, spread and frozen ATR stop |
| management | one-long-position integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk Model

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
| v1.1 | 2026-09-10 | Q01 governed compile PASS; PACER pin audit and 12 reference tests clean | compile `4516a5b1-296f-4d60-ae2b-0169fe8b484f` |
| v1.2 | 2026-09-10 | First fixed-risk Q02 baseline enqueued below CPU ceiling | Q02 `e6c263cb-c853-4551-a95f-f90b91f82186` |
