# QM5_41392_xng-shoulder-wrev - Strategy Spec

**EA ID:** QM5_41392  
**Slug:** `xng-shoulder-wrev`  
**Strategy ID:** `EIA-XNG-SHOULDER-WREV-2026_S01`  
**Source:** `EIA-XNG-SHOULDER-WREV-2026`  
**Last revised:** 2026-09-09

## 1. Strategy Logic

At the first tradable `XNGUSD.DWX` D1 bar of a normalized broker week whose
Monday anchor is in April, May, September, or October, read only the
immediately completed adjacent three-to-five-session week. Compute
`ln(final_close / first_open)` and trade the opposite strict sign. Exact zero,
invalid history, ineligible months, late restarts, and failed gates consume the
week flat.

Hold at most one position until the next normalized week. A ten-calendar-day
limit repairs stale state only. Risk uses a frozen `3.5*ATR(20,D1)` hard stop,
no target, and the Q02 preset is fixed-dollar.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_symbol` | setfile-bound `XNGUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 16 |
| `strategy_spring_month_1/2` | 4 / 5 |
| `strategy_autumn_month_1/2` | 9 / 10 |
| `strategy_required_weeks` | 1 |
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
`413920000`. The symbol is an input; no executable symbol literal is embedded
in the EA. There are no read-only companion markets or basket legs.

## 4. Timeframe

The chart, signal, ATR, and execution timeframe is D1. The normalized calendar
maps the configured custom-symbol D1 labels to broker session dates and groups
them into Monday-anchored weeks. Entry is allowed only on the first tradable
D1 bar of a new eligible week within the 180-minute grace window.

## 5. Expected Behaviour

### Entry

Consume one persistent attempt at the first normalized D1 bar of every broker
week. Only shoulder-month anchors may continue. Validate the immediately prior
adjacent week, compute its open-to-close log return, and reverse the sign.
Require an empty owned-position set, no same-week entry deal, spread at or
below 1,500 points, valid quote/ATR/stop, and framework clearance.

### Exit

Close on the first processed tick of the next normalized broker week, after ten
elapsed days as stale repair, on malformed owned exposure, on the frozen broker
hard stop, or on the framework kill switch. There is no target, signal flip,
trail, break-even, partial close, or discretionary exit.

Malformed exposure is flattened before new entry logic. An ineligible week,
late restart, exact-zero return, bad history, or failed execution gate is
consumed flat and is never retried. The expected cadence is approximately
16–18 completed packages per full year before invalid/zero-return gates.

## 6. Source Citation

The source-of-record packet is
`strategy-seeds/sources/EIA-XNG-SHOULDER-WREV-2026/source.md`, a governed
bounded mechanization of locally preserved official U.S. Energy Information
Administration natural-gas seasonal-demand context. The source does not claim
this weekly reversal rule, continuous-CFD efficacy, or portfolio
decorrelation. Fresh generic-web retrieval was refused by policy and is not
used as evidence.

### Framework Alignment

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/strategy checks; news/Friday inputs remain framework-governed |
| entry | shoulder calendar, completed-week package, contrarian sign, durable attempt, spread and frozen ATR stop |
| management | one-position integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Natural-gas gaps and slippage can exceed the modeled
loss. Continuous-CFD basis/roll, financing, week-label sensitivity, seasonal
instability, and correlation with the incumbent XNG sleeve remain explicit.
Q09 alone may establish realized diversification.

No live setfile, deployment, portfolio admission, `T_Live`, or AutoTrading
operation is authorized.
