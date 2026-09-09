# QM5_41395_xng-winter-wmom - Strategy Spec

**EA ID:** QM5_41395  
**Slug:** `xng-winter-wmom`  
**Strategy ID:** `EIA-MOP-XNG-WINTER-WMOM-2026_S01`  
**Source:** `EIA-MOP-XNG-WINTER-WMOM-2026`  
**Last revised:** 2026-09-09

## 1. Strategy Logic

At the first tradable `XNGUSD.DWX` D1 bar of a normalized broker week whose
Monday anchor lies in November through March, read only the immediately
completed adjacent three-to-five-session week. Compute
`ln(final_close / first_open)` and trade its strict sign. Exact zero, invalid
history, ineligible months, late restarts, and failed gates consume the week
flat.

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
| `strategy_winter_month_1..5` | 11 / 12 / 1 / 2 / 3 |
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
`413950000`. The symbol is an input; no executable symbol literal is embedded
in the EA. There are no read-only companion markets or basket legs.

## 4. Timeframe

The chart, signal, ATR, and execution timeframe is D1. The normalized calendar
maps configured custom-symbol D1 labels to broker session dates and groups them
into Monday-anchored weeks. Entry is allowed only on the first tradable D1 bar
of a new eligible week within the 180-minute grace window.

## 5. Expected Behaviour

### Entry

Consume one persistent attempt at the first normalized D1 bar of every broker
week. Only November-through-March anchors may continue. Validate the immediately
prior adjacent week, compute its open-to-close log return, and follow the sign.
Require no owned position or same-week entry deal, spread at or below 1,500
points, valid quote/ATR/stop, and framework clearance.

### Exit

Close on the first processed tick of the next normalized broker week, after ten
elapsed days as stale repair, on malformed owned exposure, on the frozen broker
hard stop, or on the framework kill switch. There is no target, signal flip,
trail, break-even, partial close, or discretionary exit.

Malformed exposure is flattened before new entry logic. An ineligible week,
late restart, exact-zero return, bad history, or failed execution gate is
consumed flat and never retried. Expected cadence is approximately 20-22
completed packages per full year before invalid/zero-return gates. The expected
regime is winter heating-demand season; expected hold is one normalized week.

## 6. Source Citation

The source-of-record packet is
`strategy-seeds/sources/EIA-MOP-XNG-WINTER-WMOM-2026/source.md`. It joins
locally preserved official EIA seasonal-demand context with the completely
read peer-reviewed Moskowitz-Ooi-Pedersen momentum paper. The exact weekly
winter conjunction, continuous-CFD efficacy, and portfolio decorrelation are
not source claims. R1 lineage and R2-R4 status are recorded in
`strategy-seeds/cards/approved/QM5_41395_xng-winter-wmom_card.md`.

### Framework Alignment

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/strategy checks; news/Friday inputs remain framework-governed |
| entry | winter calendar, completed-week package, continuation sign, durable attempt, spread and frozen ATR stop |
| management | one-position integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk Model

| Environment | Active risk mode | Inactive risk mode |
|---|---|---|
| Backtest | `RISK_FIXED=1000` | `RISK_PERCENT=0` |
| Live packaging | `RISK_PERCENT>0` | `RISK_FIXED=0` |

This build and its canonical setfile are backtest-only. Natural-gas gaps and
slippage can exceed modeled loss. Continuous-CFD basis/roll, financing,
week-label sensitivity, seasonal instability, horizon translation, and
correlation with incumbent XNG sleeves remain explicit. Q09 alone may establish
realized diversification.

No live setfile, deployment, portfolio admission, `T_Live`, or AutoTrading
operation is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-09-09 | Initial build from approved card | OWNER pacer mission |

