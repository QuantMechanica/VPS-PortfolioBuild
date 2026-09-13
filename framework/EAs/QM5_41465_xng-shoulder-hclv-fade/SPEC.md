# QM5_41465_xng-shoulder-hclv-fade - Strategy Spec

**EA ID:** QM5_41465  
**Strategy ID:** `EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913_S01`

## 1. Strategy Logic

At the first tradable `XNGUSD.DWX` D1 bar of each April-May or September-
October normalized broker week, aggregate exactly the immediately completed
three-to-five-session week. Sell only when its final close lies strictly above
two thirds of its full high-low range. Equality or any lower close is flat.
Return sign, range rank, candle body, wick, stretch, and moving averages are
intentionally absent. Consume the decision week before fallible gates and
never retry.

Hold at most one short through the decision week. Use one frozen
`3.5*ATR(20,D1)` hard stop, no target, next-week closure, and ten-calendar-day
stale repair.

## 2. Parameters

| Parameter | Locked value |
|---|---:|
| `strategy_symbol` | setfile-bound `XNGUSD.DWX` |
| `strategy_label_offset_seconds` | 0 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 20 |
| `strategy_shoulder_month_1..4` | 4 / 5 / 9 / 10 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_clv_cutoff` | 0.666666666667 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and backtest risk mode
are locked. Framework RNG, news, Friday-close, and stress inputs remain
configurable. Stress rejection is checked only for finiteness and inclusive
`0..1`. Backtest mode requires finite `RISK_FIXED>0` and `RISK_PERCENT=0`.

## 3. Symbol Universe

Exact setfile-configured `XNGUSD.DWX` D1 carrier, slot zero, magic
`414650000`. Runtime uses native D1 OHLC/timestamps, quotes, spread, ATR,
symbol properties, positions, deals, and persistent attempt state only.

## 4. Timeframe

Base and decision timeframe are D1. Evaluate only on the first tradable D1
bar of a new normalized Monday-anchored broker week and use only the
immediately completed prior week.

## 5. Expected Behaviour

Expected cadence is five to six positions per full post-warm-up year. Q02
retires on zero trades, fewer than five in a full scored year, nonpositive
governed economics, or any clock, signal, risk, stop, attempt, or lifecycle
mismatch. Q09 alone may establish realized correlation.

## 6. Source Citation

The approved packet is
`strategy-seeds/sources/EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913/source.md`.
It combines official EIA natural-gas shoulder-season context, academic
commodity reversal, and governed peer-reviewed XNG completed-week/close-
location lineage. The exact weekly rule is an untested QM translation.

The rule differs from `QM5_12567` (all-year long-only two-day cumulative-RSI
pullback), `QM5_41392` (symmetric completed-week return-sign fade),
`QM5_41401` (two same-sign weeks), and `QM5_12595` (D1 mean stretch, channel
high, and upper wick). It uses one week, no return/range/body/wick/mean
predicate, and a strict shoulder-season upper-tercile close.

## 7. Risk Model

Backtest mode is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. One frozen `3.5*ATR(20,D1)` broker hard stop bounds each
position; there is no target, scale-in, pyramid, grid, martingale, or second
position for the magic.

## 8. Framework Alignment

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/locked-strategy checks; framework inputs unpinned |
| entry | shoulder calendar, one completed week, upper-tercile CLV, attempt, spread, ATR stop |
| management | short-only integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 9. Safety Boundary

Gaps, slippage, roll/basis, financing, shoulder-regime instability, weekly-
horizon translation, and overlap with XNG candidates can dominate. No manual
backtest, optimization, portfolio-gate edit, admission, deploy/live manifest,
`T_Live`, AutoTrading, terminal control, or live operation is authorized.

## Revision History

| Version | Date | Change |
|---|---|---|
| v1 | 2026-09-13 | Initial governed build from approved card |
